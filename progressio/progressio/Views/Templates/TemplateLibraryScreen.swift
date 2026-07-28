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
    @State private var newLiftPickerMode: TemplateLiftPickerMode?
    @State private var newRunCategory: RunCategory = .easy
    @State private var newActivityType: ActivityType = .roadRun
    @State private var newPlannedDistance: String = ""
    @State private var newPlannedDuration: String = ""
    @State private var newPlannedElevation: String = ""
    @State private var newPlannedLevel: String = "10"
    @State private var newIntensityRPE: String = ""
    @State private var templatePendingDelete: StrengthTemplate?
    @State private var endurancePendingDelete: EnduranceTemplate?
    @State private var showingDeleteAlert = false
    @State private var showingEnduranceDeleteAlert = false
    @State private var selection: TemplateKind = .workout
    @State private var weeklyName: String = ""
    @State private var weeklyNote: String = ""
    @State private var weeklyDraftDays: [DayTemplate] = TemplateLibraryView.blankWeek()
    @State private var showingWorkoutTemplatePicker = false
    @State private var selectedDayIndexForTemplate: Int?
    @State private var showingApplyAlert = false
    @State private var templateToApply: WeeklyTemplate?
    @State private var showingPeriodizedAddSheet = false
    @State private var blockPendingDelete: PeriodizedBlockTemplate?
    @State private var showingBlockDeleteAlert = false
    @State private var blockToApply: PeriodizedBlockTemplate?
    @State private var showingBlockApplyAlert = false

    var body: some View {
        templateListContent
            .navigationTitle("Templates")
            .toolbar { addToolbar }
            .modifier(TemplateLibraryAlertsModifier(
                viewModel: viewModel,
                weekViewModel: weekViewModel,
                templatePendingDelete: $templatePendingDelete,
                showingDeleteAlert: $showingDeleteAlert,
                endurancePendingDelete: $endurancePendingDelete,
                showingEnduranceDeleteAlert: $showingEnduranceDeleteAlert,
                blockPendingDelete: $blockPendingDelete,
                showingBlockDeleteAlert: $showingBlockDeleteAlert,
                templateToApply: $templateToApply,
                showingApplyAlert: $showingApplyAlert,
                blockToApply: $blockToApply,
                showingBlockApplyAlert: $showingBlockApplyAlert
            ))
            .sheet(isPresented: $showingAddSheet) { workoutTemplateSheet }
            .sheet(isPresented: $showingWeeklyAddSheet) { weeklyTemplateSheet }
            .sheet(isPresented: $showingPeriodizedAddSheet) {
                CreatePeriodizedBlockSheet(weekViewModel: weekViewModel, isPresented: $showingPeriodizedAddSheet)
            }
    }

    @ViewBuilder
    private var templateListContent: some View {
        List {
            Picker("Template view", selection: $selection) {
                ForEach(TemplateKind.allCases) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            switch selection {
            case .workout:
                strengthTemplatesSection
                enduranceTemplatesSection
            case .weekly:
                weeklyTemplatesSection
            case .blocks:
                PeriodizedBlocksSection(
                    weekViewModel: weekViewModel,
                    blockPendingDelete: $blockPendingDelete,
                    showingDeleteAlert: $showingBlockDeleteAlert,
                    blockToApply: $blockToApply,
                    showingApplyAlert: $showingBlockApplyAlert
                )
            }
        }
    }

    @ViewBuilder
    private var strengthTemplatesSection: some View {
        Section("Strength") {
            if viewModel.activeTemplates.isEmpty {
                Text("No strength templates yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.activeTemplates, id: \.id) { template in
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Do not use role: .destructive here — that animates a row removal
                        // before the confirmation alert soft-deletes, crashing the List.
                        Button {
                            templatePendingDelete = template
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var enduranceTemplatesSection: some View {
        Section("Endurance") {
            if viewModel.activeEnduranceTemplates.isEmpty {
                Text("No endurance templates yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.activeEnduranceTemplates, id: \.id) { template in
                    NavigationLink {
                        EnduranceTemplateDetailView(template: template, viewModel: viewModel)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.name)
                                .font(.headline)
                            if let description = template.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                Text(template.activityType.rawValue)
                                if let runType = template.runType {
                                    Text("• \(runType.rawValue)")
                                }
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            endurancePendingDelete = template
                            showingEnduranceDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weeklyTemplatesSection: some View {
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
                            Text("\(template.days.flatMap { $0.workoutEntries }.count) workouts")
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

    @ToolbarContentBuilder
    private var addToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                switch selection {
                case .workout:
                    showingAddSheet = true
                case .weekly:
                    weeklyDraftDays = TemplateLibraryView.blankWeek()
                    weeklyName = ""
                    weeklyNote = ""
                    showingWeeklyAddSheet = true
                case .blocks:
                    showingPeriodizedAddSheet = true
                }
            } label: {
                Label(addButtonTitle, systemImage: "plus")
            }
            .accessibilityLabel(addButtonTitle)
        }
    }

    private var addButtonTitle: String {
        switch selection {
        case .workout: return "Add Template"
        case .weekly: return "Add Weekly"
        case .blocks: return "Add Block"
        }
    }

    @ViewBuilder
    private func applyWeeklyTemplateActions(_ template: WeeklyTemplate) -> some View {
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
    }

    private func applyWeeklyTemplateMessage(_ template: WeeklyTemplate) -> Text {
        if weekViewModel.hasWorkoutsInCurrentWeek() {
            return Text("You have existing workouts this week. Choose to override them or keep them alongside '\(template.name)'.")
        }
        return Text("This will apply '\(template.name)' to the current week.")
    }

    private func saveTemplate() {
        if newTemplateCategory == .strength {
            viewModel.addTemplate(
                name: newTemplateName,
                note: newTemplateNote,
                exercises: Self.exercises(from: newExercises)
            )
        } else {
            viewModel.addEnduranceTemplate(
                name: newTemplateName,
                activityType: newActivityType,
                runType: newActivityType.usesRunType ? RunType(runCategory: newRunCategory) : nil,
                plannedDistance: newActivityType.usesDistanceMetric ? Self.trimmedOrNil(newPlannedDistance) : nil,
                plannedDuration: Self.trimmedOrNil(newPlannedDuration),
                plannedElevationGain: Self.trimmedOrNil(newPlannedElevation),
                plannedLevel: newActivityType == .stairMaster ? Self.trimmedOrNil(newPlannedLevel) : nil,
                description: Self.trimmedOrNil(newTemplateNote),
                intensityRPE: Self.trimmedOrNil(newIntensityRPE)
            )
        }
        dismissSheet()
    }

    private static func trimmedOrNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
        newActivityType = .roadRun
        newPlannedDistance = ""
        newPlannedDuration = ""
        newPlannedElevation = ""
        newPlannedLevel = "10"
        newIntensityRPE = ""
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
                if newTemplateCategory == .endurance {
                    Section("Activity") {
                        Picker("Activity type", selection: $newActivityType) {
                            ForEach(ActivityType.enduranceTemplateTypes) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                    }
                    if newActivityType.usesRunType {
                        Section("Run type") {
                            Picker("Run type", selection: $newRunCategory) {
                                ForEach(RunCategory.allCases) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                        }
                    }
                    Section("Planned values") {
                        if newActivityType.usesDistanceMetric {
                            TextField("Distance (mi, optional)", text: $newPlannedDistance)
                        }
                        TextField("Duration (optional)", text: $newPlannedDuration)
                        TextField(
                            newActivityType == .stairMaster
                                ? "Elevation (ft, optional)"
                                : "Elevation gain (optional)",
                            text: $newPlannedElevation
                        )
                        if newActivityType == .stairMaster {
                            TextField("Level 1–20 (optional)", text: $newPlannedLevel)
                                .keyboardType(.numberPad)
                        }
                        TextField("Intensity RPE (optional)", text: $newIntensityRPE)
                            .keyboardType(.decimalPad)
                    }
                }
                if newTemplateCategory == .strength {
                    StrengthTemplateExerciseEditor(
                        exercises: $newExercises,
                        exerciseName: $newExerciseName,
                        exerciseSetsCount: $newExerciseSetsCount,
                        exerciseMinReps: $newExerciseMinReps,
                        exerciseMaxReps: $newExerciseMaxReps,
                        liftPickerMode: $newLiftPickerMode
                    )
                }
            }
            .navigationTitle("New Template")
            .navigationDestination(isPresented: Binding(
                get: { newLiftPickerMode != nil },
                set: { if !$0 { newLiftPickerMode = nil } }
            )) {
                templateLiftPicker(
                    mode: newLiftPickerMode,
                    onPick: { name in
                        applyTemplateLiftPick(
                            name,
                            mode: newLiftPickerMode,
                            exercises: $newExercises,
                            draftName: $newExerciseName
                        )
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissSheet() }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if newTemplateCategory == .strength, !newExercises.isEmpty {
                        EditButton()
                    }
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(isSaveDisabled)
                }
            }
            .keyboardDoneButton()
        }
    }

    @ViewBuilder
    private func templateLiftPicker(
        mode: TemplateLiftPickerMode?,
        onPick: @escaping (String) -> Void
    ) -> some View {
        let title: String = {
            if case .replace = mode { return "Change Lift" }
            return "Choose Lift"
        }()
        LiftPickerView(
            title: title,
            embedsNavigationStack: false,
            onSelect: { lift in onPick(lift.name) },
            onSelectCustom: { name in onPick(name) }
        )
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
                .keyboardDoneButton()
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
            ForEach(weeklyDraftDays[idx].workoutEntries) { entry in
                HStack {
                    Text(entry.title)
                    Spacer()
                    Text(entry.activityType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                weeklyDraftDays[idx].workoutEntries.remove(atOffsets: offsets)
            }
            Menu("Add workout") {
                ForEach(ActivityType.plannerAddTypes) { activityType in
                    Button("Blank \(activityType.rawValue)") {
                        weeklyDraftDays[idx].workoutEntries.append(
                            WeeklyTemplateWorkoutEntry.blank(activityType: activityType)
                        )
                    }
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
            if !viewModel.activeTemplates.isEmpty {
                Section("Strength") {
                    ForEach(viewModel.activeTemplates) { template in
                        Button {
                            addStrengthTemplateToWeeklyDraft(template)
                        } label: {
                            strengthTemplatePickerRow(template)
                        }
                    }
                }
            }
            if !viewModel.activeEnduranceTemplates.isEmpty {
                Section("Endurance") {
                    ForEach(viewModel.activeEnduranceTemplates) { template in
                        Button {
                            addEnduranceTemplateToWeeklyDraft(template)
                        } label: {
                            enduranceTemplatePickerRow(template)
                        }
                    }
                }
            }
        }
    }

    private func addStrengthTemplateToWeeklyDraft(_ template: StrengthTemplate) {
        guard let dayIdx = selectedDayIndexForTemplate else { return }
        var planned = PlannedValues.empty
        planned.plannedStrengthRoutineSnapshot = TemplateSnapshot.plannedSnapshot(from: template)
        weeklyDraftDays[dayIdx].workoutEntries.append(
            WeeklyTemplateWorkoutEntry(
                activityType: .strength,
                title: template.name,
                notes: template.note,
                plannedValues: planned,
                linkedWorkoutTemplateId: template.id,
                templateName: template.name
            )
        )
        showingWorkoutTemplatePicker = false
    }

    private func addEnduranceTemplateToWeeklyDraft(_ template: EnduranceTemplate) {
        guard let dayIdx = selectedDayIndexForTemplate else { return }
        var planned = PlannedValues.empty
        planned.plannedDistance = template.plannedDistance
        planned.plannedDuration = template.plannedDuration
        planned.plannedElevationGain = template.plannedElevationGain
        planned.plannedLevel = template.plannedLevel
        planned.plannedDescription = template.description
        planned.plannedIntensityRPE = template.intensityRPE
        planned.plannedRoute = template.route
        weeklyDraftDays[dayIdx].workoutEntries.append(
            WeeklyTemplateWorkoutEntry(
                activityType: template.activityType,
                runType: template.runType,
                title: template.name,
                notes: template.description,
                plannedValues: planned,
                linkedWorkoutTemplateId: template.id,
                templateName: template.name
            )
        )
        showingWorkoutTemplatePicker = false
    }

    @ViewBuilder
    private func strengthTemplatePickerRow(_ template: StrengthTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            Label("Strength", systemImage: TemplateCategory.strength.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let note = template.note, !note.isEmpty {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func enduranceTemplatePickerRow(_ template: EnduranceTemplate) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(template.name)
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
            HStack {
                Label(template.activityType.rawValue, systemImage: template.activityType.sessionKind.systemImage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let runType = template.runType {
                    Text("• \(runType.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let description = template.description, !description.isEmpty {
                Text(description)
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
        (1...7).map { DayTemplate(weekday: $0, workoutEntries: []) }
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
    case blocks

    var id: String { rawValue }

    var label: String {
        switch self {
        case .workout: return "Workouts"
        case .weekly: return "Weekly"
        case .blocks: return "Blocks"
        }
    }
}

private struct TemplateLibraryAlertsModifier: ViewModifier {
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @Binding var templatePendingDelete: StrengthTemplate?
    @Binding var showingDeleteAlert: Bool
    @Binding var endurancePendingDelete: EnduranceTemplate?
    @Binding var showingEnduranceDeleteAlert: Bool
    @Binding var blockPendingDelete: PeriodizedBlockTemplate?
    @Binding var showingBlockDeleteAlert: Bool
    @Binding var templateToApply: WeeklyTemplate?
    @Binding var showingApplyAlert: Bool
    @Binding var blockToApply: PeriodizedBlockTemplate?
    @Binding var showingBlockApplyAlert: Bool

    func body(content: Content) -> some View {
        content
            .alert("Delete template?", isPresented: $showingDeleteAlert, presenting: templatePendingDelete) { template in
                Button("Delete", role: .destructive) {
                    let id = template.id
                    templatePendingDelete = nil
                    viewModel.deleteTemplate(id: id)
                }
                Button("Cancel", role: .cancel) {
                    templatePendingDelete = nil
                }
            } message: { template in
                Text("\"\(template.name)\" will be removed from your library. Applied workouts are not affected.")
            }
            .alert("Delete template?", isPresented: $showingEnduranceDeleteAlert, presenting: endurancePendingDelete) { template in
                Button("Delete", role: .destructive) {
                    let id = template.id
                    endurancePendingDelete = nil
                    viewModel.deleteEnduranceTemplate(id: id)
                }
                Button("Cancel", role: .cancel) {
                    endurancePendingDelete = nil
                }
            } message: { template in
                Text("\"\(template.name)\" will be removed from your library. Applied workouts are not affected.")
            }
            .alert("Delete block?", isPresented: $showingBlockDeleteAlert, presenting: blockPendingDelete) { block in
                Button("Delete", role: .destructive) {
                    let id = block.id
                    blockPendingDelete = nil
                    weekViewModel.deletePeriodizedBlock(id: id)
                }
                Button("Cancel", role: .cancel) {
                    blockPendingDelete = nil
                }
            } message: { block in
                Text("\"\(block.name)\" will be removed from your library. Applied calendar weeks are not affected.")
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
            .alert("Apply Periodized Block?", isPresented: $showingBlockApplyAlert, presenting: blockToApply) { block in
                periodizedApplyButtons(block)
            } message: { block in
                periodizedApplyMessage(block)
            }
    }

    @ViewBuilder
    private func periodizedApplyButtons(_ block: PeriodizedBlockTemplate) -> some View {
        let hasConflicts = weekViewModel.periodizedBlockRangeHasWorkouts(
            startingAt: weekViewModel.currentStartOfWeek,
            weekCount: block.weekCount
        )
        if hasConflicts {
            Button("Merge") {
                weekViewModel.applyPeriodizedBlock(block, startingAt: weekViewModel.currentStartOfWeek, keepExisting: true)
            }
            Button("Overwrite", role: .destructive) {
                weekViewModel.applyPeriodizedBlock(block, startingAt: weekViewModel.currentStartOfWeek, keepExisting: false)
            }
            Button("Cancel", role: .cancel) {}
        } else {
            Button("Apply") {
                weekViewModel.applyPeriodizedBlock(block, startingAt: weekViewModel.currentStartOfWeek, keepExisting: true)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func periodizedApplyMessage(_ block: PeriodizedBlockTemplate) -> Text {
        let hasConflicts = weekViewModel.periodizedBlockRangeHasWorkouts(
            startingAt: weekViewModel.currentStartOfWeek,
            weekCount: block.weekCount
        )
        if hasConflicts {
            return Text("“\(block.name)” covers \(block.weekCount) weeks starting from the Plan week. Existing workouts found in that range. Merge keeps them; Overwrite soft-deletes them first.")
        }
        return Text("Apply “\(block.name)” (\(block.weekCount) weeks) starting from the currently viewed Plan week?")
    }
}

struct TemplateDetailView: View {
    let template: StrengthTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel

    @State private var showingEdit = false
    @State private var editName: String = ""
    @State private var editNote: String = ""
    @State private var editExercises: [NewExerciseInput] = []
    @State private var editExerciseName: String = ""
    @State private var editExerciseSetsCount: String = ""
    @State private var editExerciseMinReps: Int = 6
    @State private var editExerciseMaxReps: Int = 10

    var body: some View {
        List {
            Section {
                Label("Strength", systemImage: TemplateCategory.strength.systemImage)
            }
            if let note = template.note, !note.isEmpty {
                Section("Notes") {
                    Text(note)
                }
            }
            ForEach(template.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sets) { set in
                        TemplateSetRow(set: set)
                    }
                }
            }
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
                editExercises: $editExercises,
                editExerciseName: $editExerciseName,
                editExerciseSetsCount: $editExerciseSetsCount,
                editExerciseMinReps: $editExerciseMinReps,
                editExerciseMaxReps: $editExerciseMaxReps,
                isPresented: $showingEdit
            )
        }
    }

    private func beginEditing() {
        editName = template.name
        editNote = template.note ?? ""
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
    @Binding var editExercises: [NewExerciseInput]
    @Binding var editExerciseName: String
    @Binding var editExerciseSetsCount: String
    @Binding var editExerciseMinReps: Int
    @Binding var editExerciseMaxReps: Int
    @Binding var isPresented: Bool

    @State private var liftPickerMode: TemplateLiftPickerMode?

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Info") {
                    TextField("Name", text: $editName)
                    TextField("Note (optional)", text: $editNote, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                StrengthTemplateExerciseEditor(
                    exercises: $editExercises,
                    exerciseName: $editExerciseName,
                    exerciseSetsCount: $editExerciseSetsCount,
                    exerciseMinReps: $editExerciseMinReps,
                    exerciseMaxReps: $editExerciseMaxReps,
                    liftPickerMode: $liftPickerMode
                )
            }
            .navigationTitle("Edit Template")
            .navigationDestination(isPresented: Binding(
                get: { liftPickerMode != nil },
                set: { if !$0 { liftPickerMode = nil } }
            )) {
                let title: String = {
                    if case .replace = liftPickerMode { return "Change Lift" }
                    return "Choose Lift"
                }()
                LiftPickerView(
                    title: title,
                    embedsNavigationStack: false,
                    onSelect: { lift in
                        applyTemplateLiftPick(
                            lift.name,
                            mode: liftPickerMode,
                            exercises: $editExercises,
                            draftName: $editExerciseName
                        )
                    },
                    onSelectCustom: { name in
                        applyTemplateLiftPick(
                            name,
                            mode: liftPickerMode,
                            exercises: $editExercises,
                            draftName: $editExerciseName
                        )
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    if !editExercises.isEmpty {
                        EditButton()
                    }
                    Button("Save", action: save)
                        .disabled(isSaveDisabled)
                }
            }
            .keyboardDoneButton()
        }
    }

    private var isSaveDisabled: Bool {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty || editExercises.isEmpty
    }

    private func save() {
        var updated = template
        updated.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = editNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editNote
        updated.exercises = TemplateLibraryView.exercises(from: editExercises)
        viewModel.updateTemplate(updated)
        isPresented = false
    }
}

struct EnduranceTemplateDetailView: View {
    let template: EnduranceTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel

    @State private var showingEdit = false
    @State private var editName: String = ""
    @State private var editDescription: String = ""
    @State private var editActivityType: ActivityType = .roadRun
    @State private var editRunCategory: RunCategory = .easy
    @State private var editPlannedDistance: String = ""
    @State private var editPlannedDuration: String = ""
    @State private var editPlannedElevation: String = ""
    @State private var editPlannedLevel: String = ""
    @State private var editIntensityRPE: String = ""

    var body: some View {
        List {
            Section {
                Label(template.activityType.rawValue, systemImage: template.activityType.systemImage)
                if let runType = template.runType {
                    Label("Run type: \(runType.rawValue)", systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let distance = template.plannedDistance, !distance.isEmpty {
                Section("Planned distance") { Text(distance) }
            }
            if let duration = template.plannedDuration, !duration.isEmpty {
                Section("Planned duration") { Text(duration) }
            }
            if let elevation = template.plannedElevationGain, !elevation.isEmpty {
                Section(template.activityType == .stairMaster ? "Elevation (ft)" : "Elevation gain") {
                    Text(elevation)
                }
            }
            if let level = template.plannedLevel, !level.isEmpty {
                Section("Level") { Text(level) }
            }
            if let rpe = template.intensityRPE, !rpe.isEmpty {
                Section("Intensity RPE") { Text(rpe) }
            }
            if let description = template.description, !description.isEmpty {
                Section("Description") { Text(description) }
            }
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit", action: beginEditing)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EnduranceTemplateEditSheet(
                template: template,
                viewModel: viewModel,
                editName: $editName,
                editDescription: $editDescription,
                editActivityType: $editActivityType,
                editRunCategory: $editRunCategory,
                editPlannedDistance: $editPlannedDistance,
                editPlannedDuration: $editPlannedDuration,
                editPlannedElevation: $editPlannedElevation,
                editPlannedLevel: $editPlannedLevel,
                editIntensityRPE: $editIntensityRPE,
                isPresented: $showingEdit
            )
        }
    }

    private func beginEditing() {
        editName = template.name
        editDescription = template.description ?? ""
        editActivityType = template.activityType
        editRunCategory = template.runType?.runCategory ?? .easy
        editPlannedDistance = template.plannedDistance ?? ""
        editPlannedDuration = template.plannedDuration ?? ""
        editPlannedElevation = template.plannedElevationGain ?? ""
        editPlannedLevel = template.plannedLevel ?? ""
        editIntensityRPE = template.intensityRPE ?? ""
        showingEdit = true
    }
}

private struct EnduranceTemplateEditSheet: View {
    let template: EnduranceTemplate
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @Binding var editName: String
    @Binding var editDescription: String
    @Binding var editActivityType: ActivityType
    @Binding var editRunCategory: RunCategory
    @Binding var editPlannedDistance: String
    @Binding var editPlannedDuration: String
    @Binding var editPlannedElevation: String
    @Binding var editPlannedLevel: String
    @Binding var editIntensityRPE: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Info") {
                    TextField("Name", text: $editName)
                    TextField("Description (optional)", text: $editDescription, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                Section("Activity") {
                    Picker("Activity type", selection: $editActivityType) {
                        ForEach(ActivityType.enduranceTemplateTypes) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }
                if editActivityType.usesRunType {
                    Section("Run type") {
                        Picker("Run type", selection: $editRunCategory) {
                            ForEach(RunCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                    }
                }
                Section("Planned values") {
                    if editActivityType.usesDistanceMetric {
                        TextField("Distance (mi, optional)", text: $editPlannedDistance)
                    }
                    TextField("Duration (optional)", text: $editPlannedDuration)
                    TextField(
                        editActivityType == .stairMaster
                            ? "Elevation (ft, optional)"
                            : "Elevation gain (optional)",
                        text: $editPlannedElevation
                    )
                    if editActivityType == .stairMaster {
                        TextField("Level 1–20 (optional)", text: $editPlannedLevel)
                            .keyboardType(.numberPad)
                    }
                    TextField("Intensity RPE (optional)", text: $editIntensityRPE)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(editName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .keyboardDoneButton()
        }
    }

    private func save() {
        var updated = template
        updated.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.description = trimmedOrNil(editDescription)
        updated.activityType = editActivityType
        updated.runType = editActivityType.usesRunType ? RunType(runCategory: editRunCategory) : nil
        updated.plannedDistance = editActivityType.usesDistanceMetric ? trimmedOrNil(editPlannedDistance) : nil
        updated.plannedDuration = trimmedOrNil(editPlannedDuration)
        updated.plannedElevationGain = trimmedOrNil(editPlannedElevation)
        updated.plannedLevel = editActivityType == .stairMaster ? trimmedOrNil(editPlannedLevel) : nil
        updated.intensityRPE = trimmedOrNil(editIntensityRPE)
        viewModel.updateEnduranceTemplate(updated)
        isPresented = false
    }
}

private enum TemplateLiftPickerMode: Hashable {
    case add
    case replace(UUID)
}

private func applyTemplateLiftPick(
    _ name: String,
    mode: TemplateLiftPickerMode?,
    exercises: Binding<[NewExerciseInput]>,
    draftName: Binding<String>
) {
    let canonical = LiftCatalog.canonicalName(for: name)
    switch mode {
    case .replace(let id):
        guard let index = exercises.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
        exercises.wrappedValue[index].name = canonical
    case .add, .none:
        draftName.wrappedValue = canonical
    }
}

private struct StrengthTemplateExerciseEditor: View {
    @Binding var exercises: [NewExerciseInput]
    @Binding var exerciseName: String
    @Binding var exerciseSetsCount: String
    @Binding var exerciseMinReps: Int
    @Binding var exerciseMaxReps: Int
    /// Owned by the enclosing NavigationStack (create/edit sheet) so push works.
    @Binding var liftPickerMode: TemplateLiftPickerMode?

    var body: some View {
        Section("Lifts & sets") {
            VStack(alignment: .leading, spacing: 8) {
                // Push into the parent NavigationStack — nested .sheet fails while edit/create is already a sheet.
                // Avoid NavigationLink here: Form + editMode swallows its taps.
                Button {
                    liftPickerMode = .add
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lift")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(exerciseName.isEmpty ? "Choose from catalog" : exerciseName)
                                .foregroundStyle(exerciseName.isEmpty ? .secondary : .primary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

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
                        Button {
                            liftPickerMode = .replace(exercise.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Image(systemName: "pencil.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("\(exercise.setsCount) sets • \(exercise.repRange)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("Catalog") {
                            liftPickerMode = .replace(exercise.id)
                        }
                        .tint(.accentColor)
                    }
                    .contextMenu {
                        Button {
                            liftPickerMode = .replace(exercise.id)
                        } label: {
                            Label("Replace from catalog", systemImage: "list.bullet.rectangle")
                        }
                    }
                }
                .onDelete { offsets in
                    exercises.remove(atOffsets: offsets)
                }
                .onMove(perform: moveExercises)
                Text("Tap a lift to rename from the catalog. Use Edit to delete or reorder.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    private func addExercise() {
        guard let setsCount = Int(exerciseSetsCount), setsCount > 0 else { return }
        let trimmedName = LiftCatalog.canonicalName(for: exerciseName)
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

private func trimmedOrNil(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

