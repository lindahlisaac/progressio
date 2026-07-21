import SwiftUI

/// Sheet / alert presentations for week reflections and imports (split for type-checker).
struct WeekPlannerReflectionPresentations: ViewModifier {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @Binding var templatePickerContext: TemplatePickerContext?
    @Binding var showingUnattachedSheet: Bool
    @Binding var showingWeekExport: Bool
    @Binding var reflectionWorkoutID: UUID?
    @Binding var showingWeeklyReflection: Bool
    @Binding var showingWeekCloseValidation: Bool
    @Binding var showingSkipUnresolvedConfirm: Bool
    let reflectionWorkout: Workout?
    let modalityTemplatePicker: (TemplatePickerContext) -> AnyView

    func body(content: Content) -> some View {
        content
            .sheet(item: $templatePickerContext) { context in
                modalityTemplatePicker(context)
            }
            .sheet(isPresented: $showingUnattachedSheet) {
                NavigationStack {
                    UnattachedRunsView(
                        runs: viewModel.activeUnattachedRuns,
                        days: viewModel.weekPlan.days,
                        onAttach: { date, run, workoutID in
                            if let completedID = viewModel.attachActualRun(to: date, run: run, toWorkoutID: workoutID) {
                                showingUnattachedSheet = false
                                reflectionWorkoutID = completedID
                            }
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingUnattachedSheet = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingWeekExport) {
                WeekExportSummaryView(
                    weekPlan: viewModel.weekPlan,
                    periodizedWeekName: viewModel.weekPlan.appliedPeriodizedWeekName,
                    activityReflections: viewModel.activityReflections.filter { !$0.isDeleted },
                    weeklyReflection: viewModel.weeklyReflection(for: viewModel.currentWeekKey),
                    physicalIssues: viewModel.physicalIssues.filter { !$0.isDeleted }
                )
            }
            .sheet(item: Binding(
                get: { reflectionWorkout.map { IdentifiedWorkout(workout: $0) } },
                set: { reflectionWorkoutID = $0?.id }
            )) { item in
                ActivityReflectionSheet(viewModel: viewModel, workout: item.workout) {
                    reflectionWorkoutID = nil
                }
            }
            .sheet(isPresented: $showingWeeklyReflection) {
                WeeklyReflectionSheet(viewModel: viewModel) {
                    showingWeeklyReflection = false
                }
            }
            .alert("Unresolved workouts", isPresented: $showingWeekCloseValidation) {
                Button("Go back", role: .cancel) {}
                Button("Skip all unresolved", role: .destructive) {
                    showingSkipUnresolvedConfirm = true
                }
            } message: {
                let items = viewModel.unresolvedWorkoutsForWeekClose()
                let names = items.prefix(6).map { "\($0.workout.title) (\($0.workout.status.rawValue))" }.joined(separator: "\n")
                let more = items.count > 6 ? "\n…" : ""
                Text("Close out these workouts first, or skip them all:\n\(names)\(more)")
            }
            .alert("Skip all unresolved?", isPresented: $showingSkipUnresolvedConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Skip all", role: .destructive) {
                    viewModel.skipAllUnresolvedForWeekClose()
                    showingWeeklyReflection = true
                }
            } message: {
                Text("All planned or imported workouts still open will be marked skipped.")
            }
    }
}

struct IdentifiedWorkout: Identifiable {
    let workout: Workout
    var id: UUID { workout.id }
}

/// Made internal so presentation modifiers can use the same picker context type.
struct TemplatePickerContext: Identifiable {
    let id = UUID()
    let date: Date
    let activityType: ActivityType
    let timePeriod: TimePeriod
}
