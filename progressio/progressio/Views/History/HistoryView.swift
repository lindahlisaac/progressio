import SwiftUI

struct HistoryView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var entries: [WeekPlannerViewModel.HistoryEntry] = []
    @State private var reflectionWorkoutID: UUID?

    private var reflectionWorkout: Workout? {
        guard let id = reflectionWorkoutID else { return nil }
        return entries.first { $0.workout.id == id }?.workout
    }

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock",
                    description: Text("Completed and imported workouts from your weeks will show up here.")
                )
            } else {
                ForEach(entries) { entry in
                    NavigationLink {
                        historyDetail(for: entry)
                    } label: {
                        HistoryRow(
                            entry: entry,
                            reflection: weekViewModel.activityReflection(for: entry.workout.id)
                        )
                    }
                }
            }
        }
        .navigationTitle("History")
        .onAppear { reload() }
        .sheet(item: Binding(
            get: { reflectionWorkout.map { HistoryIdentifiedWorkout(workout: $0) } },
            set: { reflectionWorkoutID = $0?.id }
        )) { item in
            ActivityReflectionSheet(viewModel: weekViewModel, workout: item.workout) {
                reflectionWorkoutID = nil
                reload()
            }
        }
    }

    private func reload() {
        entries = weekViewModel.historyEntries()
    }

    @ViewBuilder
    private func historyDetail(for entry: WeekPlannerViewModel.HistoryEntry) -> some View {
        let workout = entry.workout
        if workout.activityType == .strength {
            StrengthLogView(
                workout: workout,
                onNoteChange: { note in
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        w.notes = trimmed.isEmpty ? nil : trimmed
                        w.touchUpdatedAt()
                    }
                    reload()
                },
                onTitleChange: { title in
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        w.title = trimmed.isEmpty ? ActivityType.strength.defaultTitle : trimmed
                        w.touchUpdatedAt()
                    }
                    reload()
                },
                loadPriorComparison: { liftNames in
                    weekViewModel.strengthComparison(for: workout, liftNames: liftNames)
                },
                onCompleteStatus: {
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        w.status = .completed
                        if w.completedValues.completedAt == nil {
                            w.completedValues.completedAt = Date()
                        }
                        w.touchUpdatedAt()
                    }
                    reload()
                    reflectionWorkoutID = workout.id
                },
                onUnlockStatus: {
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        w.status = .planned
                        w.touchUpdatedAt()
                    }
                    reload()
                },
                onCompletedSnapshotPersist: { snapshot in
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        w.completedValues.completedStrengthRoutineSnapshot = snapshot
                        w.touchUpdatedAt()
                    }
                    reload()
                },
                onTimePeriodChange: { period in
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        w.timePeriod = period
                        w.touchUpdatedAt()
                    }
                    reload()
                }
            )
        } else if workout.activityType.sessionKind == .run {
            RunDetailView(
                workout: workout,
                onSave: { title, activityType, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        WorkoutEditing.applyEnduranceSave(
                            to: &w,
                            title: title,
                            runType: category.flatMap(RunType.init(runCategory:)),
                            plannedDistance: plannedDistance,
                            plannedDuration: plannedDuration,
                            plannedElevation: plannedElevation,
                            actualDistance: actualDistance,
                            actualDuration: actualDuration,
                            actualElevation: actualElevation,
                            status: status,
                            timePeriod: timePeriod,
                            activityType: activityType,
                            notes: notes
                        )
                    }
                    reload()
                    if status == .completed, !wasComplete {
                        reflectionWorkoutID = workout.id
                    }
                }
            )
        } else {
            RideDetailView(
                workout: workout,
                onSave: { title, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
                    weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                        WorkoutEditing.applyEnduranceSave(
                            to: &w,
                            title: title,
                            runType: category.flatMap(RunType.init(runCategory:)),
                            plannedDistance: plannedDistance,
                            plannedDuration: plannedDuration,
                            plannedElevation: plannedElevation,
                            actualDistance: actualDistance,
                            actualDuration: actualDuration,
                            actualElevation: actualElevation,
                            status: status,
                            timePeriod: timePeriod,
                            notes: notes
                        )
                    }
                    reload()
                    if status == .completed, !wasComplete {
                        reflectionWorkoutID = workout.id
                    }
                }
            )
        }
    }
}

private struct HistoryIdentifiedWorkout: Identifiable {
    let workout: Workout
    var id: UUID { workout.id }
}

private struct HistoryRow: View {
    let entry: WeekPlannerViewModel.HistoryEntry
    var reflection: ActivityReflection?

    private var summary: String {
        let workout = entry.workout
        if workout.activityType == .strength {
            let count = workout.completedValues.completedStrengthRoutineSnapshot?.exercises.count
                ?? workout.plannedValues.plannedStrengthRoutineSnapshot?.exercises.count
                ?? 0
            return count > 0 ? "\(count) exercises" : "Strength"
        }
        let distance = workout.completedValues.completedDistance ?? workout.plannedValues.plannedDistance
        let duration = workout.completedValues.completedDuration ?? workout.plannedValues.plannedDuration
        if let distance, !distance.isEmpty {
            return "\(distance) mi"
        }
        if let duration, !duration.isEmpty {
            return duration
        }
        return workout.activityType.rawValue
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.workout.activityType.systemImage)
                .foregroundStyle(entry.workout.status.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.workout.title)
                    .font(.body.weight(.medium))
                Text(dateLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reflection {
                    Text("\(reflection.feel.label) · sRPE \(reflection.sessionRPE)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.workout.status.badgeLabel)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(entry.workout.status.tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(entry.workout.status.tint)
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: entry.dayDate)) · \(entry.workout.activityType.rawValue)"
    }
}
