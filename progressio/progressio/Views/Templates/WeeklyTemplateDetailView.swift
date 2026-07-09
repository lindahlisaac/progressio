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
                    if day.sessions.isEmpty {
                        Text("Rest day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(day.sessions) { session in
                            HStack {
                                Image(systemName: session.kind.systemImage)
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.title)
                                        .font(.subheadline)
                                    if let runCat = session.runDetail?.category {
                                        Text(runCat.rawValue)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
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
            if editDraftDays[idx].sessions.isEmpty {
                Text("No workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(editDraftDays[idx].sessions) { session in
                    HStack {
                        Image(systemName: session.kind.systemImage)
                            .foregroundStyle(.secondary)
                        Text(session.title)
                        Spacer()
                        Text(session.kind.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    editDraftDays[idx].sessions.remove(atOffsets: offsets)
                }
            }
            
            Menu {
                Button("Blank run") {
                    editDraftDays[idx].sessions.append(
                        PlannedSession(title: "Run", kind: .run, status: .planned, note: "Planned run")
                    )
                }
                Button("Blank ride") {
                    editDraftDays[idx].sessions.append(
                        PlannedSession(title: "Ride", kind: .cycle, status: .planned, note: "Planned ride")
                    )
                }
                Button("Blank strength") {
                    editDraftDays[idx].sessions.append(
                        PlannedSession(title: "Strength", kind: .strength, status: .planned, note: "Strength session")
                    )
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
            ForEach(templatesViewModel.activeTemplates) { template in
                Button {
                    addTemplateToEditDraft(template)
                } label: {
                    templatePickerRow(template)
                }
            }
        }
    }
    
    private func addTemplateToEditDraft(_ template: StrengthTemplate) {
        guard let dayIdx = selectedDayIndexForTemplate else { return }
        
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
        
        let session = PlannedSession(
            title: template.name,
            kind: template.category == .strength ? .strength : .run,
            status: .planned,
            note: template.note,
            templateName: template.name,
            runDetail: runDetail
        )
        editDraftDays[dayIdx].sessions.append(session)
        showingWorkoutTemplatePicker = false
    }
    
    @ViewBuilder
    private func templatePickerRow(_ template: StrengthTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            HStack {
                Label(template.category.rawValue, systemImage: template.category.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if template.category == .run, let runCat = template.runCategory {
                    Text("• \(runCat.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let note = template.note, !note.isEmpty {
                Text(note)
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
    
    private func weekdayName(_ weekday: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = .current
        return fmt.weekdaySymbols[(weekday - 1 + 7) % 7]
    }
}

