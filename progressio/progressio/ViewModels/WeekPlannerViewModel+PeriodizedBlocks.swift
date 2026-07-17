import Foundation

extension WeekPlannerViewModel {

    // MARK: - Periodized blocks CRUD

    var activePeriodizedBlocks: [PeriodizedBlockTemplate] {
        periodizedBlocks.filter { !$0.isDeleted }
    }

    func addPeriodizedBlock(_ block: PeriodizedBlockTemplate) {
        let trimmed = block.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var copy = block
        copy.name = trimmed
        SyncMetadata.stampNewRecord(&copy)
        periodizedBlocks.append(copy)
        persistPeriodizedBlocks()
    }

    func addPeriodizedBlock(name: String, weekCount: Int, notes: String? = nil) {
        addPeriodizedBlock(PeriodizedBlockTemplate(name: name, weekCount: weekCount, notes: notes))
    }

    func updatePeriodizedBlock(_ block: PeriodizedBlockTemplate) {
        guard let index = periodizedBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        var next = periodizedBlocks
        var updated = block
        SyncMetadata.stampSave(&updated)
        next[index] = updated
        periodizedBlocks = next
        persistPeriodizedBlocks()
    }

    func deletePeriodizedBlock(id: UUID) {
        guard let index = periodizedBlocks.firstIndex(where: { $0.id == id }) else { return }
        var next = periodizedBlocks
        next[index] = SyncMetadata.softDelete(next[index])
        periodizedBlocks = next
        persistPeriodizedBlocks()
    }

    func persistPeriodizedBlocks() {
        // Persist as-is; callers stamp the records they mutate.
        periodizedBlockStore.save(periodizedBlocks)
    }

    // MARK: - Apply periodized block

    func periodizedBlockRangeHasWorkouts(startingAt start: Date, weekCount: Int) -> Bool {
        for offset in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .day, value: offset * 7, to: start) else { continue }
            let plan: WeekPlan
            if calendar.isDate(weekStart, inSameDayAs: currentStartOfWeek) {
                plan = weekPlan
            } else {
                plan = weekStore.loadWeek(start: weekStart)
                    ?? WeekPlannerViewModel.makeEmptyWeek(calendar: calendar, start: weekStart)
            }
            if plan.days.contains(where: { !$0.activeWorkouts.isEmpty }) {
                return true
            }
        }
        return false
    }

    func applyPeriodizedBlock(
        _ block: PeriodizedBlockTemplate,
        startingAt start: Date,
        keepExisting: Bool
    ) {
        let orderedWeeks = block.weeks.sorted { $0.weekIndex < $1.weekIndex }
        for (offset, blockWeek) in orderedWeeks.enumerated() {
            guard let weekStart = calendar.date(byAdding: .day, value: offset * 7, to: start) else { continue }
            applyBlockWeek(
                blockWeek,
                blockId: block.id,
                to: weekStart,
                keepExisting: keepExisting
            )
        }
        // Reload current week view if it was in range.
        if let loaded = weekStore.loadWeek(start: currentStartOfWeek) {
            weekPlan = loaded
        }
    }

    private func applyBlockWeek(
        _ blockWeek: PeriodizedBlockWeek,
        blockId: UUID,
        to weekStart: Date,
        keepExisting: Bool
    ) {
        withWeek(containing: weekStart) { plan in
            var days: [DayPlan] = []
            for offset in 0..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
                let weekday = calendar.component(.weekday, from: date)
                let templateWorkouts = (blockWeek.daySnapshots.first(where: { $0.weekday == weekday })?.workoutEntries ?? [])
                    .map {
                        $0.makeWorkout(
                            plannedDate: date,
                            linkedWeeklyTemplateId: blockWeek.linkedWeeklyTemplateId,
                            linkedPeriodizedBlockId: blockId
                        )
                    }

                let existing = plan.days.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.workouts ?? []
                if keepExisting {
                    days.append(DayPlan(date: date, workouts: existing + templateWorkouts))
                } else {
                    let tombstoned = existing
                        .filter { !$0.metadata.isDeleted }
                        .map { SyncMetadata.softDelete($0) }
                    let retainedTombstones = existing.filter { $0.metadata.isDeleted }
                    days.append(DayPlan(date: date, workouts: retainedTombstones + tombstoned + templateWorkouts))
                }
            }
            plan.days = days
            plan.appliedPeriodizedWeekName = blockWeek.displayName
            plan.appliedPeriodizedBlockId = blockId
        }
    }
}
