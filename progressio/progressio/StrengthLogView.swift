import SwiftUI

struct StrengthLogView: View {
    struct SetLog: Identifiable, Codable, Equatable {
        let id = UUID()
        var weight: String
        var reps: String
        var repHint: String
    }

    struct ExerciseLog: Identifiable, Codable, Equatable {
        let id = UUID()
        var name: String
        var sets: [SetLog]
        var rpe: String
    }

    private struct StrengthLogState: Codable {
        var sessionID: UUID
        var exercises: [ExerciseLog]
    }

    let session: PlannedSession
    @State private var exercises: [ExerciseLog]
    private let initialExercises: [ExerciseLog]
    @State private var showingAddExerciseSheet = false
    @State private var newExerciseName: String = ""
    @FocusState private var isInputFocused: Bool
    private let storageURL: URL
    @Environment(\.scenePhase) private var scenePhase

    private struct ExerciseSection: View {
        @Binding var exercise: StrengthLogView.ExerciseLog
        var removeSets: (IndexSet, UUID) -> Void
        var addSet: (UUID) -> Void
        var isInputFocused: FocusState<Bool>.Binding
        var onChanged: () -> Void

        var body: some View {
            Section(header: Text(exercise.name)) {
                ForEach($exercise.sets) { $set in
                    SetRow(set: $set, isInputFocused: isInputFocused, onChanged: onChanged)
                }
                .onDelete { indexSet in
                    removeSets(indexSet, exercise.id)
                    onChanged()
                }

                Button {
                    addSet(exercise.id)
                    onChanged()
                } label: {
                    Label("Add set", systemImage: "plus.circle")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Exercise RPE (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("RPE", text: $exercise.rpe)
                        .keyboardType(.decimalPad)
                        .focused(isInputFocused)
                        .onChange(of: exercise.rpe) { _ in onChanged() }
                }
            }
        }
    }

    init(session: PlannedSession, template: StrengthTemplate?) {
        self.session = session
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.storageURL = docs.appendingPathComponent("strengthlog-\(session.id.uuidString).json")

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

        if let loaded = StrengthLogView.loadState(from: storageURL) {
            _exercises = State(initialValue: loaded.exercises)
        } else {
            _exercises = State(initialValue: initialExercises)
        }
    }

    var body: some View {
        List {
            ForEach($exercises) { $exercise in
                ExerciseSection(
                    exercise: $exercise,
                    removeSets: removeSets,
                    addSet: addSet,
                    isInputFocused: $isInputFocused,
                    onChanged: persistState
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
                    resetLog()
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

    private func resetLog() {
        exercises = initialExercises
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
        let state = StrengthLogState(sessionID: session.id, exercises: exercises)
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(state)
            try data.write(to: storageURL, options: .atomic)
            print("Saved strength log to \(storageURL.lastPathComponent)")
        } catch {
            print("Failed to persist strength log at \(storageURL): \(error)")
        }
    }

    private func reloadStateIfAvailable() {
        if let latest = StrengthLogView.loadState(from: storageURL) {
            exercises = latest.exercises
        }
    }

    private static func loadState(from url: URL) -> StrengthLogState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(StrengthLogState.self, from: data)
            print("Loaded strength log from \(url.lastPathComponent)")
            return decoded
        } catch {
            print("Failed to load strength log at \(url): \(error)")
            return nil
        }
    }
}

private struct SetRow: View {
    @Binding var set: StrengthLogView.SetLog
    var isInputFocused: FocusState<Bool>.Binding
    var onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(set.repHint.isEmpty ? "e.g. 8" : set.repHint, text: $set.reps, prompt: set.repHint.isEmpty ? nil : Text(set.repHint))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused(isInputFocused)
                    .onChange(of: set.reps) { _ in onChanged() }
            }
        }
        .padding(.vertical, 4)
    }
}

