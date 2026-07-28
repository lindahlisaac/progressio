import SwiftUI

struct HistoryView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var entries: [WeekPlannerViewModel.HistoryEntry] = []

    var body: some View {
        List {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No history yet",
                    systemImage: "clock",
                    description: Text("Completed, imported, and skipped workouts from your weeks will show up here.")
                )
            } else {
                ForEach(entries) { entry in
                    NavigationLink {
                        HistoryEntryDetailView(
                            entry: entry,
                            weekViewModel: weekViewModel,
                            onReload: reload
                        )
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
    }

    private func reload() {
        entries = weekViewModel.historyEntries()
    }
}

/// First-class reflection summary + link into the workout editor.
private struct HistoryEntryDetailView: View {
    let entry: WeekPlannerViewModel.HistoryEntry
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    var onReload: () -> Void

    @State private var showingEditWarning = false
    @State private var showingReflectionSheet = false

    private var reflection: ActivityReflection? {
        weekViewModel.activityReflection(for: entry.workout.id)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List {
            Section {
                LabeledContent("Workout", value: entry.workout.title)
                LabeledContent("Type", value: entry.workout.activityType.rawValue)
                LabeledContent("Status", value: entry.workout.status.badgeLabel)
            }

            Section("Reflection") {
                if let reflection {
                    reflectionDetails(reflection)
                    Button("Edit reflection") {
                        showingEditWarning = true
                    }
                } else {
                    Text("No reflection logged for this session.")
                        .foregroundStyle(.secondary)
                    Button("Add reflection") {
                        showingReflectionSheet = true
                    }
                }
            }

            Section {
                NavigationLink("Open workout") {
                    HistoryWorkoutDestination(
                        entry: entry,
                        weekViewModel: weekViewModel,
                        onReload: onReload
                    )
                }
            }
        }
        .navigationTitle(entry.workout.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { onReload() }
        .alert("Amend this reflection?", isPresented: $showingEditWarning) {
            Button("Edit anyway") {
                showingReflectionSheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reflections capture how the session felt at completion. Amend only for objective mistakes (wrong tap, typo)—not because your assessment changed later.")
        }
        .sheet(isPresented: $showingReflectionSheet) {
            ActivityReflectionSheet(
                viewModel: weekViewModel,
                workout: entry.workout,
                onSaved: {
                    if entry.workout.status != .completed && entry.workout.status != .partiallyCompleted {
                        weekViewModel.finalizeComplete(workoutID: entry.workout.id)
                    }
                    showingReflectionSheet = false
                    onReload()
                },
                onCancelled: {
                    showingReflectionSheet = false
                    onReload()
                },
                isFirstCapture: reflection == nil
            )
        }
    }

    @ViewBuilder
    private func reflectionDetails(_ reflection: ActivityReflection) -> some View {
        switch reflection.reflectionKind {
        case .standard:
            if let feel = reflection.feel {
                LabeledContent("Feel", value: feel.label)
            }
            if let rpe = reflection.sessionRPE {
                LabeledContent("Session RPE", value: "\(rpe)")
            }
        case .skip:
            LabeledContent("Kind", value: "Skip")
        }
        if let notes = reflection.performanceNotes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(notes)
            }
        }
        if let updated = reflection.updatedAt {
            LabeledContent("Updated", value: Self.dateTimeFormatter.string(from: updated))
        } else if let created = reflection.createdAt {
            LabeledContent("Logged", value: Self.dateTimeFormatter.string(from: created))
        }
    }
}

/// Workout editor destination used from History (same mutations as before).
private struct HistoryWorkoutDestination: View {
    let entry: WeekPlannerViewModel.HistoryEntry
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    var onReload: () -> Void

    @State private var showingReflectionSheet = false

    var body: some View {
        let workout = entry.workout
        Group {
            if workout.activityType == .strength {
                StrengthLogView(
                    workout: workout,
                    onNoteChange: { note in
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                            w.notes = trimmed.isEmpty ? nil : trimmed
                            w.touchUpdatedAt()
                        }
                        onReload()
                    },
                    onTitleChange: { title in
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            w.title = trimmed.isEmpty ? ActivityType.strength.defaultTitle : trimmed
                            w.touchUpdatedAt()
                        }
                        onReload()
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
                        onReload()
                        showingReflectionSheet = true
                    },
                    onUnlockStatus: {
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            w.status = .planned
                            w.touchUpdatedAt()
                        }
                        onReload()
                    },
                    onCompletedSnapshotPersist: { snapshot in
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            w.completedValues.completedStrengthRoutineSnapshot = snapshot
                            w.touchUpdatedAt()
                        }
                        onReload()
                    },
                    onTimePeriodChange: { period in
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            w.timePeriod = period
                            w.touchUpdatedAt()
                        }
                        onReload()
                    }
                )
            } else if workout.activityType == .stairMaster {
                StairMasterDetailView(
                    workout: workout,
                    onSave: { title, plannedDuration, plannedElevation, plannedLevel, status, actualDuration, actualElevation, actualLevel, timePeriod, notes in
                        let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
                        weekViewModel.mutateWorkout(weekStart: entry.weekStart, workoutID: workout.id) { w in
                            WorkoutEditing.applyEnduranceSave(
                                to: &w,
                                title: title,
                                runType: nil,
                                plannedDistance: "",
                                plannedDuration: plannedDuration,
                                plannedElevation: plannedElevation,
                                plannedLevel: plannedLevel,
                                actualDistance: nil,
                                actualDuration: actualDuration,
                                actualElevation: actualElevation,
                                actualLevel: actualLevel,
                                status: status,
                                timePeriod: timePeriod,
                                activityType: .stairMaster,
                                notes: notes
                            )
                        }
                        onReload()
                        if status == .completed, !wasComplete {
                            showingReflectionSheet = true
                        }
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
                        onReload()
                        if status == .completed, !wasComplete {
                            showingReflectionSheet = true
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
                        onReload()
                        if status == .completed, !wasComplete {
                            showingReflectionSheet = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingReflectionSheet) {
            ActivityReflectionSheet(
                viewModel: weekViewModel,
                workout: entry.workout,
                onSaved: {
                    showingReflectionSheet = false
                    onReload()
                },
                onCancelled: {
                    showingReflectionSheet = false
                    onReload()
                },
                isFirstCapture: weekViewModel.activityReflection(for: entry.workout.id) == nil
            )
        }
    }
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
                    Text(reflectionSubtitle(reflection))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("No reflection")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
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

    private func reflectionSubtitle(_ reflection: ActivityReflection) -> String {
        switch reflection.reflectionKind {
        case .skip:
            if let notes = reflection.performanceNotes, !notes.isEmpty {
                return "Skipped · \(notes)"
            }
            return "Skipped"
        case .standard:
            var parts: [String] = []
            if let feel = reflection.feel {
                parts.append(feel.label)
            }
            if let rpe = reflection.sessionRPE {
                parts.append("sRPE \(rpe)")
            }
            return parts.isEmpty ? "Reflection" : parts.joined(separator: " · ")
        }
    }
}
