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

    func addWorkout(
        activityType: ActivityType,
        on date: Date,
        timePeriod: TimePeriod = .am,
        title: String? = nil,
        notes: String? = nil
    ) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].workouts.append(
            Workout.manual(
                activityType: activityType,
                plannedDate: date,
                timePeriod: timePeriod,
                title: title,
                notes: notes
            )
        )
        persistWeek()
    }

    func addEnduranceSession(template: EnduranceTemplate, on date: Date, timePeriod: TimePeriod = .am) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].workouts.append(
            Workout.from(template: template, plannedDate: date, timePeriod: timePeriod)
        )
        persistWeek()
    }

    func addStrengthSession(template: StrengthTemplate, on date: Date, timePeriod: TimePeriod = .am) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].workouts.append(
            Workout.from(template: template, plannedDate: date, timePeriod: timePeriod)
        )
        persistWeek()
    }

    func addStrengthSession(on date: Date, timePeriod: TimePeriod = .am, title: String = "Strength", note: String? = nil) {
        addWorkout(activityType: .strength, on: date, timePeriod: timePeriod, title: title, notes: note)
    }

    func addTemplateSession(template: StrengthTemplate, on date: Date, timePeriod: TimePeriod = .am) {
        addStrengthSession(template: template, on: date, timePeriod: timePeriod)
    }

    func addRun(on date: Date, timePeriod: TimePeriod = .am, title: String = "Road Run", planned: Bool = true) {
        guard let dayIndex = dayIndex(for: date) else { return }
        if planned {
            weekPlan.days[dayIndex].workouts.append(
                Workout.manual(activityType: .roadRun, plannedDate: date, timePeriod: timePeriod, title: title)
            )
        } else {
            weekPlan.days[dayIndex].workouts.append(
                Workout.run(
                    plannedDate: date,
                    timePeriod: timePeriod,
                    title: title,
                    imported: true,
                    notes: "Logged from detected run"
                )
            )
        }
        persistWeek()
    }

    func addCycle(on date: Date, timePeriod: TimePeriod = .am, title: String = "Bike", planned: Bool = true) {
        addWorkout(activityType: .bike, on: date, timePeriod: timePeriod, title: title, notes: planned ? nil : "Logged bike")
    }

    func setWorkoutTimePeriod(workoutID: UUID, timePeriod: TimePeriod) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                weekPlan.days[dayIdx].workouts[workoutIndex].timePeriod = timePeriod
                weekPlan.days[dayIdx].workouts[workoutIndex].touchUpdatedAt()
                persistWeek()
                break
            }
        }
    }

    func saveWeeklyTemplate(name: String, note: String?, days: [DayTemplate]? = nil) {
        let dayTemplates: [DayTemplate]
        if let days {
            dayTemplates = days
        } else {
            dayTemplates = weekPlan.days.map { day in
                let weekday = calendar.component(.weekday, from: day.date)
                let entries = day.activeWorkouts.map(WeeklyTemplateWorkoutEntry.snapshot(from:))
                return DayTemplate(weekday: weekday, workoutEntries: entries)
            }
        }
        var template = WeeklyTemplate(name: name, note: note, days: dayTemplates)
        SyncMetadata.stampNewRecord(&template)
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
        weekPlan.days.contains { !$0.activeWorkouts.isEmpty }
    }

    func applyWeeklyTemplate(_ template: WeeklyTemplate, to start: Date, keepExisting: Bool = false) {
        var days: [DayPlan] = []
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: date)
            let templateWorkouts = (template.days.first(where: { $0.weekday == weekday })?.workoutEntries ?? [])
                .map { $0.makeWorkout(plannedDate: date, linkedWeeklyTemplateId: template.id) }

            if keepExisting {
                let existing = weekPlan.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.workouts ?? []
                days.append(DayPlan(date: date, workouts: existing + templateWorkouts))
            } else {
                let existing = weekPlan.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.workouts ?? []
                let tombstoned = existing
                    .filter { !$0.metadata.isDeleted }
                    .map { SyncMetadata.softDelete($0) }
                let retainedTombstones = existing.filter { $0.metadata.isDeleted }
                days.append(DayPlan(date: date, workouts: retainedTombstones + tombstoned + templateWorkouts))
            }
        }
        weekPlan = WeekPlan(startOfWeek: start, days: days)
        currentStartOfWeek = start
        persistWeek()
    }

    func toggleStatus(workoutID: UUID) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                switch weekPlan.days[dayIdx].workouts[workoutIndex].status {
                case .imported:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .planned
                case .planned:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .completed
                case .completed, .partiallyCompleted:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .planned
                case .skipped:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .planned
                }
                weekPlan.days[dayIdx].workouts[workoutIndex].touchUpdatedAt()
                persistWeek()
                break
            }
        }
    }

    func removeWorkout(dayID: UUID, workoutID: UUID) {
        guard let dayIndex = weekPlan.days.firstIndex(where: { $0.id == dayID }) else { return }
        guard let workoutIndex = weekPlan.days[dayIndex].workouts.firstIndex(where: { $0.id == workoutID }) else {
            return
        }
        weekPlan.days[dayIndex].workouts[workoutIndex] = SyncMetadata.softDelete(
            weekPlan.days[dayIndex].workouts[workoutIndex]
        )
        persistWeek()
    }

    /// Moves a workout to another day in the current week. Keeps the same workout ID.
    @discardableResult
    func moveWorkout(workoutID: UUID, toDate: Date) -> Bool {
        guard let sourceDayIdx = weekPlan.days.firstIndex(where: { day in
            day.workouts.contains(where: { $0.id == workoutID && !$0.metadata.isDeleted })
        }) else { return false }
        guard let workoutIdx = weekPlan.days[sourceDayIdx].workouts.firstIndex(where: { $0.id == workoutID }) else {
            return false
        }
        guard let destDayIdx = dayIndex(for: toDate) else { return false }
        if calendar.isDate(weekPlan.days[sourceDayIdx].date, inSameDayAs: toDate) {
            return true
        }

        var workout = weekPlan.days[sourceDayIdx].workouts.remove(at: workoutIdx)
        workout.plannedDate = calendar.startOfDay(for: toDate)
        workout.touchUpdatedAt()
        weekPlan.days[destDayIdx].workouts.append(workout)
        persistWeek()
        return true
    }

    func workoutRequiresMoveConfirmation(workoutID: UUID) -> Bool {
        guard let workout = weekPlan.days.flatMap(\.activeWorkouts).first(where: { $0.id == workoutID }) else {
            return false
        }
        return workout.hasCompletedEnduranceDetail
            || workout.linkedHealthKitUUID != nil
            || workout.status == .completed
            || workout.status == .partiallyCompleted
            || workout.completedValues.completedStrengthRoutineSnapshot != nil
    }

    // MARK: - Clipboard (copy / paste)

    struct WorkoutClipboard {
        let source: Workout
    }

    @Published private(set) var workoutClipboard: WorkoutClipboard?

    func copyWorkout(workoutID: UUID) {
        guard let workout = weekPlan.days.flatMap(\.activeWorkouts).first(where: { $0.id == workoutID }) else {
            return
        }
        workoutClipboard = WorkoutClipboard(source: workout)
    }

    enum PasteMode {
        case plannedOnly
        case plannedAndCompleted
    }

    func pasteWorkout(on date: Date, mode: PasteMode) {
        guard let clipboard = workoutClipboard else { return }
        guard let dayIndex = dayIndex(for: date) else { return }
        let source = clipboard.source

        var planned = source.plannedValues
        var completed = CompletedValues.empty
        var status: WorkoutStatus = .planned
        var linkedHealthKitUUID: String? = nil
        var skipReason: String? = nil

        if mode == .plannedAndCompleted {
            completed = source.completedValues
            status = source.status == .skipped ? .planned : source.status
            linkedHealthKitUUID = source.linkedHealthKitUUID
            if source.status == .skipped {
                skipReason = nil
            }
        }

        let copy = Workout(
            id: UUID(),
            plannedDate: calendar.startOfDay(for: date),
            timePeriod: source.timePeriod,
            title: source.title,
            activityType: source.activityType,
            runType: source.runType,
            plannedValues: planned,
            completedValues: completed,
            status: status,
            source: source.source == .appleHealth && mode == .plannedAndCompleted ? .appleHealth : .manual,
            linkedWorkoutTemplateId: source.linkedWorkoutTemplateId,
            linkedWeeklyTemplateId: nil,
            linkedPeriodizedBlockId: nil,
            linkedHealthKitUUID: linkedHealthKitUUID,
            templateName: source.templateName,
            notes: source.notes,
            skipReason: skipReason
        )
        weekPlan.days[dayIndex].workouts.append(copy)
        persistWeek()
    }

    func setWorkoutStatus(workoutID: UUID, status: WorkoutStatus, note: String? = nil) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                weekPlan.days[dayIdx].workouts[workoutIndex].status = status
                if let note {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if status == .skipped {
                        weekPlan.days[dayIdx].workouts[workoutIndex].skipReason = trimmed.isEmpty ? nil : trimmed
                    } else {
                        weekPlan.days[dayIdx].workouts[workoutIndex].notes = trimmed.isEmpty ? nil : trimmed
                    }
                }
                weekPlan.days[dayIdx].workouts[workoutIndex].touchUpdatedAt()
                persistWeek()
                break
            }
        }
    }

    func setWorkoutNote(workoutID: UUID, note: String?) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                weekPlan.days[dayIdx].workouts[workoutIndex].notes = trimmed.isEmpty ? nil : trimmed
                weekPlan.days[dayIdx].workouts[workoutIndex].touchUpdatedAt()
                persistWeek()
                break
            }
        }
    }

    func updateCompletedStrengthSnapshot(workoutID: UUID, snapshot: StrengthRoutineSnapshot) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedStrengthRoutineSnapshot = snapshot
                if weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt == nil {
                    weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt = Date()
                }
                weekPlan.days[dayIdx].workouts[workoutIndex].touchUpdatedAt()
                persistWeek()
                break
            }
        }
    }

    func updateEnduranceWorkout(
        workoutID: UUID,
        title: String,
        runType: RunType?,
        plannedDistance: String,
        plannedDuration: String,
        plannedElevation: String,
        status: WorkoutStatus,
        actualDistance: String? = nil,
        actualDuration: String? = nil,
        actualElevation: String? = nil,
        timePeriod: TimePeriod? = nil
    ) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                WorkoutEditing.applyEnduranceSave(
                    to: &weekPlan.days[dayIdx].workouts[workoutIndex],
                    title: title,
                    runType: runType,
                    plannedDistance: plannedDistance,
                    plannedDuration: plannedDuration,
                    plannedElevation: plannedElevation,
                    actualDistance: actualDistance,
                    actualDuration: actualDuration,
                    actualElevation: actualElevation,
                    status: status,
                    timePeriod: timePeriod
                )
                persistWeek()
                break
            }
        }
    }

    func attachActualRun(to day: Date, run: UnattachedRun, toWorkoutID: UUID? = nil) {
        guard let dayIndex = weekPlan.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) else { return }
        if let targetID = toWorkoutID,
           let workoutIndex = weekPlan.days[dayIndex].workouts.firstIndex(where: { $0.id == targetID }) {
            WorkoutEditing.applyAttachedRun(run.detail, to: &weekPlan.days[dayIndex].workouts[workoutIndex])
        } else if let workoutIndex = weekPlan.days[dayIndex].workouts.firstIndex(where: {
            $0.activityType.sessionKind == .run && $0.hasPlannedEnduranceDetail && !$0.hasCompletedEnduranceDetail
        }) {
            WorkoutEditing.applyAttachedRun(run.detail, to: &weekPlan.days[dayIndex].workouts[workoutIndex])
        } else {
            var workout = Workout.run(
                plannedDate: day,
                title: run.detail.title.isEmpty ? "Run" : run.detail.title,
                imported: true,
                notes: "Imported from HealthKit"
            )
            WorkoutEditing.applyAttachedRun(run.detail, to: &workout)
            weekPlan.days[dayIndex].workouts.append(workout)
        }
        persistWeek()
    }

    func detachActualRun(workoutID: UUID) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                if let detail = WorkoutEditing.detachCompletedRun(from: &weekPlan.days[dayIdx].workouts[workoutIndex]) {
                    let unattached = UnattachedRun(detail: detail, date: weekPlan.days[dayIdx].date, source: "Detached")
                    addUnattachedRun(unattached)
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
            for workout in day.activeWorkouts where workout.activityType.sessionKind == .run {
                if workout.linkedHealthKitUUID == uuid { return true }
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
            for workout in day.activeWorkouts where workout.activityType.sessionKind == .run {
                if workout.hasPlannedEnduranceDetail {
                    sigs.insert(enduranceSignature(for: workout, planned: true, fallbackDate: day.date))
                }
                if workout.hasCompletedEnduranceDetail {
                    sigs.insert(enduranceSignature(for: workout, planned: false, fallbackDate: day.date))
                }
            }
        }
        return sigs
    }

    private func enduranceSignature(for workout: Workout, planned: Bool, fallbackDate: Date) -> String {
        if planned {
            let detail = RunDetailData(
                title: workout.title,
                notes: workout.plannedValues.plannedDescription ?? "",
                distance: workout.plannedDistance,
                duration: workout.plannedDuration,
                averageHR: "",
                category: workout.runType?.runCategory,
                hkWorkoutUUID: nil,
                elevationGain: workout.plannedElevation
            )
            return detailSignature(detail, fallbackDate: fallbackDate)
        }
        return detailSignature(WorkoutEditing.completedRunDetail(from: workout), fallbackDate: fallbackDate)
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
            var workouts: [Workout] = []
            if offset == 0, let template = templates.first {
                var workout = Workout.from(template: template, plannedDate: date)
                workout.notes = "Tap to log sets and mark complete"
                workouts.append(workout)
            }
            if offset == 2 {
                workouts.append(
                    Workout.run(
                        plannedDate: date,
                        title: "Easy Run 4 mi",
                        imported: false,
                        notes: "Will prompt to attach when HealthKit run is detected"
                    )
                )
            }
            if offset == 4, templates.count > 1 {
                var workout = Workout.from(template: templates[1], plannedDate: date)
                workout.notes = "Use template for progressive overload"
                workouts.append(workout)
            }
            return DayPlan(date: date, workouts: workouts)
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    static func makeEmptyWeek(calendar: Calendar, start: Date) -> WeekPlan {
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return DayPlan(date: date, workouts: [])
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    func exportCurrentWeek() -> URL? {
        do {
            var exportPlan = weekPlan
            var strengthLogsIncluded = 0

            for dayIdx in exportPlan.days.indices {
                for workoutIdx in exportPlan.days[dayIdx].workouts.indices {
                    let workout = exportPlan.days[dayIdx].workouts[workoutIdx]
                    guard workout.activityType == .strength else { continue }

                    let logURL = StrengthLogPersistence.strengthLogURL(for: workout.id)
                    if let log = StrengthLogPersistence.load(from: logURL) {
                        exportPlan.days[dayIdx].workouts[workoutIdx].completedValues.completedStrengthRoutineSnapshot =
                            strengthSnapshot(from: log)
                        strengthLogsIncluded += 1
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
            print("   Total workouts: \(exportPlan.days.flatMap { $0.workouts }.count)")
            print("   Strength logs included: \(strengthLogsIncluded)")
            return url
        } catch {
            print("❌ Failed to export week: \(error)")
            return nil
        }
    }

    func importWeek(from url: URL) {
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
            print("   Total workouts: \(imported.days.flatMap { $0.workouts }.count)")

            var strengthLogsRestored = 0
            for day in imported.days {
                for workout in day.workouts where workout.activityType == .strength {
                    if let snapshot = workout.completedValues.completedStrengthRoutineSnapshot {
                        let log = strengthLogState(from: snapshot, workout: workout)
                        let logURL = StrengthLogPersistence.strengthLogURL(for: workout.id)
                        try StrengthLogPersistence.save(log, to: logURL)
                        strengthLogsRestored += 1
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

    private func strengthSnapshot(from log: StrengthLogState) -> StrengthRoutineSnapshot {
        let exercises = log.exercises.enumerated().map { index, exercise in
            StrengthExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                orderIndex: index,
                targetSets: exercise.sets.enumerated().map { setIndex, set in
                    StrengthSetSnapshot(
                        id: set.id,
                        setNumber: setIndex + 1,
                        targetReps: Int(set.repHint.filter { $0.isNumber }),
                        targetWeight: parseDouble(from: set.weight),
                        repHint: set.repHint.isEmpty ? nil : set.repHint,
                        actualReps: set.reps.isEmpty ? nil : set.reps,
                        actualWeight: set.weight.isEmpty ? nil : set.weight
                    )
                },
                exerciseRPE: exercise.rpe.isEmpty ? nil : exercise.rpe
            )
        }
        return StrengthRoutineSnapshot(exercises: exercises)
    }

    private func strengthLogState(from snapshot: StrengthRoutineSnapshot, workout: Workout) -> StrengthLogState {
        let exercises = snapshot.exercises.sorted { $0.orderIndex < $1.orderIndex }.map { exercise in
            ExerciseLog(
                id: exercise.id,
                name: exercise.name,
                sets: exercise.targetSets.map { set in
                    SetLog(
                        id: set.id,
                        weight: set.actualWeight ?? (set.targetWeight.map { String(Int($0)) } ?? ""),
                        reps: set.actualReps ?? "",
                        repHint: set.repHint ?? set.targetReps.map(String.init) ?? ""
                    )
                },
                rpe: exercise.exerciseRPE ?? ""
            )
        }
        let isCompleted = workout.status == .completed || workout.status == .partiallyCompleted
        return StrengthLogState(
            sessionID: workout.id,
            exercises: exercises,
            isCompleted: isCompleted,
            updatedAt: workout.completedValues.completedAt ?? workout.metadata.updatedAt
        )
    }

    private func parseDouble(from string: String) -> Double? {
        let filtered = string.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty, let value = Double(filtered) else { return nil }
        return value
    }

    private func persistWeek(for start: Date? = nil) {
        weekPlan.updatedAt = Date()
        weekStore.save(weekPlan, start: start ?? currentStartOfWeek)
    }

    private func persistWeek() {
        persistWeek(for: currentStartOfWeek)
    }

    @MainActor
    func forceSync() async {
        persistWeek()
        persistUnattached()
        persistWeeklyTemplates()
        if let loaded = weekStore.loadWeek(start: currentStartOfWeek) {
            weekPlan = loaded
        }
        unattachedRuns = unattachedStore.loadRuns()
        weeklyTemplates = weeklyTemplateStore.loadTemplates()
    }
}
