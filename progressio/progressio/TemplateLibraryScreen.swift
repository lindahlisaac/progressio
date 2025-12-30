import SwiftUI

struct TemplateLibraryView: View {
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @State private var showingAddSheet = false
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

    var body: some View {
        List {
            Section("Strength") {
                ForEach(viewModel.templates.filter { $0.category == .strength }) { template in
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
                ForEach(viewModel.templates.filter { $0.category == .run }) { template in
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
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Template", systemImage: "plus")
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
        .sheet(isPresented: $showingAddSheet) {
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
                        Section("Lifts & sets") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Lift name", text: $newExerciseName)
                                TextField("Number of sets", text: $newExerciseSetsCount)
                                    .keyboardType(.numberPad)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Rep range")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Picker("Min reps", selection: $newExerciseMinReps) {
                                            ForEach(1...30, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        Text("to")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Picker("Max reps", selection: $newExerciseMaxReps) {
                                            ForEach(1...30, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                    }
                                    .frame(height: 120)
                                    if newExerciseMinReps >= newExerciseMaxReps {
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
                                .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(newExerciseSetsCount) == nil || newExerciseMinReps >= newExerciseMaxReps)
                            }
                            if !newExercises.isEmpty {
                                ForEach(newExercises) { exercise in
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
                                .onMove(perform: moveExercises)
                                Text("Drag the hamburger icon to reorder")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .environment(\.editMode, .constant(.active))
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
    }

    private func saveTemplate() {
        let exercises: [StrengthExercise]
        if newTemplateCategory == .strength {
            exercises = newExercises.map { input in
                let sets = (0..<input.setsCount).map { _ in
                    StrengthSetTemplate(targetReps: 0, targetWeight: 0, targetRPE: nil, repRange: input.repRange)
                }
                return StrengthExercise(name: input.name, sets: sets)
            }
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

    private func addExercise() {
        guard let setsCount = Int(newExerciseSetsCount), setsCount > 0 else { return }
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, newExerciseMinReps < newExerciseMaxReps else { return }
        let rangeText = "\(newExerciseMinReps)-\(newExerciseMaxReps)"
        let input = NewExerciseInput(name: trimmedName, setsCount: setsCount, repRange: rangeText, createdAt: Date())
        newExercises.append(input)
        newExerciseName = ""
        newExerciseSetsCount = ""
        newExerciseMinReps = 6
        newExerciseMaxReps = 10
    }

    private func moveExercises(from offsets: IndexSet, to destination: Int) {
        newExercises.move(fromOffsets: offsets, toOffset: destination)
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

struct TemplateDetailView: View {
    let template: StrengthTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel

    @State private var showingEdit = false
    @State private var editName: String = ""
    @State private var editNote: String = ""
    @State private var editRunCategory: RunCategory = .easy

    var body: some View {
        List {
            Section {
                Label(template.category.rawValue, systemImage: template.category.systemImage)
                if template.category == .run, let runCat = template.runCategory {
                    Label("Run type: \(runCat.rawValue)", systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let note = template.note, !note.isEmpty {
                Section("Notes") {
                    Text(note)
                }
            }
            ForEach(template.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sets) { set in
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
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editName = template.name
                    editNote = template.note ?? ""
                    editRunCategory = template.runCategory ?? .easy
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
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
                }
                .navigationTitle("Edit Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEdit = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            var updated = template
                            updated.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
                            updated.note = editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote
                            if updated.category == .run {
                                updated.runCategory = editRunCategory
                            }
                            viewModel.updateTemplate(updated)
                            showingEdit = false
                        }
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

