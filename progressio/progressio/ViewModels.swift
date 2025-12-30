import Foundation
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
    private static var storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("weekplan.json")
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

    func updateRunDetail(sessionID: UUID, detail: RunDetailData, status: PlanStatus) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                weekPlan.days[dayIdx].sessions[sessionIndex].runDetail = detail
                weekPlan.days[dayIdx].sessions[sessionIndex].title = detail.title
                weekPlan.days[dayIdx].sessions[sessionIndex].note = detail.notes.isEmpty ? weekPlan.days[dayIdx].sessions[sessionIndex].note : detail.notes
                weekPlan.days[dayIdx].sessions[sessionIndex].status = status
                persistWeek()
                break
            }
        }
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

