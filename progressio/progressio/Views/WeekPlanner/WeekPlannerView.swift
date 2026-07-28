import SwiftUI

struct WeekPlannerView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @ObservedObject var templatesViewModel: TemplateLibraryViewModel
    @EnvironmentObject private var metricPreferences: ActivityMetricPreferenceStore
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
    @State private var reflectionWorkoutID: UUID?
    @State private var showingWeeklyReflection = false
    @State private var showingWeekCloseValidation = false
    @State private var showingSkipUnresolvedConfirm = false
    @State private var showingSettings = false

    private var reflectionWorkout: Workout? {
        guard let id = reflectionWorkoutID else { return nil }
        return viewModel.weekPlan.days.flatMap(\.activeWorkouts).first { $0.id == id }
    }

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
            weekCloseSection
        }
        .navigationTitle(plannerNavigationTitle)
        .toolbar { plannerToolbarContent }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView(weekViewModel: viewModel)
                    .environmentObject(metricPreferences)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
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
        .modifier(WeekPlannerReflectionPresentations(
            viewModel: viewModel,
            templatePickerContext: $templatePickerContext,
            showingUnattachedSheet: $showingUnattachedSheet,
            showingWeekExport: $showingWeekExport,
            reflectionWorkoutID: $reflectionWorkoutID,
            showingWeeklyReflection: $showingWeeklyReflection,
            showingWeekCloseValidation: $showingWeekCloseValidation,
            showingSkipUnresolvedConfirm: $showingSkipUnresolvedConfirm,
            reflectionWorkout: reflectionWorkout,
            modalityTemplatePicker: { context in AnyView(modalityTemplatePickerSheet(for: context)) }
        ))
        .modifier(WeekPlannerTemplatePresentations(
            viewModel: viewModel,
            showingWeeklyTemplatePicker: $showingWeeklyTemplatePicker,
            showingPeriodizedBlockPicker: $showingPeriodizedBlockPicker,
            showingSaveWeekAsTemplate: $showingSaveWeekAsTemplate,
            saveTemplateName: $saveTemplateName,
            saveTemplateNote: $saveTemplateNote,
            selectedWeeklyTemplate: $selectedWeeklyTemplate,
            selectedPeriodizedBlock: $selectedPeriodizedBlock,
            showingApplyTemplateAlert: $showingApplyTemplateAlert,
            showingApplyPeriodizedAlert: $showingApplyPeriodizedAlert,
            showingSkipSheet: $showingSkipSheet,
            skipNote: $skipNote,
            skipSessionID: $skipSessionID,
            showingMoveConfirm: $showingMoveConfirm,
            pendingMoveWorkoutID: $pendingMoveWorkoutID,
            pendingMoveDate: $pendingMoveDate,
            showingPasteModeAlert: $showingPasteModeAlert,
            pasteTargetDate: $pasteTargetDate
        ))
    }

    @ToolbarContentBuilder
    private var plannerToolbarContent: some ToolbarContent {
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

                Section {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
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


    private var unattachedRunsSection: some View {
        Group {
            if !viewModel.activeUnattachedRuns.isEmpty {
                NavigationLink {
                    UnattachedRunsView(
                        runs: viewModel.activeUnattachedRuns,
                        days: viewModel.weekPlan.days,
                        onAttach: { date, run, workoutID in
                            if let completedID = viewModel.attachActualRun(to: date, run: run, toWorkoutID: workoutID) {
                                requestActivityReflection(for: completedID)
                            }
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
        let _ = metricPreferences.revision
        let totals = WeekTotals.modalityTotals(for: viewModel.weekPlan, preferences: metricPreferences)
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

    private var weekCloseSection: some View {
        Section {
            if viewModel.weekPlan.isWeekComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Week complete", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    if let when = viewModel.weekPlan.weekCompletedAt {
                        Text(dayFormatter.string(from: when))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let reflection = viewModel.weeklyReflection(for: viewModel.currentWeekKey) {
                        Text("Rated \(reflection.weekRating)/10 · Fatigue \(reflection.fatigue.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Reopen week") {
                        viewModel.reopenWeek()
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    beginWeekClose()
                } label: {
                    Text("Complete Week")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .tint(.green)
            }
        }
    }

    private func beginWeekClose() {
        let unresolved = viewModel.unresolvedWorkoutsForWeekClose()
        if unresolved.isEmpty {
            showingWeeklyReflection = true
        } else {
            showingWeekCloseValidation = true
        }
    }

    private func requestActivityReflection(for workoutID: UUID) {
        reflectionWorkoutID = workoutID
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
                            onToggle: {
                                if viewModel.toggleStatus(workoutID: workout.id) {
                                    requestActivityReflection(for: workout.id)
                                }
                            },
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
                    requestActivityReflection(for: workout.id)
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
        } else if workout.activityType == .stairMaster {
            StairMasterDetailView(
                workout: workout,
                onSave: { title, plannedDuration, plannedElevation, plannedLevel, status, actualDuration, actualElevation, actualLevel, timePeriod, notes in
                    let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
                    viewModel.updateEnduranceWorkout(
                        workoutID: workout.id,
                        title: title,
                        runType: nil,
                        plannedDistance: "",
                        plannedDuration: plannedDuration,
                        plannedElevation: plannedElevation,
                        plannedLevel: plannedLevel,
                        status: status,
                        actualDistance: nil,
                        actualDuration: actualDuration,
                        actualElevation: actualElevation,
                        actualLevel: actualLevel,
                        timePeriod: timePeriod,
                        activityType: .stairMaster,
                        notes: notes
                    )
                    if status == .completed, !wasComplete {
                        requestActivityReflection(for: workout.id)
                    }
                }
            )
        } else if workout.activityType.sessionKind == .run {
            RunDetailView(
                workout: workout,
                onSave: { title, activityType, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
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
                    if status == .completed, !wasComplete {
                        requestActivityReflection(for: workout.id)
                    }
                }
            )
        } else {
            RideDetailView(
                workout: workout,
                onSave: { title, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes in
                    let wasComplete = workout.status == .completed || workout.status == .partiallyCompleted
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
                    if status == .completed, !wasComplete {
                        requestActivityReflection(for: workout.id)
                    }
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
                .foregroundStyle(color(for: workout.activityType))

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
        if workout.activityType == .stairMaster {
            if workout.hasCompletedEnduranceDetail {
                if !workout.actualDuration.isEmpty {
                    Text("Actual \(workout.actualDuration)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                if !workout.actualLevel.isEmpty {
                    Text("Level \(workout.actualLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !workout.actualElevation.isEmpty {
                    Text("\(workout.actualElevation) ft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if workout.hasPlannedEnduranceDetail {
                if !workout.plannedDuration.isEmpty {
                    Text(workout.plannedDuration)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !workout.plannedLevel.isEmpty {
                    Text("Level \(workout.plannedLevel)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !workout.plannedElevation.isEmpty {
                    Text("\(workout.plannedElevation) ft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else if workout.activityType.sessionKind == .run || workout.activityType == .bike {
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

private func color(for activityType: ActivityType) -> Color {
    switch activityType {
    case .strength:
        return .blue
    case .roadRun, .trailRun, .walk:
        return .purple
    case .bike:
        return .orange
    case .stairMaster:
        return .teal
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
