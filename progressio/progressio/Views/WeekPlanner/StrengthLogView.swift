import SwiftUI

struct StrengthLogView: View {
    let session: PlannedSession
    var onNoteChange: ((String) -> Void)?
    @State private var exercises: [ExerciseLog]
    private let initialExercises: [ExerciseLog]
    @State private var showingAddExerciseSheet = false
    @State private var newExerciseName: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isLocked: Bool
    @State private var isCompleted: Bool
    @State private var note: String
    private let storageURL: URL
    @Environment(\.scenePhase) private var scenePhase
    private let onCompleteStatus: (() -> Void)?
    private let onUnlockStatus: (() -> Void)?
    @State private var showingResetConfirm = false

    private struct ExerciseSection: View {
        @Binding var exercise: ExerciseLog
        var removeSets: (IndexSet, UUID) -> Void
        var addSet: (UUID) -> Void
        var isInputFocused: FocusState<Bool>.Binding
        var onChanged: () -> Void
        var isLocked: Bool

        var body: some View {
            Section(header: Text(exercise.name)) {
                ForEach(exercise.sets.indices, id: \.self) { idx in
                    SetRow(set: $exercise.sets[idx], isInputFocused: isInputFocused, onChanged: onChanged, isLocked: isLocked)
                }
                .onDelete { indexSet in
                    guard !isLocked else { return }
                    removeSets(indexSet, exercise.id)
                    onChanged()
                }
                .deleteDisabled(isLocked)

                Button {
                    addSet(exercise.id)
                    onChanged()
                } label: {
                    Label("Add set", systemImage: "plus.circle")
                }
                .disabled(isLocked)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercise RPE (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("RPE", text: $exercise.rpe)
                        .keyboardType(.decimalPad)
                        .focused(isInputFocused)
                        .onChange(of: exercise.rpe) { _ in onChanged() }
                        .disabled(isLocked)
                }
            }
        }
    }

    init(session: PlannedSession, template: StrengthTemplate?, onNoteChange: ((String) -> Void)? = nil, onCompleteStatus: (() -> Void)? = nil, onUnlockStatus: (() -> Void)? = nil) {
        self.session = session
        self.onNoteChange = onNoteChange
        self.onCompleteStatus = onCompleteStatus
        self.onUnlockStatus = onUnlockStatus
        self.storageURL = StrengthLogPersistence.strengthLogURL(for: session.id)

        if let template {
            let seeded: [ExerciseLog] = template.exercises.map { exercise -> ExerciseLog in
                let exerciseRPE = exercise.sets.first?.targetRPE.map { String(format: "%.1f", $0) } ?? ""
                return ExerciseLog(
                    name: exercise.name,
                    sets: exercise.sets.map { set -> SetLog in
                        return SetLog(
                            weight: set.targetWeight > 0 ? String(Int(set.targetWeight)) : "",
                            reps: "",
                            repHint: set.repRange ?? (set.targetReps > 0 ? String(set.targetReps) : "")
                        )
                    },
                    rpe: exerciseRPE
                )
            }
            self.initialExercises = seeded
        } else {
            self.initialExercises = []
        }

        if let loaded = StrengthLogPersistence.load(from: storageURL) {
            _exercises = State(initialValue: loaded.exercises)
            let completed = session.status == .completed ? loaded.isCompleted : false
            _isCompleted = State(initialValue: completed)
            _isLocked = State(initialValue: completed)
            _note = State(initialValue: session.note ?? "")
        } else {
            _exercises = State(initialValue: initialExercises)
            let completed = session.status == .completed
            _isCompleted = State(initialValue: completed)
            _isLocked = State(initialValue: completed)
            _note = State(initialValue: session.note ?? "")
        }
    }

