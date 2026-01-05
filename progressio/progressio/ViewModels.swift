import Foundation
import CryptoKit
import SwiftUI
import Combine

final class TemplateLibraryViewModel: ObservableObject {
    @Published var templates: [StrengthTemplate]

    private static var storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("templates.json")
    }()

    init(templates: [StrengthTemplate]? = nil) {
        if let templates {
            self.templates = templates
        } else if let loaded = TemplateLibraryViewModel.loadPersistedTemplates() {
            self.templates = loaded
        } else {
            let samples = TemplateLibraryViewModel.makeSamples()
            self.templates = samples
            persistTemplates()
        }
    }

    func addTemplate(name: String, note: String?, category: TemplateCategory, exercises: [StrengthExercise], runCategory: RunCategory? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let cleanedNote: String?
        if let note {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedNote = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            cleanedNote = nil
        }

        var newTemplate = StrengthTemplate(name: trimmedName, category: category, exercises: exercises, note: cleanedNote, runCategory: runCategory)
        templates.append(newTemplate)
        persistTemplates()
    }

    func updateTemplate(_ updated: StrengthTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == updated.id }) {
            templates[idx] = updated
            persistTemplates()
        }
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        persistTemplates()
    }

    static func makeSamples() -> [StrengthTemplate] {
        [
            StrengthTemplate(
                name: "Upper Push",
                category: .strength,
                exercises: [
                    StrengthExercise(
                        name: "Bench Press",
                        sets: [
                            StrengthSetTemplate(targetReps: 8, targetWeight: 135, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 8, targetWeight: 140, targetRPE: 8.0),
                            StrengthSetTemplate(targetReps: 8, targetWeight: 145, targetRPE: 8.5)
                        ]
                    ),
                    StrengthExercise(
                        name: "Overhead Press",
                        sets: [
                            StrengthSetTemplate(targetReps: 10, targetWeight: 75, targetRPE: 7.0),
                            StrengthSetTemplate(targetReps: 10, targetWeight: 80, targetRPE: 7.5)
                        ]
                    )
                ],
                note: "Baseline template for push focus days."
                , runCategory: nil
            ),
            StrengthTemplate(
                name: "Lower Mixed",
                category: .strength,
                exercises: [
                    StrengthExercise(
                        name: "Back Squat",
                        sets: [
                            StrengthSetTemplate(targetReps: 6, targetWeight: 185, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 6, targetWeight: 195, targetRPE: 8.0)
                        ]
                    ),
                    StrengthExercise(
                        name: "Romanian Deadlift",
                        sets: [
                            StrengthSetTemplate(targetReps: 10, targetWeight: 155, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 10, targetWeight: 160, targetRPE: 8.0)
                        ]
                    )
                ],
                note: "Hybrid lower day with hinge + squat.",
                runCategory: nil
            )
        ]
    }

    private func persistTemplates() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(templates)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist templates: \(error)")
        }
    }

    private static func loadPersistedTemplates() -> [StrengthTemplate]? {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([StrengthTemplate].self, from: data)
        } catch {
            print("Failed to load templates: \(error)")
            return nil
        }
    }
}

final class WeekPlannerViewModel: ObservableObject {
    private let calendar: Calendar

