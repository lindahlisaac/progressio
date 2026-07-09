import SwiftUI

struct TemplateLibraryView: View {
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var showingAddSheet = false
    @State private var showingWeeklyAddSheet = false
    @State private var newTemplateName: String = ""
    @State private var newTemplateNote: String = ""
    @State private var newTemplateCategory: TemplateCategory = .strength
    @State private var newExercises: [NewExerciseInput] = []
    @State private var newExerciseName: String = ""
    @State private var newExerciseSetsCount: String = ""
    @State private var newExerciseMinReps: Int = 6
    @State private var newExerciseMaxReps: Int = 10
    @State private var newRunCategory: RunCategory = .easy
    @State private var templatePendingDelete: StrengthTemplate?
    @State private var showingDeleteAlert = false
    @State private var selection: TemplateKind = .workout
    @State private var weeklyName: String = ""
    @State private var weeklyNote: String = ""
    @State private var weeklyDraftDays: [DayTemplate] = TemplateLibraryView.blankWeek()
    @State private var showingWorkoutTemplatePicker = false
    @State private var selectedDayIndexForTemplate: Int?
    @State private var showingApplyAlert = false
    @State private var templateToApply: WeeklyTemplate?

    var body: some View {
        List {
            Picker("Template view", selection: $selection) {
                ForEach(TemplateKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            if selection == .workout {
                Section("Strength") {
                    ForEach(viewModel.activeTemplates.filter { $0.category == .strength }) { template in
                        NavigationLink {
                            TemplateDetailView(template: template, viewModel: viewModel)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .font(.headline)
                                if let note = template.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(template.exercises.count) exercises")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                templatePendingDelete = template
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Section("Run") {
                    ForEach(viewModel.activeTemplates.filter { $0.category == .run }) { template in
                        NavigationLink {
                            TemplateDetailView(template: template, viewModel: viewModel)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                    .font(.headline)
                                if let note = template.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(template.exercises.count) items")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                templatePendingDelete = template
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } else {
                if weekViewModel.activeWeeklyTemplates.isEmpty {
                    Text("No weekly templates yet. Tap + to create one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    Section {
                        ForEach(weekViewModel.activeWeeklyTemplates) { template in
                            NavigationLink {
                                WeeklyTemplateDetailView(
                                    template: template,
                                    weekViewModel: weekViewModel,
                                    templatesViewModel: viewModel
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                    if let note = template.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(template.days.flatMap { $0.sessions }.count) workouts")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    templateToApply = template
                                    showingApplyAlert = true
                                } label: {
                                    Label("Apply", systemImage: "calendar.badge.plus")
                                }
                                .tint(.blue)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    weekViewModel.deleteWeeklyTemplate(id: template.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if selection == .workout {
                        showingAddSheet = true
                    } else {
                        weeklyDraftDays = TemplateLibraryView.blankWeek()
                        weeklyName = ""
                        weeklyNote = ""
                        showingWeeklyAddSheet = true
                    }
                } label: {
                    Label(selection == .workout ? "Add Template" : "Add Weekly", systemImage: "plus")
                }
            }
        }
        .alert("Delete template?", isPresented: $showingDeleteAlert, presenting: templatePendingDelete) { template in
            Button("Delete", role: .destructive) {
                viewModel.deleteTemplate(id: template.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { template in
            Text("This will remove \(template.name). This action cannot be undone.")
        }
        .alert("Apply Template to Current Week?", isPresented: $showingApplyAlert, presenting: templateToApply) { template in
            if weekViewModel.hasWorkoutsInCurrentWeek() {
                Button("Override existing") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: false)
                }
                Button("Keep existing") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: true)
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("Apply") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: false)
                }
                Button("Cancel", role: .cancel) { }
            }
        } message: { template in
            if weekViewModel.hasWorkoutsInCurrentWeek() {
                Text("You have existing workouts this week. Choose to override them or keep them alongside '\(template.name)'.")
            } else {
                Text("This will apply '\(template.name)' to the current week.")
            }
        }
        .sheet(isPresented: $showingAddSheet) { workoutTemplateSheet }
        .sheet(isPresented: $showingWeeklyAddSheet) { weeklyTemplateSheet }
    }

    private func saveTemplate() {
        let exercises: [StrengthExercise]
        if newTemplateCategory == .strength {
            exercises = Self.exercises(from: newExercises)
        } else {
            exercises = []
        }

        viewModel.addTemplate(
            name: newTemplateName,
            note: newTemplateNote,
            category: newTemplateCategory,
            exercises: exercises,
            runCategory: newTemplateCategory == .run ? newRunCategory : nil
        )
        dismissSheet()
    }

    private func dismissSheet() {
        showingAddSheet = false
        newTemplateName = ""
        newTemplateNote = ""
        newTemplateCategory = .strength
        newExercises = []
        newExerciseName = ""
        newExerciseSetsCount = ""
        newExerciseMinReps = 6
        newExerciseMaxReps = 10
        newRunCategory = .easy
    }

    static func exercises(from inputs: [NewExerciseInput]) -> [StrengthExercise] {
        inputs.map { input in
            let sets = (0..<input.setsCount).map { _ in
                StrengthSetTemplate(targetReps: 0, targetWeight: 0, targetRPE: nil, repRange: input.repRange)
            }
            return StrengthExercise(name: input.name, sets: sets)
        }
    }

    static func exerciseInputs(from exercises: [StrengthExercise]) -> [NewExerciseInput] {
        exercises.map { exercise in
            NewExerciseInput(
                name: exercise.name,
                setsCount: max(1, exercise.sets.count),
                repRange: exercise.sets.first?.repRange ?? "6-10"
            )
        }
    }

    private var workoutTemplateSheet: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Template Type", selection: $newTemplateCategory) {
                        ForEach(TemplateCategory.allCases) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                }
                Section("Template Info") {
                    TextField("Name", text: $newTemplateName)
                    TextField("Note (optional)", text: $newTemplateNote, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                if newTemplateCategory == .run {
                    Section("Run type") {
                        Picker("Run type", selection: $newRunCategory) {
                            ForEach(RunCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }
                }
                if newTemplateCategory == .strength {
                    StrengthTemplateExerciseEditor(
                        exercises: $newExercises,
                        exerciseName: $newExerciseName,
                        exerciseSetsCount: $newExerciseSetsCount,
                        exerciseMinReps: $newExerciseMinReps,
                        exerciseMaxReps: $newExerciseMaxReps
                    )
                }
            }
            .navigationTitle("New Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var weeklyTemplateSheet: some View {
        NavigationStack {
            weeklyTemplateForm
                .navigationTitle("New Weekly Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingWeeklyAddSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let name = weeklyName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            weekViewModel.saveWeeklyTemplate(name: name, note: weeklyNote, days: weeklyDraftDays)
                            showingWeeklyAddSheet = false
                        }
                        .disabled(weeklyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .sheet(isPresented: $showingWorkoutTemplatePicker) {
                    workoutTemplatePickerSheet
                }
        }
    }
    
    private var weeklyTemplateForm: some View {
        let orderedDays = weeklyDraftDays.sorted { lhs, rhs in
            let order: (Int) -> Int = { $0 == 1 ? 8 : $0 }
            return order(lhs.weekday) < order(rhs.weekday)
        }
        
        return Form {
            Section("Info") {
                TextField("Name", text: $weeklyName)
                TextField("Note (optional)", text: $weeklyNote, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
            }
            ForEach(Array(orderedDays.enumerated()), id: \.element.id) { entry in
                let idx = weeklyDraftDays.firstIndex(where: { $0.id == entry.element.id }) ?? entry.offset
                weeklyDaySection(idx: idx, weekday: entry.element.weekday)
            }
        }
    }
    
    @ViewBuilder
    private func weeklyDaySection(idx: Int, weekday: Int) -> some View {
        Section(weekdayName(weekday)) {
            ForEach(weeklyDraftDays[idx].sessions) { session in
                HStack {
                    Text(session.title)
                    Spacer()
                    Text(session.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                weeklyDraftDays[idx].sessions.remove(atOffsets: offsets)
            }
            Menu("Add workout") {
                Button("Blank run") {
                    weeklyDraftDays[idx].sessions.append(
                        PlannedSession(title: "Run", kind: .run, status: .planned, note: "Planned run")
                    )
                }
                Button("Blank ride") {
                    weeklyDraftDays[idx].sessions.append(
                        PlannedSession(title: "Ride", kind: .cycle, status: .planned, note: "Planned ride")
                    )
                }
                Button("Blank strength") {
                    weeklyDraftDays[idx].sessions.append(
                        PlannedSession(title: "Strength", kind: .strength, status: .planned, note: "Strength session")
                    )
                }
                Divider()
                Button("From template...") {
                    selectedDayIndexForTemplate = idx
                    showingWorkoutTemplatePicker = true
                }
            }
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
            ForEach(viewModel.activeTemplates) { template in
                Button {
                    addTemplateToWeeklyDraft(template)
                } label: {
                    templatePickerRow(template)
                }
            }
        }
    }
    
    private func addTemplateToWeeklyDraft(_ template: StrengthTemplate) {
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
        weeklyDraftDays[dayIdx].sessions.append(session)
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

    private func weekdayName(_ weekday: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = .current
        return fmt.weekdaySymbols[(weekday - 1 + 7) % 7]
    }

    private static func blankWeek() -> [DayTemplate] {
        (1...7).map { DayTemplate(weekday: $0, sessions: []) }
    }

    private var isSaveDisabled: Bool {
        let trimmedName = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return true }
        if newTemplateCategory == .strength {
            return newExercises.isEmpty
        }
        return false
    }
}

enum TemplateKind: String, CaseIterable, Identifiable {
    case workout
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workout: return "Workouts"
        case .weekly: return "Weekly"
        }
    }
}

struct TemplateDetailView: View {
    let template: StrengthTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel

    @State private var showingEdit = false
    @State private var editName: String = ""
    @State private var editNote: String = ""
    @State private var editRunCategory: RunCategory = .easy
    @State private var editExercises: [NewExerciseInput] = []
    @State private var editExerciseName: String = ""
    @State private var editExerciseSetsCount: String = ""
    @State private var editExerciseMinReps: Int = 6
    @State private var editExerciseMaxReps: Int = 10

    var body: some View {
        List {
            templateInfoSection
            templateNotesSection
            templateExercisesList
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: beginEditing)
            }
        }
        .sheet(isPresented: $showingEdit) {
            TemplateEditSheet(
                template: template,
                viewModel: viewModel,
                editName: $editName,
                editNote: $editNote,
                editRunCategory: $editRunCategory,
                editExercises: $editExercises,
                editExerciseName: $editExerciseName,
                editExerciseSetsCount: $editExerciseSetsCount,
                editExerciseMinReps: $editExerciseMinReps,
                editExerciseMaxReps: $editExerciseMaxReps,
                isPresented: $showingEdit
            )
        }
    }

    @ViewBuilder
    private var templateInfoSection: some View {
        Section {
            Label(template.category.rawValue, systemImage: template.category.systemImage)
            if template.category == .run, let runCat = template.runCategory {
                Label("Run type: \(runCat.rawValue)", systemImage: "tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var templateNotesSection: some View {
        if let note = template.note, !note.isEmpty {
            Section("Notes") {
                Text(note)
            }
        }
    }

    @ViewBuilder
    private var templateExercisesList: some View {
        ForEach(template.exercises) { exercise in
            Section(exercise.name) {
                ForEach(exercise.sets) { set in
                    TemplateSetRow(set: set)
                }
            }
        }
    }

    private func beginEditing() {
        editName = template.name
        editNote = template.note ?? ""
        editRunCategory = template.runCategory ?? .easy
        editExercises = TemplateLibraryView.exerciseInputs(from: template.exercises)
        editExerciseName = ""
        editExerciseSetsCount = ""
        editExerciseMinReps = 6
        editExerciseMaxReps = 10
        showingEdit = true
    }
}

private struct TemplateSetRow: View {
    let set: StrengthSetTemplate

    var body: some View {
        HStack {
            if let repRange = set.repRange {
                Text("\(repRange) reps")
            } else {
                Text("\(set.targetReps) reps")
            }
            Spacer()
            if set.targetWeight > 0 {
                Text("\(Int(set.targetWeight)) lb")
                    .foregroundStyle(.secondary)
            }
            if let rpe = set.targetRPE {
                Text("RPE \(String(format: "%.1f", rpe))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TemplateEditSheet: View {
    let template: StrengthTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @Binding var editName: String
    @Binding var editNote: String
    @Binding var editRunCategory: RunCategory
    @Binding var editExercises: [NewExerciseInput]
    @Binding var editExerciseName: String
    @Binding var editExerciseSetsCount: String
    @Binding var editExerciseMinReps: Int
    @Binding var editExerciseMaxReps: Int
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Info") {
                    TextField("Name", text: $editName)
                    TextField("Note (optional)", text: $editNote, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                if template.category == .run {
                    Section("Run type") {
                        Picker("Run type", selection: $editRunCategory) {
                            ForEach(RunCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }
                }
                if template.category == .strength {
                    StrengthTemplateExerciseEditor(
                        exercises: $editExercises,
                        exerciseName: $editExerciseName,
                        exerciseSetsCount: $editExerciseSetsCount,
                        exerciseMinReps: $editExerciseMinReps,
                        exerciseMaxReps: $editExerciseMaxReps
                    )
                }
            }
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return true }
        if template.category == .strength {
            return editExercises.isEmpty
        }
        return false
    }

    private func save() {
        var updated = template
        updated.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote
        if updated.category == .run {
            updated.runCategory = editRunCategory
        }
        if updated.category == .strength {
            updated.exercises = TemplateLibraryView.exercises(from: editExercises)
        }
        viewModel.updateTemplate(updated)
        isPresented = false
    }
}

private struct StrengthTemplateExerciseEditor: View {
    @Binding var exercises: [NewExerciseInput]
    @Binding var exerciseName: String
    @Binding var exerciseSetsCount: String
    @Binding var exerciseMinReps: Int
    @Binding var exerciseMaxReps: Int

    var body: some View {
        Section("Lifts & sets") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Lift name", text: $exerciseName)
                TextField("Number of sets", text: $exerciseSetsCount)
                    .keyboardType(.numberPad)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rep range")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("Min reps", selection: $exerciseMinReps) {
                            ForEach(1...30, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        Text("to")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Max reps", selection: $exerciseMaxReps) {
                            ForEach(1...30, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                    .frame(height: 120)
                    if exerciseMinReps >= exerciseMaxReps {
                        Text("Min must be less than max")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                Button {
                    addExercise()
                } label: {
                    Label("Add lift", systemImage: "plus.circle.fill")
                }
                .disabled(
                    exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || Int(exerciseSetsCount) == nil
                        || exerciseMinReps >= exerciseMaxReps
                )
            }
            if !exercises.isEmpty {
                ForEach(exercises) { exercise in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                            Text("\(exercise.setsCount) sets • \(exercise.repRange)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    exercises.remove(atOffsets: offsets)
                }
                .onMove(perform: moveExercises)
                Text("Swipe to delete; drag to reorder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func addExercise() {
        guard let setsCount = Int(exerciseSetsCount), setsCount > 0 else { return }
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, exerciseMinReps < exerciseMaxReps else { return }
        let rangeText = "\(exerciseMinReps)-\(exerciseMaxReps)"
        exercises.append(
            NewExerciseInput(name: trimmedName, setsCount: setsCount, repRange: rangeText, createdAt: Date())
        )
        exerciseName = ""
        exerciseSetsCount = ""
        exerciseMinReps = 6
        exerciseMaxReps = 10
    }

    private func moveExercises(from offsets: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: offsets, toOffset: destination)
    }
}