    var body: some View {
        List {
            Section("Description") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
                    .onChange(of: note) { newValue in
                        onNoteChange?(newValue)
                    }
            }
            ForEach($exercises) { $exercise in
                ExerciseSection(
                    exercise: $exercise,
                    removeSets: removeSets,
                    addSet: addSet,
                    isInputFocused: $isInputFocused,
                    onChanged: persistState,
                    isLocked: isLocked
                )
            }
            .onDelete(perform: deleteExercise)
        }
        .navigationTitle(session.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExerciseSheet = true
                } label: {
                    Label("Add lift", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(exercises == initialExercises)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputFocused = false
                }
            }
        }
        .onChange(of: exercises) { _ in
            persistState()
        }
        .onChange(of: note) { newValue in
            onNoteChange?(newValue)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                persistState()
            }
        }
        .onAppear {
            reloadStateIfAvailable()
        }
        .onDisappear {
            persistState()
        }
        .sheet(isPresented: $showingAddExerciseSheet) {
            NavigationStack {
                Form {
                    TextField("Lift name", text: $newExerciseName)
                        .focused($isInputFocused)
                }
                .navigationTitle("New Lift")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismissAddExercise() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addExercise()
                        }
                        .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("Clear log?", isPresented: $showingResetConfirm) {
            Button("Clear", role: .destructive) {
                resetLog()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove entered weights and reps for this session.")
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if isLocked {
                    isLocked = false
                    isCompleted = false
                    onUnlockStatus?()
                    persistState()
                } else {
                    markComplete()
                }
            } label: {
                Text(isLocked ? "Edit workout" : "Complete workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isLocked ? Color.blue.opacity(0.15) : Color.green.opacity(0.2))
                    .foregroundStyle(isLocked ? Color.blue : Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
        persistState()
    }

    private func removeSets(_ offsets: IndexSet, in exerciseID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[exerciseIndex].sets.remove(atOffsets: offsets)
        persistState()
    }

    private func addSet(to exerciseID: UUID) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[idx].sets.append(SetLog(weight: "", reps: "", repHint: ""))
        persistState()
    }

    private func addExercise() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let exercise = ExerciseLog(name: trimmed, sets: [SetLog(weight: "", reps: "", repHint: "")], rpe: "")
        exercises.append(exercise)
        dismissAddExercise()
        persistState()
    }

    private func dismissAddExercise() {
        newExerciseName = ""
        showingAddExerciseSheet = false
    }

    private func markComplete() {
        isCompleted = true
        isLocked = true
        isInputFocused = false
        onCompleteStatus?()
        persistState()
    }

    private func resetLog() {
        exercises = initialExercises
        isCompleted = false
        isLocked = false
        do {
            if FileManager.default.fileExists(atPath: storageURL.path) {
                try FileManager.default.removeItem(at: storageURL)
            }
        } catch {
            print("Failed to remove log file at \(storageURL): \(error)")
        }
        persistState()
    }

    private func persistState() {
        let state = StrengthLogState(sessionID: session.id, exercises: exercises, isCompleted: isCompleted)
        do {
            try StrengthLogPersistence.save(state, to: storageURL)
            print("Saved strength log to \(storageURL.lastPathComponent)")
        } catch {
            print("Failed to persist strength log at \(storageURL): \(error)")
        }
    }

    private func reloadStateIfAvailable() {
        if let latest = StrengthLogPersistence.load(from: storageURL) {
            exercises = latest.exercises
            let completed = session.status == .completed ? latest.isCompleted : false
            isCompleted = completed
            isLocked = completed
        }
    }
}

private struct SetRow: View {
    @Binding var set: SetLog
    var isInputFocused: FocusState<Bool>.Binding
    var onChanged: () -> Void
    var isLocked: Bool

    @State private var repSelection: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("e.g. 135", text: $set.weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .focused(isInputFocused)
                            .onChange(of: set.weight) { _ in onChanged() }
                        Text("lb")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isLocked)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("", selection: $repSelection) {
                            ForEach(0...99, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.white)
                        .onChange(of: repSelection) { newValue in
                            set.reps = "\(newValue)"
                            onChanged()
                        }
                        .disabled(isLocked)

                        Spacer()

                        if !set.repHint.isEmpty {
                            Text(set.repHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            if let current = Int(set.reps) {
                repSelection = max(0, min(99, current))
            } else {
                repSelection = 0
            }
        }
        .padding(.vertical, 4)
    }
}

