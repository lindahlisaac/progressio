import Foundation
import SwiftUI
import CryptoKit
import Combine

final class WeekPlannerViewModel: ObservableObject {
    private let calendar: Calendar
    private let weekStore: WeekPlanStore
    private let unattachedStore: UnattachedRunStore
    private let weeklyTemplateStore: WeeklyTemplateStore
    private let isoFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    @Published var weekPlan: WeekPlan
    @Published var currentStartOfWeek: Date
    @Published private(set) var unattachedRuns: [UnattachedRun] = []
    @Published private(set) var weeklyTemplates: [WeeklyTemplate] = []

    var activeWeeklyTemplates: [WeeklyTemplate] {
        weeklyTemplates.filter { !$0.isDeleted }
    }

    var activeUnattachedRuns: [UnattachedRun] {
        unattachedRuns.filter { !$0.isDeleted }
    }

    init(calendar: Calendar = .current,
         templates: [StrengthTemplate],
         weekStore: WeekPlanStore = SyncingWeekPlanStore(),
         unattachedStore: UnattachedRunStore = SyncingUnattachedRunStore(),
         weeklyTemplateStore: WeeklyTemplateStore = SyncingWeeklyTemplateStore()) {
        self.calendar = calendar
        self.weekStore = weekStore
        self.unattachedStore = unattachedStore
        self.weeklyTemplateStore = weeklyTemplateStore
        let start = calendar.startOfWeek(for: Date())
        self.currentStartOfWeek = start
        if let loaded = weekStore.loadWeek(start: start) {
            self.weekPlan = loaded
        } else {
            let sample = WeekPlannerViewModel.makeSampleWeek(calendar: calendar, templates: templates, start: start)
            self.weekPlan = sample
            persistWeek()
        }
        self.unattachedRuns = unattachedStore.loadRuns()
        self.weeklyTemplates = weeklyTemplateStore.loadTemplates()
        dedupeUnattachedRuns()
    }

    func goToPreviousWeek(templates: [StrengthTemplate]) {
        guard let newStart = calendar.date(byAdding: .day, value: -7, to: currentStartOfWeek) else { return }
        loadWeek(startDate: newStart, templates: templates)
    }

    func goToNextWeek(templates: [StrengthTemplate]) {
        guard let newStart = calendar.date(byAdding: .day, value: 7, to: currentStartOfWeek) else { return }
        loadWeek(startDate: newStart, templates: templates)
    }

