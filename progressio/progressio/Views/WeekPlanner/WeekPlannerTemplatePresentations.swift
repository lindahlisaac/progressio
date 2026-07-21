import SwiftUI

struct WeekPlannerTemplatePresentations: ViewModifier {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @Binding var showingWeeklyTemplatePicker: Bool
    @Binding var showingPeriodizedBlockPicker: Bool
    @Binding var showingSaveWeekAsTemplate: Bool
    @Binding var saveTemplateName: String
    @Binding var saveTemplateNote: String
    @Binding var selectedWeeklyTemplate: WeeklyTemplate?
    @Binding var selectedPeriodizedBlock: PeriodizedBlockTemplate?
    @Binding var showingApplyTemplateAlert: Bool
    @Binding var showingApplyPeriodizedAlert: Bool
    @Binding var showingSkipSheet: Bool
    @Binding var skipNote: String
    @Binding var skipSessionID: UUID?
    @Binding var showingMoveConfirm: Bool
    @Binding var pendingMoveWorkoutID: UUID?
    @Binding var pendingMoveDate: Date?
    @Binding var showingPasteModeAlert: Bool
    @Binding var pasteTargetDate: Date?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingWeeklyTemplatePicker) {
                NavigationStack {
                    List {
                        ForEach(viewModel.activeWeeklyTemplates) { template in
                            Button {
                                selectedWeeklyTemplate = template
                                showingWeeklyTemplatePicker = false
                                showingApplyTemplateAlert = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.primary)
                                    if let note = template.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(template.days.flatMap { $0.workoutEntries }.count) workouts")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Apply Weekly Template")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingWeeklyTemplatePicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingPeriodizedBlockPicker) {
                NavigationStack {
                    List {
                        ForEach(viewModel.activePeriodizedBlocks) { block in
                            Button {
                                selectedPeriodizedBlock = block
                                showingPeriodizedBlockPicker = false
                                showingApplyPeriodizedAlert = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(block.name)
                                        .font(.body.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("\(block.weekCount) weeks · \(block.weeks.map(\.displayName).joined(separator: " → "))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                    .navigationTitle("Apply Periodized Block")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingPeriodizedBlockPicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSaveWeekAsTemplate) {
                NavigationStack {
                    Form {
                        Section("Template Info") {
                            TextField("Name", text: $saveTemplateName)
                            TextField("Note (optional)", text: $saveTemplateNote, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                        Section {
                            Text("Saves a snapshot of the currently viewed week. Later edits to the week will not change this template.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .navigationTitle("Save Week as Template")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingSaveWeekAsTemplate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let name = saveTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !name.isEmpty else { return }
                                let note = saveTemplateNote.trimmingCharacters(in: .whitespacesAndNewlines)
                                viewModel.saveWeeklyTemplate(
                                    name: name,
                                    note: note.isEmpty ? nil : note
                                )
                                showingSaveWeekAsTemplate = false
                            }
                            .disabled(saveTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSkipSheet) {
                NavigationStack {
                    Form {
                        Section("Skip note (optional)") {
                            TextEditor(text: $skipNote)
                                .frame(minHeight: 120)
                        }
                    }
                    .navigationTitle("Skip session")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingSkipSheet = false
                                skipSessionID = nil
                                skipNote = ""
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Skip") {
                                if let id = skipSessionID {
                                    viewModel.setWorkoutStatus(workoutID: id, status: .skipped, note: skipNote)
                                }
                                showingSkipSheet = false
                                skipSessionID = nil
                                skipNote = ""
                            }
                        }
                    }
                }
            }
            .alert("Apply Template to Current Week?", isPresented: $showingApplyTemplateAlert, presenting: selectedWeeklyTemplate) { template in
                if viewModel.hasWorkoutsInCurrentWeek() {
                    Button("Override existing") {
                        viewModel.applyWeeklyTemplate(template, to: viewModel.currentStartOfWeek, keepExisting: false)
                    }
                    Button("Keep existing") {
                        viewModel.applyWeeklyTemplate(template, to: viewModel.currentStartOfWeek, keepExisting: true)
                    }
                    Button("Cancel", role: .cancel) { }
                } else {
                    Button("Apply") {
                        viewModel.applyWeeklyTemplate(template, to: viewModel.currentStartOfWeek, keepExisting: false)
                    }
                    Button("Cancel", role: .cancel) { }
                }
            } message: { template in
                if viewModel.hasWorkoutsInCurrentWeek() {
                    Text("You have existing workouts this week. Choose to override them or keep them alongside '\(template.name)'.")
                } else {
                    Text("This will apply '\(template.name)' to the current week.")
                }
            }
            .alert("Apply Periodized Block?", isPresented: $showingApplyPeriodizedAlert, presenting: selectedPeriodizedBlock) { block in
                let hasConflicts = viewModel.periodizedBlockRangeHasWorkouts(
                    startingAt: viewModel.currentStartOfWeek,
                    weekCount: block.weekCount
                )
                if hasConflicts {
                    Button("Merge") {
                        viewModel.applyPeriodizedBlock(block, startingAt: viewModel.currentStartOfWeek, keepExisting: true)
                    }
                    Button("Overwrite", role: .destructive) {
                        viewModel.applyPeriodizedBlock(block, startingAt: viewModel.currentStartOfWeek, keepExisting: false)
                    }
                    Button("Cancel", role: .cancel) {}
                } else {
                    Button("Apply") {
                        viewModel.applyPeriodizedBlock(block, startingAt: viewModel.currentStartOfWeek, keepExisting: true)
                    }
                    Button("Cancel", role: .cancel) {}
                }
            } message: { block in
                let hasConflicts = viewModel.periodizedBlockRangeHasWorkouts(
                    startingAt: viewModel.currentStartOfWeek,
                    weekCount: block.weekCount
                )
                if hasConflicts {
                    Text("“\(block.name)” spans \(block.weekCount) weeks from this Plan week. Existing workouts found — Merge keeps them, Overwrite replaces them.")
                } else {
                    Text("Apply “\(block.name)” (\(block.weekCount) weeks) starting from this Plan week?")
                }
            }
            .alert("Move workout?", isPresented: $showingMoveConfirm) {
                Button("Move") {
                    if let id = pendingMoveWorkoutID, let date = pendingMoveDate {
                        _ = viewModel.moveWorkout(workoutID: id, toDate: date)
                    }
                    pendingMoveWorkoutID = nil
                    pendingMoveDate = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingMoveWorkoutID = nil
                    pendingMoveDate = nil
                }
            } message: {
                Text("This workout has completed or HealthKit data. Move it to the new day?")
            }
            .alert("Paste workout", isPresented: $showingPasteModeAlert) {
                Button("Planned only") {
                    if let date = pasteTargetDate {
                        viewModel.pasteWorkout(on: date, mode: .plannedOnly)
                    }
                    pasteTargetDate = nil
                }
                Button("Planned + completed") {
                    if let date = pasteTargetDate {
                        viewModel.pasteWorkout(on: date, mode: .plannedAndCompleted)
                    }
                    pasteTargetDate = nil
                }
                Button("Cancel", role: .cancel) {
                    pasteTargetDate = nil
                }
            } message: {
                Text("Include completed values from the copied workout?")
            }
    }
}
