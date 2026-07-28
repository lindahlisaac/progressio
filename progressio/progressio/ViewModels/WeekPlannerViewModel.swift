import Foundation
import SwiftUI
import CryptoKit
import Combine

final class WeekPlannerViewModel: ObservableObject {
    let calendar: Calendar
    let weekStore: WeekPlanStore
    private let unattachedStore: UnattachedRunStore
    private let weeklyTemplateStore: WeeklyTemplateStore
    private let importedHealthStore: ImportedHealthWorkoutReferenceStore
    let periodizedBlockStore: PeriodizedBlockStore
    let activityReflectionStore: ActivityReflectionStore
    let weeklyReflectionStore: WeeklyReflectionStore
    let physicalIssueStore: PhysicalIssueStore
    let activityIssueReportStore: ActivityIssueReportStore
    let weeklyIssueReviewStore: WeeklyIssueReviewStore
    private let isoFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    @Published var weekPlan: WeekPlan
    @Published var currentStartOfWeek: Date
    @Published private(set) var unattachedRuns: [UnattachedRun] = []
    @Published private(set) var weeklyTemplates: [WeeklyTemplate] = []
    @Published var importedHealthReferences: [ImportedHealthWorkoutReference] = []
    @Published var periodizedBlocks: [PeriodizedBlockTemplate] = []
    @Published var activityReflections: [ActivityReflection] = []
    @Published var weeklyReflections: [WeeklyReflection] = []
    @Published var physicalIssues: [PhysicalIssue] = []
    @Published var activityIssueReports: [ActivityIssueReport] = []
    @Published var weeklyIssueReviews: [WeeklyIssueReview] = []
    @Published var lastHealthKitImportAt: Date?
    @Published var lastSyncAt: Date?
    @Published var lastSyncMessage: String?
    var inflightHealthKitUUIDs: Set<String> = []

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
         weeklyTemplateStore: WeeklyTemplateStore = SyncingWeeklyTemplateStore(),
         importedHealthStore: ImportedHealthWorkoutReferenceStore = SyncingImportedHealthWorkoutReferenceStore(),
         periodizedBlockStore: PeriodizedBlockStore = SyncingPeriodizedBlockStore(),
         activityReflectionStore: ActivityReflectionStore = SyncingActivityReflectionStore(),
         weeklyReflectionStore: WeeklyReflectionStore = SyncingWeeklyReflectionStore(),
         physicalIssueStore: PhysicalIssueStore = SyncingPhysicalIssueStore(),
         activityIssueReportStore: ActivityIssueReportStore = SyncingActivityIssueReportStore(),
         weeklyIssueReviewStore: WeeklyIssueReviewStore = SyncingWeeklyIssueReviewStore()) {
        self.calendar = calendar
        self.weekStore = weekStore
        self.unattachedStore = unattachedStore
        self.weeklyTemplateStore = weeklyTemplateStore
        self.importedHealthStore = importedHealthStore
        self.periodizedBlockStore = periodizedBlockStore
        self.activityReflectionStore = activityReflectionStore
        self.weeklyReflectionStore = weeklyReflectionStore
        self.physicalIssueStore = physicalIssueStore
        self.activityIssueReportStore = activityIssueReportStore
        self.weeklyIssueReviewStore = weeklyIssueReviewStore
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
        self.importedHealthReferences = importedHealthStore.loadReferences()
        self.periodizedBlocks = periodizedBlockStore.loadBlocks()
        self.activityReflections = activityReflectionStore.load()
        self.weeklyReflections = weeklyReflectionStore.load()
        self.physicalIssues = physicalIssueStore.load()
        self.activityIssueReports = activityIssueReportStore.load()
        self.weeklyIssueReviews = weeklyIssueReviewStore.load()
        self.lastHealthKitImportAt = UserDefaults.standard.object(forKey: Self.lastHealthKitImportKey) as? Date
        self.lastSyncAt = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date
        self.lastSyncMessage = UserDefaults.standard.string(forKey: Self.lastSyncMessageKey)
        dedupeUnattachedRuns()
    }

    private static let lastHealthKitImportKey = "progressio.lastHealthKitImportAt"
    private static let lastSyncKey = "progressio.lastSyncAt"
    private static let lastSyncMessageKey = "progressio.lastSyncMessage"

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
        var next = weeklyTemplates
        next[idx] = SyncMetadata.softDelete(next[idx])
        weeklyTemplates = next
        persistWeeklyTemplates()
    }

    func updateWeeklyTemplate(id: UUID, name: String, note: String?, days: [DayTemplate]) {
        guard let idx = weeklyTemplates.firstIndex(where: { $0.id == id }) else { return }
        var next = weeklyTemplates
        next[idx].name = name
        next[idx].note = note
        next[idx].days = days
        SyncMetadata.stampSave(&next[idx])
        weeklyTemplates = next
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

    /// Toggles workout status. Returns `true` when the workout newly becomes `.completed`.
    @discardableResult
    func toggleStatus(workoutID: UUID) -> Bool {
        var becameCompleted = false
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                switch weekPlan.days[dayIdx].workouts[workoutIndex].status {
                case .imported:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .planned
                case .planned:
                    weekPlan.days[dayIdx].workouts[workoutIndex].status = .completed
                    if weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt == nil {
                        weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt = Date()
                    }
                    becameCompleted = true
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
        return becameCompleted
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
        softDeleteReflections(forWorkoutID: workoutID)
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
                if status == .completed || status == .partiallyCompleted {
                    if weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt == nil {
                        weekPlan.days[dayIdx].workouts[workoutIndex].completedValues.completedAt = Date()
                    }
                }
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

    func setWorkoutTitle(workoutID: UUID, title: String) {
        for dayIdx in weekPlan.days.indices {
            if let workoutIndex = weekPlan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                weekPlan.days[dayIdx].workouts[workoutIndex].title =
                    trimmed.isEmpty ? ActivityType.strength.defaultTitle : trimmed
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
        plannedLevel: String? = nil,
        status: WorkoutStatus,
        actualDistance: String? = nil,
        actualDuration: String? = nil,
        actualElevation: String? = nil,
        actualLevel: String? = nil,
        timePeriod: TimePeriod? = nil,
        activityType: ActivityType? = nil,
        notes: String? = nil
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
                    plannedLevel: plannedLevel,
                    actualDistance: actualDistance,
                    actualDuration: actualDuration,
                    actualElevation: actualElevation,
                    actualLevel: actualLevel,
                    status: status,
                    timePeriod: timePeriod,
                    activityType: activityType,
                    notes: notes
                )
                persistWeek()
                break
            }
        }
    }

    /// Attaches an imported run to a planned workout (or creates an ad-hoc completed workout).
    /// Returns the workout ID when status newly becomes `.completed` (for reflection sheet).
    @discardableResult
    func attachActualRun(to day: Date, run: UnattachedRun, toWorkoutID: UUID? = nil) -> UUID? {
        guard let dayIndex = weekPlan.days.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) else {
            return nil
        }
        var linkedWorkoutID: UUID?
        var newlyCompletedID: UUID?

        if let targetID = toWorkoutID,
           let workoutIndex = weekPlan.days[dayIndex].workouts.firstIndex(where: { $0.id == targetID }) {
            let priorStatus = weekPlan.days[dayIndex].workouts[workoutIndex].status
            WorkoutEditing.applyAttachedRun(run.detail, to: &weekPlan.days[dayIndex].workouts[workoutIndex])
            linkedWorkoutID = targetID
            if priorStatus != .completed {
                newlyCompletedID = targetID
            }
        } else if let workoutIndex = weekPlan.days[dayIndex].workouts.firstIndex(where: {
            $0.activityType == run.activityType
                && $0.hasPlannedEnduranceDetail
                && !$0.hasCompletedEnduranceDetail
        }) {
            let priorStatus = weekPlan.days[dayIndex].workouts[workoutIndex].status
            WorkoutEditing.applyAttachedRun(run.detail, to: &weekPlan.days[dayIndex].workouts[workoutIndex])
            linkedWorkoutID = weekPlan.days[dayIndex].workouts[workoutIndex].id
            if priorStatus != .completed {
                newlyCompletedID = linkedWorkoutID
            }
        } else {
            var workout = Workout.manual(
                activityType: run.activityType,
                plannedDate: day,
                title: run.detail.title.isEmpty ? run.activityType.defaultTitle : run.detail.title,
                notes: "Imported from HealthKit"
            )
            workout.status = .imported
            workout.source = .appleHealth
            WorkoutEditing.applyAttachedRun(run.detail, to: &workout)
            linkedWorkoutID = workout.id
            newlyCompletedID = workout.id
            weekPlan.days[dayIndex].workouts.append(workout)
        }
        if let uuid = run.detail.hkWorkoutUUID {
            recordImportedReference(
                healthKitUUID: uuid,
                linkedWorkoutId: linkedWorkoutID,
                activityType: run.activityType,
                workoutStartDate: run.date
            )
        }
        removeUnattachedRun(id: run.id)
        persistWeek()
        return newlyCompletedID
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

    func hasAttachedRun(with uuid: String) -> Bool {
        let normalized = uuid.lowercased()
        for day in weekPlan.days {
            for workout in day.activeWorkouts where workout.activityType.sessionKind == .run {
                if workout.linkedHealthKitUUID?.lowercased() == normalized { return true }
            }
        }
        return false
    }

    func persistImportedHealthReferences() {
        importedHealthReferences = importedHealthReferences.map { reference in
            var stamped = reference
            SyncMetadata.stampSave(&stamped)
            return stamped
        }
        importedHealthStore.save(importedHealthReferences)
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
            let strengthSnapshotsIncluded = weekPlan.days
                .flatMap(\.workouts)
                .filter {
                    $0.activityType == .strength
                        && $0.completedValues.completedStrengthRoutineSnapshot != nil
                }
                .count

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(weekPlan)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("weekplan-\(isoFormatter.string(from: currentStartOfWeek)).json")
            try data.write(to: url, options: .atomic)
            print("📤 Exported week to: \(url.path)")
            print("   Strength snapshots included: \(strengthSnapshotsIncluded)")
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
            // Snapshots travel with the week plan — no strengthlog-*.json rewrite.
            self.weekPlan = imported
            self.currentStartOfWeek = imported.startOfWeek
            persistWeek(for: imported.startOfWeek)
            print("💾 Imported week persisted (snapshots embedded)")
        } catch {
            print("❌ Failed to import week: \(error)")
        }
    }

    func persistWeek(for start: Date? = nil) {
        weekPlan.updatedAt = Date()
        weekStore.save(weekPlan, start: start ?? currentStartOfWeek)
    }

    func persistWeek() {
        persistWeek(for: currentStartOfWeek)
    }

    @MainActor
    func forceSync() async {
        persistWeek()
        persistUnattached()
        persistWeeklyTemplates()
        persistImportedHealthReferences()
        persistPeriodizedBlocks()
        persistActivityReflections()
        persistWeeklyReflections()
        persistPhysicalIssues()
        persistActivityIssueReports()
        persistWeeklyIssueReviews()
        if let loaded = weekStore.loadWeek(start: currentStartOfWeek) {
            weekPlan = loaded
        }
        unattachedRuns = unattachedStore.loadRuns()
        weeklyTemplates = weeklyTemplateStore.loadTemplates()
        importedHealthReferences = importedHealthStore.loadReferences()
        periodizedBlocks = periodizedBlockStore.loadBlocks()
        activityReflections = activityReflectionStore.load()
        weeklyReflections = weeklyReflectionStore.load()
        physicalIssues = physicalIssueStore.load()
        activityIssueReports = activityIssueReportStore.load()
        weeklyIssueReviews = weeklyIssueReviewStore.load()
        let now = Date()
        lastSyncAt = now
        lastSyncMessage = "Synced via CloudKit"
        UserDefaults.standard.set(now, forKey: Self.lastSyncKey)
        UserDefaults.standard.set(lastSyncMessage, forKey: Self.lastSyncMessageKey)
    }

    /// Soft-deletes duplicate unattached rows and strips auto-imported calendar workouts
    /// (Apple Health / `.imported`) across all on-disk weeks, restoring unique UUIDs to Unattached
    /// for manual attach. Planned workouts that are not imports are left alone.
    @discardableResult
    func cleanupDuplicateImports() -> Int {
        var removed = 0
        var recoveredByUUID: [String: UnattachedRun] = [:]

        // Deduplicate unattached by HealthKit UUID (keep first).
        var seenUnattached = Set<String>()
        for index in unattachedRuns.indices {
            guard !unattachedRuns[index].isDeleted,
                  let uuid = unattachedRuns[index].detail.hkWorkoutUUID?.lowercased(),
                  !uuid.isEmpty
            else { continue }
            if seenUnattached.contains(uuid) {
                unattachedRuns[index] = SyncMetadata.softDelete(unattachedRuns[index])
                removed += 1
            } else {
                seenUnattached.insert(uuid)
                recoveredByUUID[uuid] = unattachedRuns[index]
            }
        }

        let localWeeks = FileWeekPlanStore()
        for weekStart in WeekPlanFileIndex.allWeekStarts() {
            let isCurrent = calendar.isDate(weekStart, inSameDayAs: currentStartOfWeek)
            var plan = isCurrent
                ? weekPlan
                : (localWeeks.loadWeek(start: weekStart) ?? WeekPlannerViewModel.makeEmptyWeek(calendar: calendar, start: weekStart))
            var planChanged = false

            for dayIdx in plan.days.indices {
                for workoutIdx in plan.days[dayIdx].workouts.indices {
                    let workout = plan.days[dayIdx].workouts[workoutIdx]
                    guard !workout.metadata.isDeleted,
                          workout.source == .appleHealth || workout.status == .imported
                    else { continue }

                    if let uuid = workout.linkedHealthKitUUID?.lowercased(), !uuid.isEmpty {
                        if recoveredByUUID[uuid] == nil {
                            let detail = WorkoutEditing.completedRunDetail(from: workout)
                            recoveredByUUID[uuid] = UnattachedRun(
                                detail: detail,
                                date: plan.days[dayIdx].date,
                                source: "Apple Health"
                            )
                        }
                    }

                    plan.days[dayIdx].workouts[workoutIdx] = SyncMetadata.softDelete(workout)
                    removed += 1
                    planChanged = true
                }
            }

            if planChanged {
                if isCurrent {
                    weekPlan = plan
                    persistWeek()
                } else {
                    localWeeks.save(plan, start: weekStart)
                }
            }
        }

        // Restore unique imports to Unattached and seed UUID references.
        var unattachedChanged = removed > 0
        for (uuid, run) in recoveredByUUID {
            if !seenUnattached.contains(uuid) {
                var stamped = run
                SyncMetadata.stampNewRecord(&stamped)
                unattachedRuns.append(stamped)
                seenUnattached.insert(uuid)
                unattachedChanged = true
            }
            recordImportedReference(
                healthKitUUID: uuid,
                linkedWorkoutId: nil,
                activityType: .roadRun,
                workoutStartDate: run.date
            )
        }
        if unattachedChanged {
            dedupeUnattachedRuns()
            persistUnattached()
        }
        return removed
    }

    func recordHealthKitImportTimestamp() {
        let now = Date()
        lastHealthKitImportAt = now
        UserDefaults.standard.set(now, forKey: Self.lastHealthKitImportKey)
    }

    // MARK: - History

    struct HistoryEntry: Identifiable, Equatable {
        var id: UUID { workout.id }
        let weekStart: Date
        let dayDate: Date
        let workout: Workout
    }

    func historyEntries() -> [HistoryEntry] {
        var entries: [HistoryEntry] = []
        let weekStarts = WeekPlanFileIndex.allWeekStarts()
        // Local files only — SyncingWeekPlanStore would CloudKit-fetch every week on each History appear.
        let localWeeks = FileWeekPlanStore()
        for weekStart in weekStarts {
            let plan: WeekPlan
            if calendar.isDate(weekStart, inSameDayAs: currentStartOfWeek) {
                plan = weekPlan
            } else if let loaded = localWeeks.loadWeek(start: weekStart) {
                plan = loaded
            } else {
                continue
            }
            for day in plan.days {
                for workout in day.activeWorkouts where Self.isHistoryEligible(workout) {
                    entries.append(HistoryEntry(weekStart: weekStart, dayDate: day.date, workout: workout))
                }
            }
        }
        return entries.sorted { lhs, rhs in
            let lhsDate = lhs.workout.completedValues.completedAt ?? lhs.dayDate
            let rhsDate = rhs.workout.completedValues.completedAt ?? rhs.dayDate
            return lhsDate > rhsDate
        }
    }

    private static func isHistoryEligible(_ workout: Workout) -> Bool {
        switch workout.status {
        case .completed, .partiallyCompleted, .imported:
            return true
        case .planned, .skipped:
            return false
        }
    }

    func mutateWorkout(
        weekStart: Date,
        workoutID: UUID,
        mutate: (inout Workout) -> Void
    ) {
        withWeek(containing: weekStart) { plan in
            // withWeek uses date's week — weekStart is Monday; mutate across days.
            for dayIdx in plan.days.indices {
                if let workoutIndex = plan.days[dayIdx].workouts.firstIndex(where: { $0.id == workoutID }) {
                    mutate(&plan.days[dayIdx].workouts[workoutIndex])
                    return
                }
            }
        }
    }

    /// Newest-first local scan for prior strength performance (per-lift + similar session).
    func strengthComparison(for workout: Workout, liftNames: [String]) -> StrengthComparisonResult {
        StrengthHistoryLookup.compare(
            current: workout,
            currentLiftNames: liftNames,
            currentWeekPlan: weekPlan,
            calendar: calendar
        )
    }
}