    private func loadWeek(startDate: Date, templates: [StrengthTemplate]) {
        if let loaded = weekStore.loadWeek(start: startDate) {
            self.weekPlan = loaded
        } else {
            let todayStart = calendar.startOfWeek(for: Date())
            if calendar.isDate(startDate, inSameDayAs: todayStart) {
                let sample = WeekPlannerViewModel.makeSampleWeek(calendar: calendar, templates: templates, start: startDate)
                self.weekPlan = sample
            } else {
                self.weekPlan = WeekPlannerViewModel.makeEmptyWeek(calendar: calendar, start: startDate)
            }
            persistWeek(for: startDate)
        }
        self.currentStartOfWeek = startDate
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

    func addStrengthSession(on date: Date, title: String = "Strength", note: String? = nil) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: title,
                kind: .strength,
                status: .planned,
                note: note,
                templateName: nil
            )
        )
        persistWeek()
    }

    func addTemplateSession(template: StrengthTemplate, on date: Date) {
        guard let dayIndex = dayIndex(for: date) else { return }
        
        let runDetail: RunDetailData?
        if template.category == .run {
            runDetail = RunDetailData(
                title: template.name,
                notes: template.note ?? "",
                distance: "",
                duration: "",
                averageHR: "",
                category: template.runCategory
            )
        } else {
            runDetail = nil
        }
        
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: template.name,
                kind: template.category == .run ? .run : .strength,
                status: .planned,
                note: "From template",
                templateName: template.name,
                runDetail: runDetail
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

    func saveWeeklyTemplate(name: String, note: String?, days: [DayTemplate]? = nil) {
        let dayTemplates: [DayTemplate]
        if let days {
            dayTemplates = days
        } else {
            dayTemplates = weekPlan.days.map { day in
                let weekday = calendar.component(.weekday, from: day.date)
                return DayTemplate(weekday: weekday, sessions: day.sessions)
            }
        }
        let template = WeeklyTemplate(name: name, note: note, days: dayTemplates)
        weeklyTemplates.append(template)
        print("✅ Saved weekly template: \(name), total templates: \(weeklyTemplates.count)")
        persistWeeklyTemplates()
    }

    func deleteWeeklyTemplate(id: UUID) {
        guard let idx = weeklyTemplates.firstIndex(where: { $0.id == id }) else { return }
        weeklyTemplates[idx] = SyncMetadata.softDelete(weeklyTemplates[idx])
        persistWeeklyTemplates()
    }

    func updateWeeklyTemplate(id: UUID, name: String, note: String?, days: [DayTemplate]) {
        guard let idx = weeklyTemplates.firstIndex(where: { $0.id == id }) else { return }
        weeklyTemplates[idx].name = name
        weeklyTemplates[idx].note = note
        weeklyTemplates[idx].days = days
        SyncMetadata.stampSave(&weeklyTemplates[idx])
        persistWeeklyTemplates()
    }

    func hasWorkoutsInCurrentWeek() -> Bool {
        return weekPlan.days.contains { !$0.sessions.isEmpty }
    }
    
    func applyWeeklyTemplate(_ template: WeeklyTemplate, to start: Date, keepExisting: Bool = false) {
        var days: [DayPlan] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let templateSessions = template.days.first(where: { $0.weekday == weekday })?.sessions ?? []
            
            if keepExisting {
                // Find existing day and keep its sessions, then append template sessions
                if let existingDay = weekPlan.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                    var combinedSessions = existingDay.sessions
                    combinedSessions.append(contentsOf: templateSessions)
                    days.append(DayPlan(date: date, sessions: combinedSessions))
                } else {
                    days.append(DayPlan(date: date, sessions: templateSessions))
                }
            } else {
                // Override with template sessions only
                days.append(DayPlan(date: date, sessions: templateSessions))
            }
        }
        weekPlan = WeekPlan(startOfWeek: start, days: days)
        currentStartOfWeek = start
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
                case .skipped:
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

    func setSessionStatus(sessionID: UUID, status: PlanStatus, note: String? = nil) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                weekPlan.days[dayIdx].sessions[sessionIndex].status = status
                if let note {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    weekPlan.days[dayIdx].sessions[sessionIndex].note = trimmed.isEmpty ? nil : trimmed
                }
                persistWeek()
                break
            }
        }
    }

    func setSessionNote(sessionID: UUID, note: String?) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                weekPlan.days[dayIdx].sessions[sessionIndex].note = trimmed.isEmpty ? nil : trimmed
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
                var stamped = run
                SyncMetadata.stampNewRecord(&stamped)
                unattachedRuns.append(stamped)
                added = true
            }
        }
        if added {
            dedupeUnattachedRuns()
            persistUnattached()
        }
    }

    func removeUnattachedRun(id: UUID) {
        guard let idx = unattachedRuns.firstIndex(where: { $0.id == id }) else { return }
        unattachedRuns[idx] = SyncMetadata.softDelete(unattachedRuns[idx])
        persistUnattached()
    }

    func clearUnattachedRuns() {
        let now = Date()
        unattachedRuns = unattachedRuns.map { run in
            guard !run.isDeleted else { return run }
            var copy = run
            copy.isDeleted = true
            copy.deletedAt = now
            copy.updatedAt = now
            return copy
        }
        persistUnattached()
    }

    func dedupeUnattachedRuns() {
        var seen = Set<String>()
        var unique: [UnattachedRun] = []
        for run in unattachedRuns {
            guard !run.isDeleted else {
                unique.append(run)
                continue
            }
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
        unattachedRuns = unattachedRuns.map { run in
            var stamped = run
            SyncMetadata.stampSave(&stamped)
            return stamped
        }
        unattachedStore.save(unattachedRuns)
    }

    func persistWeeklyTemplates() {
        weeklyTemplates = weeklyTemplates.map { template in
            var stamped = template
            SyncMetadata.stampSave(&stamped)
            return stamped
        }
        weeklyTemplateStore.save(weeklyTemplates)
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

    private func detailSignature(_ detail: RunDetailData, fallbackDate: Date?) -> String {
        if let uuid = detail.hkWorkoutUUID?.lowercased() {
            return "hk-\(uuid)"
        }

        let dateComponent: String = {
            if let eventDate = detail.eventDate {
                return "\(Int(eventDate.timeIntervalSince1970))"
            } else if let fallbackDate {
                return "\(Int(fallbackDate.timeIntervalSince1970))"
            }
            return ""
        }()

        let distanceValue = normalizedDistance(detail.distance)
        let durationValue = normalizedDurationSeconds(detail.duration)
        let title = detail.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let category = detail.category?.rawValue.lowercased() ?? ""

        let components = [
            dateComponent,
            title,
            distanceValue,
            durationValue,
            detail.averageHR ?? "",
            category
        ].joined(separator: "|")
        return sha256Hex(of: components)
    }

    private func runSignature(for run: UnattachedRun) -> String {
        detailSignature(run.detail, fallbackDate: run.date)
    }

    private func existingRunSignatures() -> Set<String> {
        var sigs = Set<String>()
        for unattached in unattachedRuns where !unattached.isDeleted {
            sigs.insert(runSignature(for: unattached))
        }
        for day in weekPlan.days {
            for session in day.sessions where session.kind == .run {
                if let detail = session.runDetail {
                    sigs.insert(detailSignature(detail, fallbackDate: day.date))
                }
                if let detail = session.actualRun {
                    sigs.insert(detailSignature(detail, fallbackDate: day.date))
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

    static func makeSampleWeek(calendar: Calendar, templates: [StrengthTemplate], start: Date? = nil) -> WeekPlan {
        let start = start ?? calendar.startOfWeek(for: Date())
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

    static func makeEmptyWeek(calendar: Calendar, start: Date) -> WeekPlan {
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayPlan(date: date, sessions: [])
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    func exportCurrentWeek() -> URL? {
        do {
            // Create a copy of weekPlan with strength logs included
            var exportPlan = weekPlan
            var strengthLogsIncluded = 0
            
            for dayIdx in exportPlan.days.indices {
                for sessionIdx in exportPlan.days[dayIdx].sessions.indices {
                    let session = exportPlan.days[dayIdx].sessions[sessionIdx]
                    
                    // Load strength log if this is a strength session
                    if session.kind == .strength {
                        let logURL = Self.strengthLogURL(for: session.id)
                        if FileManager.default.fileExists(atPath: logURL.path) {
                            do {
                                let logData = try Data(contentsOf: logURL)
                                let decoder = JSONDecoder()
                                let strengthLog = try decoder.decode(StrengthLogState.self, from: logData)
                                exportPlan.days[dayIdx].sessions[sessionIdx].strengthLog = strengthLog
                                strengthLogsIncluded += 1
                            } catch {
                                print("⚠️ Failed to load strength log for session \(session.id): \(error)")
                            }
                        }
                    }
                }
            }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(exportPlan)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("weekplan-\(isoFormatter.string(from: currentStartOfWeek)).json")
            try data.write(to: url, options: .atomic)
            print("📤 Exported week to: \(url.path)")
            print("   Days: \(exportPlan.days.count)")
            print("   Total sessions: \(exportPlan.days.flatMap { $0.sessions }.count)")
            print("   Strength logs included: \(strengthLogsIncluded)")
            return url
        } catch {
            print("❌ Failed to export week: \(error)")
            return nil
        }
    }
    
    private static func strengthLogURL(for sessionID: UUID) -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("strengthlog-\(sessionID.uuidString).json")
    }

    func importWeek(from url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security-scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let imported = try decoder.decode(WeekPlan.self, from: data)
            print("✅ Successfully decoded WeekPlan with \(imported.days.count) days")
            print("   Start of week: \(imported.startOfWeek)")
            print("   Total sessions: \(imported.days.flatMap { $0.sessions }.count)")
            
            // Restore strength logs for strength sessions
            var strengthLogsRestored = 0
            for day in imported.days {
                for session in day.sessions {
                    if session.kind == .strength, let strengthLog = session.strengthLog {
                        let logURL = Self.strengthLogURL(for: session.id)
                        do {
                            let encoder = JSONEncoder()
                            encoder.outputFormatting = [.prettyPrinted]
                            let logData = try encoder.encode(strengthLog)
                            try logData.write(to: logURL, options: .atomic)
                            strengthLogsRestored += 1
                        } catch {
                            print("⚠️ Failed to restore strength log for session \(session.id): \(error)")
                        }
                    }
                }
            }
            
            self.weekPlan = imported
            self.currentStartOfWeek = imported.startOfWeek
            persistWeek(for: imported.startOfWeek)
            print("💾 Imported week persisted")
            print("   Strength logs restored: \(strengthLogsRestored)")
        } catch {
            print("❌ Failed to import week: \(error)")
        }
    }

    private func persistWeek(for start: Date? = nil) {
        weekPlan.updatedAt = Date()
        weekStore.save(weekPlan, start: start ?? currentStartOfWeek)
    }

    private func persistWeek() {
        persistWeek(for: currentStartOfWeek)
    }

    // MARK: - Sync helpers

    @MainActor
    func forceSync() async {
        // Push local state
        persistWeek()
        persistUnattached()
        persistWeeklyTemplates()
        // Pull latest from stores
        if let loaded = weekStore.loadWeek(start: currentStartOfWeek) {
            weekPlan = loaded
        }
        unattachedRuns = unattachedStore.loadRuns()
        weeklyTemplates = weeklyTemplateStore.loadTemplates()
    }
}

