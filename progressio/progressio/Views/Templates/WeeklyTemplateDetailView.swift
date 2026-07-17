import SwiftUI

struct WeeklyTemplateDetailView: View {
    let template: WeeklyTemplate
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @ObservedObject var templatesViewModel: TemplateLibraryViewModel
    
    @State private var showingEdit = false
    @State private var editName: String = ""
    @State private var editNote: String = ""
    @State private var editDraftDays: [DayTemplate] = []
    @State private var showingWorkoutTemplatePicker = false
    @State private var selectedDayIndexForTemplate: Int?
    
    var body: some View {
        List {
            if let note = template.note, !note.isEmpty {
                Section("Note") {
                    Text(note)
                }
            }
            
            ForEach(orderedDays, id: \.id) { day in
                Section(weekdayName(day.weekday)) {
                    if day.workoutEntries.isEmpty {
                        Text("Rest day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(day.workoutEntries) { entry in
                            if entry.activityType == .strength,
                               let snapshot = entry.plannedValues.plannedStrengthRoutineSnapshot {
                                NavigationLink {
                                    StrengthRoutineSnapshotDetailView(
                                        title: entry.title,
                                        snapshot: snapshot
                                    )
                                } label: {
                                    weeklyTemplateEntryRow(entry)
                                }
                            } else {
                                weeklyTemplateEntryRow(entry)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: nil) {
            editSheet
                .onAppear {
                    // Initialize state when sheet appears
                    editName = template.name
                    editNote = template.note ?? ""
                    editDraftDays = template.days
                }
        }
    }
    
    private var orderedDays: [DayTemplate] {
        template.days.sorted { lhs, rhs in
            let order: (Int) -> Int = { $0 == 1 ? 8 : $0 }
            return order(lhs.weekday) < order(rhs.weekday)
        }
    }
    
    private var editSheet: some View {
        NavigationStack {
            editForm
                .navigationTitle("Edit Weekly Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEdit = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveEdits()
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .sheet(isPresented: $showingWorkoutTemplatePicker) {
                    workoutTemplatePickerSheet
                }
        }
    }
    
    private var editForm: some View {
        let sortedIndices = editDraftDays.indices.sorted { lhs, rhs in
            let order: (Int) -> Int = { $0 == 1 ? 8 : $0 }
            return order(editDraftDays[lhs].weekday) < order(editDraftDays[rhs].weekday)
        }
        
        return Form {
            Section("Info") {
                TextField("Name", text: $editName)
                TextField("Note (optional)", text: $editNote, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            
            ForEach(sortedIndices, id: \.self) { idx in
                weeklyDaySection(idx: idx, weekday: editDraftDays[idx].weekday)
            }
        }
    }
    
    @ViewBuilder
    private func weeklyDaySection(idx: Int, weekday: Int) -> some View {
        Section {
            if editDraftDays[idx].workoutEntries.isEmpty {
                Text("No workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(editDraftDays[idx].workoutEntries) { entry in
                    HStack {
                        Image(systemName: entry.activityType.sessionKind.systemImage)
                            .foregroundStyle(.secondary)
                        Text(entry.title)
                        Spacer()
                        Text(entry.activityType.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    editDraftDays[idx].workoutEntries.remove(atOffsets: offsets)
                }
            }

            Menu {
                ForEach(ActivityType.plannerAddTypes) { activityType in
                    Button("Blank \(activityType.rawValue)") {
                        editDraftDays[idx].workoutEntries.append(
                            WeeklyTemplateWorkoutEntry.blank(activityType: activityType)
                        )
                    }
                }
                Divider()
                Button("From template...") {
                    selectedDayIndexForTemplate = idx
                    showingWorkoutTemplatePicker = true
                }
            } label: {
                Label("Add workout", systemImage: "plus.circle")
            }
        } header: {
            Text(weekdayName(weekday))
        }
    }
    
    private var workoutTemplatePickerSheet: some View {
        NavigationStack {
            templatePickerList
                .navigationTitle("Select Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingWorkoutTemplatePicker = false
                        }
                    }
                }
        }
    }
    
    private var templatePickerList: some View {
        List {
            if !templatesViewModel.activeTemplates.isEmpty {
                Section("Strength") {
                    ForEach(templatesViewModel.activeTemplates) { template in
                        Button {
                            addStrengthTemplateToEditDraft(template)
                        } label: {
                            strengthTemplatePickerRow(template)
                        }
                    }
                }
            }
            if !templatesViewModel.activeEnduranceTemplates.isEmpty {
                Section("Endurance") {
                    ForEach(templatesViewModel.activeEnduranceTemplates) { template in
                        Button {
                            addEnduranceTemplateToEditDraft(template)
                        } label: {
                            enduranceTemplatePickerRow(template)
                        }
                    }
                }
            }
        }
    }

    private func addStrengthTemplateToEditDraft(_ template: StrengthTemplate) {
        guard let dayIdx = selectedDayIndexForTemplate else { return }
        var planned = PlannedValues.empty
        planned.plannedStrengthRoutineSnapshot = TemplateSnapshot.plannedSnapshot(from: template)
        editDraftDays[dayIdx].workoutEntries.append(
            WeeklyTemplateWorkoutEntry(
                activityType: .strength,
                title: template.name,
                notes: template.note,
                plannedValues: planned,
                linkedWorkoutTemplateId: template.id,
                templateName: template.name
            )
        )
        showingWorkoutTemplatePicker = false
    }

    private func addEnduranceTemplateToEditDraft(_ template: EnduranceTemplate) {
        guard let dayIdx = selectedDayIndexForTemplate else { return }
        var planned = PlannedValues.empty
        planned.plannedDistance = template.plannedDistance
        planned.plannedDuration = template.plannedDuration
        planned.plannedElevationGain = template.plannedElevationGain
        planned.plannedDescription = template.description
        planned.plannedIntensityRPE = template.intensityRPE
        planned.plannedRoute = template.route
        editDraftDays[dayIdx].workoutEntries.append(
            WeeklyTemplateWorkoutEntry(
                activityType: template.activityType,
                runType: template.runType,
                title: template.name,
                notes: template.description,
                plannedValues: planned,
                linkedWorkoutTemplateId: template.id,
                templateName: template.name
            )
        )
        showingWorkoutTemplatePicker = false
    }

    @ViewBuilder
    private func strengthTemplatePickerRow(_ template: StrengthTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            Label("Strength", systemImage: TemplateCategory.strength.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = template.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func enduranceTemplatePickerRow(_ template: EnduranceTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            HStack {
                Label(template.activityType.rawValue, systemImage: template.activityType.sessionKind.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let runType = template.runType {
                    Text("• \(runType.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let description = template.description, !description.isEmpty {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func saveEdits() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Update the template in the weekViewModel
        weekViewModel.updateWeeklyTemplate(
            id: template.id,
            name: trimmedName,
            note: editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote,
            days: editDraftDays
        )
        
        showingEdit = false
    }
    
    @ViewBuilder
    private func weeklyTemplateEntryRow(_ entry: WeeklyTemplateWorkoutEntry) -> some View {
        HStack {
            Image(systemName: entry.activityType.sessionKind.systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline)
                if let runType = entry.runType {
                    Text(runType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if entry.activityType != .strength {
                    Text(entry.activityType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if entry.plannedValues.plannedStrengthRoutineSnapshot != nil {
                    Text("Tap for routine")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weekdayName(_ weekday: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = .current
        return fmt.weekdaySymbols[(weekday - 1 + 7) % 7]
    }
}

struct StrengthRoutineSnapshotDetailView: View {
    let title: String
    let snapshot: StrengthRoutineSnapshot

    var body: some View {
        List {
            if let notes = snapshot.completionNotes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
            ForEach(snapshot.exercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { exercise in
                Section(exercise.name) {
                    if let muscle = exercise.muscleGroup, !muscle.isEmpty {
                        Text(muscle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(exercise.targetSets) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                            Spacer()
                            if let reps = set.targetReps {
                                Text("\(reps) reps")
                                    .foregroundStyle(.secondary)
                            } else if let hint = set.repHint, !hint.isEmpty {
                                Text(hint)
                                    .foregroundStyle(.secondary)
                            }
                            if let weight = set.targetWeight {
                                Text(String(format: "%.1f", weight))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                    }
                    if let notes = exercise.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

