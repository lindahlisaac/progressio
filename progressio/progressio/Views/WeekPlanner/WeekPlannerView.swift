import SwiftUI

struct WeekPlannerView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @ObservedObject var templatesViewModel: TemplateLibraryViewModel
    @State private var templatePickerContext: TemplatePickerContext?
    @State private var previousUnattachedCount: Int = 0
    @State private var showingUnattachedSheet = false
    @State private var showingWeeklyTemplatePicker = false
    @State private var showingApplyTemplateAlert = false
    @State private var selectedWeeklyTemplate: WeeklyTemplate?
    @State private var showingSaveWeekAsTemplate = false
    @State private var saveTemplateName: String = ""
    @State private var saveTemplateNote: String = ""
    @State private var showingSkipSheet = false
    @State private var skipNote: String = ""
    @State private var skipSessionID: UUID?
    @State private var pendingMoveWorkoutID: UUID?
    @State private var pendingMoveDate: Date?
    @State private var showingMoveConfirm = false
    @State private var pasteTargetDate: Date?
    @State private var showingPasteModeAlert = false
    @State private var showingPeriodizedBlockPicker = false
    @State private var selectedPeriodizedBlock: PeriodizedBlockTemplate?
    @State private var showingApplyPeriodizedAlert = false
    @State private var showingWeekExport = false

    private var plannerNavigationTitle: String {
        if let name = viewModel.weekPlan.appliedPeriodizedWeekName, !name.isEmpty {
            return name
        }
        return "This Week"
    }

    var body: some View {
        List {
            unattachedRunsSection
            weeklyTotalsSection
            daysSection
        }
        .navigationTitle(plannerNavigationTitle)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    viewModel.goToPreviousWeek(templates: templatesViewModel.activeTemplates)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous week")
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Section("Templates") {
                        Button {
                            showingWeeklyTemplatePicker = true
                        } label: {
                            Label("Apply Weekly Template", systemImage: "rectangle.stack.badge.plus")
                        }
                        .disabled(viewModel.activeWeeklyTemplates.isEmpty)

                        Button {
                            showingPeriodizedBlockPicker = true
                        } label: {
                            Label("Apply Periodized Block", systemImage: "calendar.badge.clock")
                        }
                        .disabled(viewModel.activePeriodizedBlocks.isEmpty)

                        Button {
                            saveTemplateName = ""
                            saveTemplateNote = ""
                            showingSaveWeekAsTemplate = true
                        } label: {
                            Label("Save Week as Template", systemImage: "square.and.arrow.down")
                        }
                        .disabled(!viewModel.hasWorkoutsInCurrentWeek())
                    }

                    Section {
                        Button {
                            showingWeekExport = true
                        } label: {
                            Label("Export Week Summary", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Week options")

                Button {
                    viewModel.goToNextWeek(templates: templatesViewModel.activeTemplates)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next week")
            }
        }
        .onAppear {
            viewModel.dedupeUnattachedRuns()
        }
        .onChange(of: viewModel.activeUnattachedRuns.count) { newCount in
            if newCount > previousUnattachedCount {
                showingUnattachedSheet = true
            }
            previousUnattachedCount = newCount
        }
        .sheet(item: $templatePickerContext) { context in
            modalityTemplatePickerSheet(for: context)
        }
        .sheet(isPresented: $showingUnattachedSheet) {
            NavigationStack {
                UnattachedRunsView(
                    runs: viewModel.activeUnattachedRuns,
                    days: viewModel.weekPlan.days,
                    onAttach: { date, run, workoutID in
                        viewModel.attachActualRun(to: date, run: run, toWorkoutID: workoutID)
                        viewModel.removeUnattachedRun(id: run.id)
                    }
                )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingUnattachedSheet = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingWeekExport) {
            WeekExportSummaryView(
                weekPlan: viewModel.weekPlan,
                periodizedWeekName: viewModel.weekPlan.appliedPeriodizedWeekName
            )
        }
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
                        Button("Cancel") {
                            showingWeeklyTemplatePicker = false
                        }
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
                        Button("Cancel") {
                            showingSaveWeekAsTemplate = false
                        }
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

    private var unattachedRunsSection: some View {
        Group {
            if !viewModel.activeUnattachedRuns.isEmpty {
                NavigationLink {
                    UnattachedRunsView(
                        runs: viewModel.activeUnattachedRuns,
                        days: viewModel.weekPlan.days,
                        onAttach: { date, run, workoutID in
                            viewModel.attachActualRun(to: date, run: run, toWorkoutID: workoutID)
                            viewModel.removeUnattachedRun(id: run.id)
                        }
                    )
                } label: {
                    HStack {
                        Label("Unattached runs", systemImage: "bolt.heart")
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Text("\(viewModel.activeUnattachedRuns.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var weeklyTotalsSection: some View {
        let totals = WeekTotals.modalityTotals(for: viewModel.weekPlan)
        return Section {
            if totals.isEmpty {
                Text("No workouts this week")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(totals) { total in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Label(total.activityType.rawValue, systemImage: total.activityType.systemImage)
                            Spacer()
                            Text("\(formatTotal(total.completedAmount, strength: total.activityType == .strength)) / \(formatTotal(total.plannedAmount, strength: total.activityType == .strength)) \(total.unitLabel)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if total.plannedElevation > 0 {
                            Text("\(formatElevation(total.plannedElevation)) ft planned vert")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 28)
                        }
                    }
                }
            }
        } header: {
            Text("Weekly totals")
        }
    }

    private func formatTotal(_ value: Double, strength: Bool) -> String {
        if strength {
            return String(Int(value.rounded()))
        }
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func formatElevation(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%.0f", value)
    }

    private var daysSection: some View {
        ForEach(viewModel.weekPlan.days) { day in
            daySection(for: day)
        }
    }

    @ViewBuilder
    private func daySection(for day: DayPlan) -> some View {
        Section(header: Text(dayHeader(for: day.date))) {
            if day.activeWorkouts.isEmpty {
                Text("No sessions planned")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(day.activeWorkouts) { workout in
                    NavigationLink {
                        workoutDestination(workout)
                    } label: {
                        WorkoutRow(
                            workout: workout,
                            onToggle: { viewModel.toggleStatus(workoutID: workout.id) },
                            onDelete: { viewModel.removeWorkout(dayID: day.id, workoutID: workout.id) },
                            onSkip: {
                                skipSessionID = workout.id
                                skipNote = workout.status == .skipped ? (workout.skipReason ?? "") : ""
                                showingSkipSheet = true
                            },
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                    .draggable(workout.id.uuidString)
                    .contextMenu {
                        Button {
                            viewModel.copyWorkout(workoutID: workout.id)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                }
            }

            if viewModel.workoutClipboard != nil {
                Button {
                    pasteTargetDate = day.date
                    showingPasteModeAlert = true
                } label: {
                    Label("Paste workout", systemImage: "doc.on.clipboard")
                }
            }

            Menu("Add workout") {
                ForEach(ActivityType.plannerAddTypes) { activityType in
                    Menu {
                        Menu("Blank") {
                            Button("AM") {
                                viewModel.addWorkout(
                                    activityType: activityType,
                                    on: day.date,
                                    timePeriod: .am
                                )
                            }
                            Button("PM") {
                                viewModel.addWorkout(
                                    activityType: activityType,
                                    on: day.date,
                                    timePeriod: .pm
                                )
                            }
                        }
                        if hasTemplates(for: activityType) {
                            Menu("From template") {
                                Button("AM") {
                                    openTemplatePicker(for: activityType, on: day.date, timePeriod: .am)
                                }
                                Button("PM") {
                                    openTemplatePicker(for: activityType, on: day.date, timePeriod: .pm)
                                }
                            }
                        }
                    } label: {
                        Label(activityType.rawValue, systemImage: activityType.systemImage)
                    }
                }
                if !viewModel.activeUnattachedRuns.isEmpty {
                    Divider()
                    Button {
                        viewModel.addRun(on: day.date, title: "Detected run", planned: false)
                    } label: {
                        Label("Attach detected run", systemImage: "bolt.heart")
                    }
                }
            }
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let workoutID = UUID(uuidString: raw) else { return false }
            requestMove(workoutID: workoutID, to: day.date)
            return true
        }
    }

    private func requestMove(workoutID: UUID, to date: Date) {
        if viewModel.workoutRequiresMoveConfirmation(workoutID: workoutID) {
            pendingMoveWorkoutID = workoutID
            pendingMoveDate = date
            showingMoveConfirm = true
        } else {
            _ = viewModel.moveWorkout(workoutID: workoutID, toDate: date)
        }
    }

    @ViewBuilder
    private func workoutDestination(_ workout: Workout) -> some View {
        if workout.activityType == .strength {
            StrengthLogView(
                workout: workout,
                onNoteChange: { note in
                    viewModel.setWorkoutNote(workoutID: workout.id, note: note)
                },
                onTitleChange: { title in
                    viewModel.setWorkoutTitle(workoutID: workout.id, title: title)
                },
                loadPriorComparison: { liftNames in
                    viewModel.strengthComparison(for: workout, liftNames: liftNames)
                },
                onCompleteStatus: {
                    viewModel.setWorkoutStatus(workoutID: workout.id, status: .completed)
                },
                onUnlockStatus: {
                    viewModel.setWorkoutStatus(workoutID: workout.id, status: .planned)
                },
                onCompletedSnapshotPersist: { snapshot in
                    viewModel.updateCompletedStrengthSnapshot(workoutID: workout.id, snapshot: snapshot)
                },
                onTimePeriodChange: { period in
                    viewModel.setWorkoutTimePeriod(workoutID: workout.id, timePeriod: period)
                }
            )
        } else if workout.activityType.sessionKind == .run {
            RunDetailView(
                workout: workout,
                onSave: { title, activityType, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    viewModel.updateEnduranceWorkout(
                        workoutID: workout.id,
                        title: title,
                        runType: category.flatMap(RunType.init(runCategory:)),
                        plannedDistance: plannedDistance,
                        plannedDuration: plannedDuration,
                        plannedElevation: plannedElevation,
                        status: status,
                        actualDistance: actualDistance,
                        actualDuration: actualDuration,
                        actualElevation: actualElevation,
                        timePeriod: timePeriod,
                        activityType: activityType,
                        notes: notes
                    )
                }
            )
        } else {
            RideDetailView(
                workout: workout,
                onSave: { title, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    viewModel.updateEnduranceWorkout(
                        workoutID: workout.id,
                        title: title,
                        runType: category.flatMap(RunType.init(runCategory:)),
                        plannedDistance: plannedDistance,
                        plannedDuration: plannedDuration,
                        plannedElevation: plannedElevation,
                        status: status,
                        actualDistance: actualDistance,
                        actualDuration: actualDuration,
                        actualElevation: actualElevation,
                        timePeriod: timePeriod,
                        notes: notes
                    )
                }
            )
        }
    }

    private func hasTemplates(for activityType: ActivityType) -> Bool {
        if activityType == .strength {
            return !templatesViewModel.activeTemplates.isEmpty
        }
        return templatesViewModel.activeEnduranceTemplates.contains { $0.activityType == activityType }
    }

    private func openTemplatePicker(for activityType: ActivityType, on date: Date, timePeriod: TimePeriod) {
        // Use sheet(item:) so Menu → sheet doesn't present with a stale nil activity type.
        templatePickerContext = TemplatePickerContext(
            date: date,
            activityType: activityType,
            timePeriod: timePeriod
        )
    }

    private func modalityTemplatePickerSheet(for context: TemplatePickerContext) -> some View {
        NavigationStack {
            List {
                if context.activityType == .strength {
                    if templatesViewModel.activeTemplates.isEmpty {
                        Text("No strength templates yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(templatesViewModel.activeTemplates) { template in
                        Button {
                            viewModel.addStrengthSession(
                                template: template,
                                on: context.date,
                                timePeriod: context.timePeriod
                            )
                            templatePickerContext = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let note = template.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    let matches = templatesViewModel.activeEnduranceTemplates.filter {
                        $0.activityType == context.activityType
                    }
                    if matches.isEmpty {
                        Text("No \(context.activityType.rawValue) templates yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(matches) { template in
                        Button {
                            viewModel.addEnduranceSession(
                                template: template,
                                on: context.date,
                                timePeriod: context.timePeriod
                            )
                            templatePickerContext = nil
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                HStack {
                                    Text(template.activityType.rawValue)
                                    if let runType = template.runType {
                                        Text("• \(runType.rawValue)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if let distance = template.plannedDistance, !distance.isEmpty {
                                    Text("Distance: \(distance)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(context.activityType.rawValue) Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        templatePickerContext = nil
                    }
                }
            }
        }
    }

    private func dayHeader(for date: Date) -> String {
        let dayString = dayFormatter.string(from: date)
        let short = shortDayFormatter.string(from: date)
        return "\(short) • \(dayString)"
    }
}

private struct TemplatePickerContext: Identifiable {
    let id = UUID()
    let date: Date
    let activityType: ActivityType
    let timePeriod: TimePeriod
}

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

private let shortDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter
}()

struct WorkoutRow: View {
    let workout: Workout
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSkip: () -> Void
    var showsDisclosure: Bool = false

    private var leadingLabel: String {
        switch workout.status {
        case .imported:
            return "Mark Planned"
        case .planned:
            return "Mark Complete"
        case .completed, .partiallyCompleted:
            return "Mark Planned"
        case .skipped:
            return "Mark Planned"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: workout.activityType.systemImage)
                .foregroundStyle(color(for: workout.sessionKind))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(workout.title)
                        .font(.headline)
                        .strikethrough(workout.status == .skipped, color: .secondary)
                        .foregroundStyle(workout.status == .skipped ? .secondary : .primary)
                    Text(workout.timePeriod.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(workout.activityType.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if workout.status == .skipped, let reason = workout.skipReason,
                   !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(truncated(reason, limit: 60))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
                enduranceSummary
                strengthSummary
            }

            Spacer(minLength: 8)

            Text(workout.status.badgeLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(workout.status.tint.opacity(0.15))
                .foregroundStyle(workout.status.tint)
                .clipShape(Capsule())
                .accessibilityLabel(workout.status.rawValue)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                onToggle()
            } label: {
                Label(leadingLabel, systemImage: workout.status == .completed || workout.status == .partiallyCompleted ? "arrow.uturn.left" : "checkmark.circle")
            }
            .tint(workout.status == .completed || workout.status == .partiallyCompleted ? .blue : .green)
            Button {
                onSkip()
            } label: {
                Label("Skip", systemImage: "slash.circle")
            }
            .tint(.gray)
        }
    }

    @ViewBuilder
    private var enduranceSummary: some View {
        if workout.activityType.sessionKind == .run || workout.activityType == .bike {
            if workout.hasCompletedEnduranceDetail {
                if !workout.actualDistance.isEmpty {
                    Text("Actual \(workout.actualDistance) mi")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                if !workout.plannedDistance.isEmpty {
                    Text("Planned \(workout.plannedDistance) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                enduranceChip
            } else if workout.hasPlannedEnduranceDetail {
                if !workout.plannedDistance.isEmpty {
                    Text("\(workout.plannedDistance) mi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                enduranceChip
            }
        }
    }

    @ViewBuilder
    private var enduranceChip: some View {
        if let cat = workout.runType?.runCategory {
            chip(text: cat.rawValue, color: cat.tint)
        } else if workout.activityType == .bike {
            chip(text: "Bike", color: .orange)
        }
    }

    @ViewBuilder
    private var strengthSummary: some View {
        if workout.activityType == .strength {
            if let template = workout.templateName {
                Text(template)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if workout.status != .skipped, let note = workout.notes,
               !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(truncated(note, limit: 60))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func color(for kind: SessionKind) -> Color {
    switch kind {
    case .strength:
        return .blue
    case .run:
        return .purple
    case .cycle:
        return .orange
    }
}

private func chip(text: String, color: Color) -> some View {
    Text(text)
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .foregroundStyle(color)
        .clipShape(Capsule())
}

private func truncated(_ text: String, limit: Int) -> String {
    if text.count <= limit { return text }
    let idx = text.index(text.startIndex, offsetBy: limit)
    return text[text.startIndex..<idx] + "…"
}
