import SwiftUI
import UIKit

struct StrengthLogView: View {
    let workout: Workout
    var onNoteChange: ((String) -> Void)?
    var onTitleChange: ((String) -> Void)?
    /// Loads prior lift/session comparison from local week files (newest-first).
    var loadPriorComparison: (([String]) -> StrengthComparisonResult)?
    @State private var exercises: [ExerciseLog]
    private let initialExercises: [ExerciseLog]
    @State private var showingAddExerciseSheet = false
    @State private var showingReorderSheet = false
    @State private var showingPriorSessionSheet = false
    @State private var renamingExerciseID: UUID?
    @State private var comparison: StrengthComparisonResult = .empty
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

    init(
        workout: Workout,
        onNoteChange: ((String) -> Void)? = nil,
        onTitleChange: ((String) -> Void)? = nil,
        loadPriorComparison: (([String]) -> StrengthComparisonResult)? = nil,
        onCompleteStatus: (() -> Void)? = nil,
        onUnlockStatus: (() -> Void)? = nil,
        onCompletedSnapshotPersist: ((StrengthRoutineSnapshot) -> Void)? = nil,
        onTimePeriodChange: ((TimePeriod) -> Void)? = nil
    ) {
        self.workout = workout
        self.onNoteChange = onNoteChange
        self.onTitleChange = onTitleChange
        self.loadPriorComparison = loadPriorComparison
        self.onCompleteStatus = onCompleteStatus
        self.onUnlockStatus = onUnlockStatus
        self.onCompletedSnapshotPersist = onCompletedSnapshotPersist
        self.onTimePeriodChange = onTimePeriodChange

        let seededFromSnapshot = Self.seedExercises(from: workout)
        self.initialExercises = seededFromSnapshot

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
                if let prior = comparison.similarSession {
                    Button {
                        showingPriorSessionSheet = true
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last similar session")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(prior.title) · \(Self.shortDate.string(from: prior.date))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(prior.matchLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
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
                Section {
                    // Lift title: tap name to swap via catalog; ≡ reorders whole lifts.
                    HStack(alignment: .top, spacing: 12) {
                        Button {
                            guard !isLocked else { return }
                            renamingExerciseID = exercise.id
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        if !isLocked {
                                            Image(systemName: "pencil.circle")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if let prior = priorPerformance(for: exercise.name) {
                                        Text("Last: \(prior.condensedLine)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(Self.shortDate.string(from: prior.date))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    } else if !isLocked {
                                        Text("Tap to change lift")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isLocked)
                        .accessibilityLabel("Change \(exercise.name)")
                        .accessibilityHint("Opens lift catalog to swap this exercise")

                        if !isLocked, exercises.count > 1 {
                            Button {
                                showingReorderSheet = true
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 44, height: 36, alignment: .trailing)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reorder lifts")
                        }
                    }
                    .listRowBackground(Color(.secondarySystemBackground))

                    ForEach($exercise.sets) { $set in
                        SetRow(
                            set: $set,
                            isInputFocused: $isInputFocused,
                            onChanged: persistState,
                            isLocked: isLocked
                        )
                    }
                    .onDelete { indexSet in
                        guard !isLocked else { return }
                        removeSets(indexSet, in: exercise.id)
                    }
                    .deleteDisabled(isLocked)

                    Button {
                        addSet(to: exercise.id)
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
                            .focused($isInputFocused)
                            .onChange(of: exercise.rpe) { _ in persistState() }
                            .disabled(isLocked)
                    }
                }
            }
            .onDelete(perform: deleteExercise)
            .deleteDisabled(isLocked)

            if !isLocked, exercises.count > 1 {
                Section {
                    Text("Tap ≡ on a lift to reorder the routine. Sets stay with their lift.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
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
                        .padding(.vertical, 8)
                }
                .tint(isLocked ? .blue : .green)
            }
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
                .disabled(isLocked)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .destructive) {
                    showingResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(isLocked || exercises == initialExercises)
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
            refreshPriorComparison()
        }
        .onChange(of: exercises.map(\.name)) { _ in
            refreshPriorComparison()
        }
        .onDisappear {
            persistState()
            flushNoteAndTitle()
        }
        .sheet(isPresented: $showingAddExerciseSheet) {
            LiftPickerView(
                title: "Add Lift",
                onSelect: { lift in
                    appendLift(named: lift.name)
                },
                onSelectCustom: { name in
                    appendLift(named: name)
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { renamingExerciseID != nil },
            set: { if !$0 { renamingExerciseID = nil } }
        )) {
            LiftPickerView(
                title: "Change Lift",
                onSelect: { lift in
                    if let id = renamingExerciseID {
                        renameLift(id: id, to: lift.name)
                    }
                    renamingExerciseID = nil
                },
                onSelectCustom: { name in
                    if let id = renamingExerciseID {
                        renameLift(id: id, to: name)
                    }
                    renamingExerciseID = nil
                }
            )
        }
        .sheet(isPresented: $showingReorderSheet) {
            ReorderLiftsSheet(exercises: $exercises) {
                persistState()
            }
        }
        .sheet(isPresented: $showingPriorSessionSheet) {
            if let prior = comparison.similarSession {
                PriorStrengthSessionSheet(session: prior)
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
    }

    private func priorPerformance(for liftName: String) -> PriorLiftPerformance? {
        comparison.priorByLift[StrengthHistoryLookup.normalizeLiftName(liftName)]
    }

    private func refreshPriorComparison() {
        guard let loadPriorComparison else {
            comparison = .empty
            return
        }
        comparison = loadPriorComparison(exercises.map(\.name))
    }

    private static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func deleteExercise(at offsets: IndexSet) {
        guard !isLocked else { return }
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
        appendLift(named: newExerciseName)
    }

    private func appendLift(named rawName: String) {
        let trimmed = LiftCatalog.canonicalName(for: rawName)
        guard !trimmed.isEmpty else { return }
        let exercise = ExerciseLog(name: trimmed, sets: [SetLog(weight: "", reps: "", repHint: "")], rpe: "")
        exercises.append(exercise)
        dismissAddExercise()
        persistState()
    }

    private func renameLift(id: UUID, to rawName: String) {
        let trimmed = LiftCatalog.canonicalName(for: rawName)
        guard !trimmed.isEmpty,
              let index = exercises.firstIndex(where: { $0.id == id })
        else { return }
        exercises[index].name = trimmed
        persistState()
        refreshPriorComparison()
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
        onCompletedSnapshotPersist?(TemplateSnapshot.completedSnapshot(from: exercises))
    }

    private func reloadStateIfAvailable() {}
}

/// Flat list of whole lifts — List `onMove` is safe here because each row is one exercise.
private struct ReorderLiftsSheet: View {
    @Binding var exercises: [ExerciseLog]
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(exercises) { exercise in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.body.weight(.semibold))
                                Text("\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "line.3.horizontal")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Drag ≡ to change the order you perform lifts. Sets stay with each lift.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Lifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: offsets, toOffset: destination)
    }
}

private struct PriorStrengthSessionSheet: View {
    let session: PriorStrengthSession
    @Environment(\.dismiss) private var dismiss

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Date", value: Self.dateFormatter.string(from: session.date))
                    LabeledContent("Match", value: session.matchLabel)
                } header: {
                    Text(session.title)
                }

                ForEach(session.lifts) { lift in
                    Section(lift.name) {
                        ForEach(Array(lift.sets.enumerated()), id: \.offset) { index, set in
                            HStack {
                                Text("Set \(index + 1)")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(setLine(set))
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Last Similar Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func setLine(_ set: (weight: String, reps: String)) -> String {
        let w = set.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = set.reps.trimmingCharacters(in: .whitespacesAndNewlines)
        if w.isEmpty, r.isEmpty { return "—" }
        if w.isEmpty { return "×\(r)" }
        if r.isEmpty { return "\(w) lb" }
        return "\(w) lb × \(r)"
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
