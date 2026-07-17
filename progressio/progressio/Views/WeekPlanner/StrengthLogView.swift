import SwiftUI
import UIKit

struct StrengthLogView: View {
    let workout: Workout
    var onNoteChange: ((String) -> Void)?
    var onTitleChange: ((String) -> Void)?
    @State private var exercises: [ExerciseLog]
    private let initialExercises: [ExerciseLog]
    @State private var showingAddExerciseSheet = false
    @State private var newExerciseName: String = ""
    @FocusState private var isInputFocused: Bool
    @State private var isLocked: Bool
    @State private var isCompleted: Bool
    @State private var title: String
    @State private var note: String
    @State private var timePeriod: TimePeriod
    @Environment(\.scenePhase) private var scenePhase
    private let onCompleteStatus: (() -> Void)?
    private let onUnlockStatus: (() -> Void)?
    private let onCompletedSnapshotPersist: ((StrengthRoutineSnapshot) -> Void)?
    private let onTimePeriodChange: ((TimePeriod) -> Void)?
    @State private var showingResetConfirm = false
    @State private var persistWorkItem: DispatchWorkItem?
    @State private var noteWorkItem: DispatchWorkItem?
    @State private var titleWorkItem: DispatchWorkItem?

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

    init(
        workout: Workout,
        onNoteChange: ((String) -> Void)? = nil,
        onTitleChange: ((String) -> Void)? = nil,
        onCompleteStatus: (() -> Void)? = nil,
        onUnlockStatus: (() -> Void)? = nil,
        onCompletedSnapshotPersist: ((StrengthRoutineSnapshot) -> Void)? = nil,
        onTimePeriodChange: ((TimePeriod) -> Void)? = nil
    ) {
        self.workout = workout
        self.onNoteChange = onNoteChange
        self.onTitleChange = onTitleChange
        self.onCompleteStatus = onCompleteStatus
        self.onUnlockStatus = onUnlockStatus
        self.onCompletedSnapshotPersist = onCompletedSnapshotPersist
        self.onTimePeriodChange = onTimePeriodChange

        let seededFromSnapshot = Self.seedExercises(from: workout)
        self.initialExercises = seededFromSnapshot

        // Prefer workout-embedded snapshot (synced). One-time fallback to legacy local file if present.
        if seededFromSnapshot.isEmpty,
           let loaded = StrengthLogPersistence.load(from: StrengthLogPersistence.strengthLogURL(for: workout.id)) {
            _exercises = State(initialValue: loaded.exercises)
            let completed = workout.status == .completed || workout.status == .partiallyCompleted ? loaded.isCompleted : false
            _isCompleted = State(initialValue: completed)
            _isLocked = State(initialValue: completed)
            _note = State(initialValue: workout.notes ?? "")
        } else {
            _exercises = State(initialValue: seededFromSnapshot)
            let completed = workout.status == .completed || workout.status == .partiallyCompleted
            _isCompleted = State(initialValue: completed)
            _isLocked = State(initialValue: completed)
            _note = State(initialValue: workout.notes ?? "")
        }
        _title = State(initialValue: workout.title.isEmpty ? ActivityType.strength.defaultTitle : workout.title)
        _timePeriod = State(initialValue: workout.timePeriod)
    }

    private static func seedExercises(from workout: Workout) -> [ExerciseLog] {
        if let completed = workout.completedValues.completedStrengthRoutineSnapshot {
            return TemplateSnapshot.exerciseLogs(from: completed, preferActuals: true)
        }
        if let planned = workout.plannedValues.plannedStrengthRoutineSnapshot {
            return TemplateSnapshot.exerciseLogs(from: planned)
        }
        return []
    }

    var body: some View {
        List {
            Section("Session") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Strength", text: $title)
                        .focused($isInputFocused)
                        .disabled(isLocked)
                        .onChange(of: title) { newValue in
                            scheduleTitlePersist(newValue)
                        }
                }
                Picker("Time of day", selection: $timePeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: timePeriod) { newValue in
                    onTimePeriodChange?(newValue)
                }
            }
            Section("Notes") {
                TextEditor(text: $note)
                    .frame(minHeight: 100)
                    .focused($isInputFocused)
                    .disabled(isLocked)
                    .onChange(of: note) { newValue in
                        scheduleNotePersist(newValue)
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
        .navigationTitle(title.isEmpty ? "Strength" : title)
        .navigationBarTitleDisplayMode(.inline)
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
                    dismissKeyboard()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: exercises) { newValue in
            schedulePersist(exercises: newValue)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background || phase == .inactive {
                persistState()
                flushNoteAndTitle()
            }
        }
        .onAppear {
            reloadStateIfAvailable()
        }
        .onDisappear {
            persistState()
            flushNoteAndTitle()
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
        dismissKeyboard()
        onCompleteStatus?()
        persistState()
    }

    private func dismissKeyboard() {
        isInputFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func resetLog() {
        exercises = initialExercises
        isCompleted = false
        isLocked = false
        persistState()
    }

    private func schedulePersist(exercises pending: [ExerciseLog]) {
        persistWorkItem?.cancel()
        let persist = onCompletedSnapshotPersist
        let work = DispatchWorkItem {
            persist?(TemplateSnapshot.completedSnapshot(from: pending))
        }
        persistWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func scheduleNotePersist(_ value: String) {
        noteWorkItem?.cancel()
        let handler = onNoteChange
        let work = DispatchWorkItem { handler?(value) }
        noteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func scheduleTitlePersist(_ value: String) {
        titleWorkItem?.cancel()
        let handler = onTitleChange
        let work = DispatchWorkItem { handler?(value) }
        titleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func flushNoteAndTitle() {
        noteWorkItem?.cancel()
        noteWorkItem = nil
        titleWorkItem?.cancel()
        titleWorkItem = nil
        onNoteChange?(note)
        onTitleChange?(title)
    }

    private func persistState() {
        persistWorkItem?.cancel()
        persistWorkItem = nil
        // Strength completion lives on the workout model (CloudKit week sync).
        onCompletedSnapshotPersist?(TemplateSnapshot.completedSnapshot(from: exercises))
    }

    private func reloadStateIfAvailable() {
        // No separate file reload; week plan snapshot is source of truth after Task 021.
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