    @Published var weekPlan: WeekPlan
    @Published var unattachedRuns: [UnattachedRun] = []
    private static var storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("weekplan.json")
    }()
    private static var unattachedURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("unattachedRuns.json")
    }()

    init(calendar: Calendar = .current, templates: [StrengthTemplate]) {
        self.calendar = calendar
        if let loaded = WeekPlannerViewModel.loadPersistedWeek() {
            self.weekPlan = loaded
        } else {
            let sample = WeekPlannerViewModel.makeSampleWeek(calendar: calendar, templates: templates)
            self.weekPlan = sample
            persistWeek()
        }
        self.unattachedRuns = WeekPlannerViewModel.loadUnattachedRuns()
        dedupeUnattachedRuns()
    }

    func addStrengthSession(template: StrengthTemplate, on date: Date) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: template.name,
                kind: template.category == .run ? .run : .strength,
                status: .planned,
                note: "From template",
                templateName: template.name
            )
        )
        persistWeek()
    }

    func addTemplateSession(template: StrengthTemplate, on date: Date) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: template.name,
                kind: template.category == .run ? .run : .strength,
                status: .planned,
                note: "From template",
                templateName: template.name
            )
        )
        persistWeek()
    }

    func addRun(on date: Date, title: String = "Run", planned: Bool = true) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: title,
                kind: .run,
                status: planned ? .planned : .unplanned,
                note: planned ? "Attach the detected HealthKit run" : "Logged from detected run"
            )
        )
        persistWeek()
    }

    func addCycle(on date: Date, title: String = "Ride", planned: Bool = true) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: title,
                kind: .cycle,
                status: planned ? .planned : .unplanned,
                note: planned ? "Planned ride" : "Logged ride"
            )
        )
        persistWeek()
    }

    func toggleStatus(sessionID: UUID) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                let status = weekPlan.days[dayIdx].sessions[sessionIndex].status
                switch status {
                case .unplanned:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .planned
                case .planned:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .completed
                case .completed:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .planned
                }
                persistWeek()
                break
            }
        }
    }

    func removeSession(dayID: UUID, sessionID: UUID) {
        guard let dayIndex = weekPlan.days.firstIndex(where: { $0.id == dayID }) else { return }
        weekPlan.days[dayIndex].sessions.removeAll { $0.id == sessionID }
        persistWeek()
    }

    func setSessionStatus(sessionID: UUID, status: PlanStatus) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                weekPlan.days[dayIdx].sessions[sessionIndex].status = status
                persistWeek()
                break
            }
        }
    }

    func updateRunDetail(sessionID: UUID, detail: RunDetailData, status: PlanStatus, actualDistance: String? = nil, actualDuration: String? = nil, actualElevation: String? = nil) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                weekPlan.days[dayIdx].sessions[sessionIndex].runDetail = detail
                weekPlan.days[dayIdx].sessions[sessionIndex].title = detail.title
                weekPlan.days[dayIdx].sessions[sessionIndex].note = detail.notes.isEmpty ? weekPlan.days[dayIdx].sessions[sessionIndex].note : detail.notes
                weekPlan.days[dayIdx].sessions[sessionIndex].status = status

                if let actualDistance, !actualDistance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    var actual = weekPlan.days[dayIdx].sessions[sessionIndex].actualRun
                    let baseTitle = actual?.title ?? detail.title
                    actual = RunDetailData(
                        title: baseTitle,
                        notes: actual?.notes ?? "",
                        distance: actualDistance,
                        duration: actual?.duration ?? "",
                        averageHR: actual?.averageHR ?? "",
                        category: detail.category,
                        hkWorkoutUUID: actual?.hkWorkoutUUID,
                        elevationGain: actual?.elevationGain
                    )
                    weekPlan.days[dayIdx].sessions[sessionIndex].actualRun = actual
                } else if actualDistance != nil {
                    // Explicit clear of distance
                    if var actual = weekPlan.days[dayIdx].sessions[sessionIndex].actualRun {
                        actual.distance = ""
                        weekPlan.days[dayIdx].sessions[sessionIndex].actualRun = actual
                    }
                }

                if let actualDuration {
                    var actual = weekPlan.days[dayIdx].sessions[sessionIndex].actualRun ?? RunDetailData(title: detail.title, notes: "", distance: "", duration: "", averageHR: "", category: detail.category, hkWorkoutUUID: detail.hkWorkoutUUID)
                    actual.duration = actualDuration
                    weekPlan.days[dayIdx].sessions[sessionIndex].actualRun = actual
                }

                if let actualElevation {
                    var actual = weekPlan.days[dayIdx].sessions[sessionIndex].actualRun ?? RunDetailData(title: detail.title, notes: "", distance: "", duration: "", averageHR: "", category: detail.category, hkWorkoutUUID: detail.hkWorkoutUUID)
                    actual.elevationGain = actualElevation
                    weekPlan.days[dayIdx].sessions[sessionIndex].actualRun = actual
                }

                persistWeek()
                break
            }
        }
    }

    func attachActualRun(to day: Date, run: UnattachedRun, toSessionID: UUID? = nil) {
        guard let dayIndex = weekPlan.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return }
        if let targetID = toSessionID,
           let sessionIndex = weekPlan.days[dayIndex].sessions.firstIndex(where: { $0.id == targetID }) {
            weekPlan.days[dayIndex].sessions[sessionIndex].actualRun = run.detail
            weekPlan.days[dayIndex].sessions[sessionIndex].status = .completed
        } else if let sessionIndex = weekPlan.days[dayIndex].sessions.firstIndex(where: { $0.kind == .run && $0.runDetail != nil && $0.actualRun == nil }) {
            weekPlan.days[dayIndex].sessions[sessionIndex].actualRun = run.detail
            weekPlan.days[dayIndex].sessions[sessionIndex].status = .completed
        } else {
            // No planned run; add as unplanned actual
            var session = PlannedSession(
                title: run.detail.title.isEmpty ? "Run" : run.detail.title,
                kind: .run,
                status: .completed,
                note: "Imported from HealthKit",
                templateName: nil,
                runDetail: nil
            )
            session.actualRun = run.detail
            weekPlan.days[dayIndex].sessions.append(session)
        }
        persistWeek()
    }

    func detachActualRun(sessionID: UUID) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                if let actual = weekPlan.days[dayIdx].sessions[sessionIndex].actualRun {
                    let unattached = UnattachedRun(detail: actual, date: weekPlan.days[dayIdx].date, source: "Detached")
                    addUnattachedRun(unattached)
                }
                weekPlan.days[dayIdx].sessions[sessionIndex].actualRun = nil
                if weekPlan.days[dayIdx].sessions[sessionIndex].status == .completed,
                   weekPlan.days[dayIdx].sessions[sessionIndex].runDetail == nil {
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .planned
                }
                persistWeek()
                break
            }
        }
    }

    func addUnattachedRun(_ run: UnattachedRun) {
        importUnattachedRuns([run])
    }

    func importUnattachedRuns(_ runs: [UnattachedRun]) {
        var sigs = existingRunSignatures()
        var added = false
        for run in runs {
            let sig = runSignature(for: run)
            if sigs.insert(sig).inserted {
                unattachedRuns.append(run)
                added = true
            }
        }
        if added {
            dedupeUnattachedRuns()
            persistUnattached()
        }
    }

    func removeUnattachedRun(id: UUID) {
        unattachedRuns.removeAll { $0.id == id }
        persistUnattached()
    }

    func clearUnattachedRuns() {
        unattachedRuns.removeAll()
        persistUnattached()
    }

    func dedupeUnattachedRuns() {
        var seen = Set<String>()
        var unique: [UnattachedRun] = []
        for run in unattachedRuns {
            let sig = runSignature(for: run)
            if seen.insert(sig).inserted {
                unique.append(run)
            }
        }
        if unique.count != unattachedRuns.count {
            unattachedRuns = unique
            persistUnattached()
        }
    }

    private func persistUnattached() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(unattachedRuns)
            try data.write(to: Self.unattachedURL, options: .atomic)
        } catch {
            print("Failed to persist unattached runs: \(error)")
        }
    }

    private static func loadUnattachedRuns() -> [UnattachedRun] {
        let url = unattachedURL
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([UnattachedRun].self, from: data)
        } catch {
            print("Failed to load unattached runs: \(error)")
            return []
        }
    }

    private func hasAttachedRun(with uuid: String) -> Bool {
        for day in weekPlan.days {
            for session in day.sessions where session.kind == .run {
                if session.runDetail?.hkWorkoutUUID == uuid { return true }
                if session.actualRun?.hkWorkoutUUID == uuid { return true }
            }
        }
        return false
    }

    private func runSignature(for run: UnattachedRun) -> String {
        if let uuid = run.detail.hkWorkoutUUID?.lowercased() {
            return "hk-\(uuid)"
        }

        let startSeconds = Int(run.date.timeIntervalSince1970)
        let distanceValue = normalizedDistance(run.detail.distance)
        let durationValue = normalizedDurationSeconds(run.detail.duration)
        let title = run.detail.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let category = run.detail.category?.rawValue.lowercased() ?? ""

        let components = [
            "\(startSeconds)",
            title,
            distanceValue,
            durationValue,
            run.detail.averageHR ?? "",
            category
        ].joined(separator: "|")
        return sha256Hex(of: components)
    }

    private func existingRunSignatures() -> Set<String> {
        var sigs = Set<String>()
        for unattached in unattachedRuns {
            sigs.insert(runSignature(for: unattached))
        }
        for day in weekPlan.days {
            for session in day.sessions where session.kind == .run {
                if let uuid = session.runDetail?.hkWorkoutUUID?.lowercased() {
                    sigs.insert("hk-\(uuid)")
                }
                if let uuid = session.actualRun?.hkWorkoutUUID?.lowercased() {
                    sigs.insert("hk-\(uuid)")
                }
                if let detail = session.actualRun {
                    let components = [
                        "\(Int(day.date.timeIntervalSince1970))",
                        detail.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        normalizedDistance(detail.distance),
                        normalizedDurationSeconds(detail.duration),
                        detail.averageHR ?? "",
                        detail.category?.rawValue.lowercased() ?? ""
                    ].joined(separator: "|")
                    sigs.insert(sha256Hex(of: components))
                }
            }
        }
        return sigs
    }

    private func sha256Hex(of string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func normalizedDistance(_ distance: String) -> String {
        let filtered = distance.filter { "0123456789.,".contains($0) }.replacingOccurrences(of: ",", with: ".")
        if let value = Double(filtered) {
            return String(format: "%.2f", value)
        }
        return distance.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedDurationSeconds(_ duration: String) -> String {
        let trimmed = duration.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 {
            return "\(parts[0] * 3600 + parts[1] * 60 + parts[2])"
        } else if parts.count == 2 {
            return "\(parts[0] * 60 + parts[1])"
        } else if let val = Int(trimmed) {
            return "\(val)"
        }
        return trimmed
    }

    private func dayIndex(for date: Date) -> Int? {
        weekPlan.days.firstIndex { calendar.isDate($0.date, inSameDayAs: date) }
    }

    static func makeSampleWeek(calendar: Calendar, templates: [StrengthTemplate]) -> WeekPlan {
        let start = calendar.startOfWeek(for: Date())
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            var sessions: [PlannedSession] = []
            if offset == 0, let template = templates.first {
                sessions.append(
                    PlannedSession(
                        title: template.name,
                        kind: template.category == .run ? .run : .strength,
                        status: .planned,
                        note: "Tap to log sets and mark complete",
                        templateName: template.name
                    )
                )
            }
            if offset == 2 {
                sessions.append(
                    PlannedSession(
                        title: "Easy Run 4 mi",
                        kind: .run,
                        status: .planned,
                        note: "Will prompt to attach when HealthKit run is detected"
                    )
                )
            }
            if offset == 4, templates.count > 1 {
                sessions.append(
                    PlannedSession(
                        title: templates[1].name,
                        kind: templates[1].category == .run ? .run : .strength,
                        status: .planned,
                        note: "Use template for progressive overload",
                        templateName: templates[1].name
                    )
                )
            }
            return DayPlan(date: date, sessions: sessions)
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    private func persistWeek() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(weekPlan)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist week: \(error)")
        }
    }

    private static func loadPersistedWeek() -> WeekPlan? {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WeekPlan.self, from: data)
        } catch {
            print("Failed to load week: \(error)")
            return nil
        }
    }
}

