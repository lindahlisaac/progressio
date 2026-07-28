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
    /// Last weight copied from the first fillable set — later sets matching this (or empty) stay in sync while typing.
    @State private var lastAutofilledWeightByExercise: [UUID: String] = [:]

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
        _exercises = State(initialValue: seededFromSnapshot)
        let completed = workout.status == .completed || workout.status == .partiallyCompleted
        _isCompleted = State(initialValue: completed)
        _isLocked = State(initialValue: completed)
        _note = State(initialValue: workout.notes ?? "")
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
                            onWeightEdited: {
                                autofillWeight(from: set.id, in: exercise.id)
                            },
                            isLocked: isLocked
                        )
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !isLocked {
                                Button {
                                    toggleSkip(setID: set.id, in: exercise.id)
                                } label: {
                                    Label(set.isSkipped ? "Unskip" : "Skip", systemImage: set.isSkipped ? "arrow.uturn.backward" : "forward.fill")
                                }
                                .tint(set.isSkipped ? .blue : .orange)
                            }
                        }
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
            seedAutofillWeights()
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
        let fillWeight = exercises[idx].sets
            .first(where: { !$0.isSkipped && !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })?
            .weight ?? ""
        let hint = exercises[idx].sets.last?.repHint ?? ""
        exercises[idx].sets.append(SetLog(weight: fillWeight, reps: "", repHint: hint))
        persistState()
    }

    /// Copies weight from the first non-skipped set into later empty / previously autofilled sets.
    /// Tracks the last seed so typing `1` → `13` → `135` updates followers instead of locking them at `1`.
    private func autofillWeight(from setID: UUID, in exerciseID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        let sets = exercises[exerciseIndex].sets
        guard let sourceIndex = sets.firstIndex(where: { $0.id == setID }),
              let firstFillable = sets.firstIndex(where: { !$0.isSkipped }),
              sourceIndex == firstFillable
        else { return }

        let weight = sets[sourceIndex].weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousSeed = lastAutofilledWeightByExercise[exerciseID] ?? ""

        var changed = false
        for index in (sourceIndex + 1)..<sets.count {
            var set = exercises[exerciseIndex].sets[index]
            guard !set.isSkipped else { continue }
            let existing = set.weight.trimmingCharacters(in: .whitespacesAndNewlines)
            guard StrengthWeightAutofill.shouldUpdate(existing: existing, previousSeed: previousSeed) else { continue }
            guard existing != weight else { continue }
            set.weight = weight
            exercises[exerciseIndex].sets[index] = set
            changed = true
        }
        lastAutofilledWeightByExercise[exerciseID] = weight
        if changed { persistState() }
    }

    private func seedAutofillWeights() {
        var seeds: [UUID: String] = [:]
        for exercise in exercises {
            guard let first = exercise.sets.first(where: { !$0.isSkipped }) else { continue }
            seeds[exercise.id] = first.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        lastAutofilledWeightByExercise = seeds
    }

    private func toggleSkip(setID: UUID, in exerciseID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID })
        else { return }
        exercises[exerciseIndex].sets[setIndex].isSkipped.toggle()
        if exercises[exerciseIndex].sets[setIndex].isSkipped {
            // Skipped sets stay in structure but are not "empty incomplete" logging targets.
            exercises[exerciseIndex].sets[setIndex].weight = ""
            exercises[exerciseIndex].sets[setIndex].reps = ""
        } else if let source = exercises[exerciseIndex].sets.first(where: {
            !$0.isSkipped && !$0.weight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) {
            autofillWeight(from: source.id, in: exerciseID)
        }
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
        seedAutofillWeights()
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

/// Pure rules for progressive weight autofill while typing into set 1.
enum StrengthWeightAutofill {
    /// Update empty followers, or followers still equal to the last autofilled seed (so `1`→`135` keeps pace).
    static func shouldUpdate(existing: String, previousSeed: String) -> Bool {
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = previousSeed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == seed
    }
}

private struct SetRow: View {
    @Binding var set: SetLog
    var isInputFocused: FocusState<Bool>.Binding
    var onChanged: () -> Void
    var onWeightEdited: () -> Void
    var isLocked: Bool

    @State private var repSelection: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if set.isSkipped {
                Label("Skipped", systemImage: "forward.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
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
                            .onChange(of: set.weight) { _ in
                                onChanged()
                                onWeightEdited()
                            }
                        Text("lb")
                            .foregroundStyle(.secondary)
                    }
                    .disabled(isLocked || set.isSkipped)
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
                        .disabled(isLocked || set.isSkipped)

                        Spacer()

                        if !set.repHint.isEmpty {
                            Text(set.repHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .opacity(set.isSkipped ? 0.45 : 1)
        }
        .onAppear {
            if let current = Int(set.reps.trimmingCharacters(in: .whitespacesAndNewlines)),
               !set.reps.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                repSelection = max(0, min(99, current))
            } else if let midpoint = TemplateSnapshot.midpointReps(from: set.repHint) {
                // Highlight planned midpoint without writing until the user confirms a pick.
                repSelection = midpoint
            } else {
                repSelection = 0
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(set.isSkipped ? Color.orange.opacity(0.08) : nil)
    }
}
