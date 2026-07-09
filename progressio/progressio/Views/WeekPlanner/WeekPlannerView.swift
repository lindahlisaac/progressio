import SwiftUI
import HealthKit

struct WeekPlannerView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @ObservedObject var templatesViewModel: TemplateLibraryViewModel
    @State private var showingTemplatePicker = false
    @State private var templatePickerDate: Date?
    @State private var hasStartedHKObserver = false
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

    var body: some View {
        List {
            unattachedRunsSection
            weeklyReportSection
            daysSection
        }
        .navigationTitle("This Week")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    viewModel.goToPreviousWeek(templates: templatesViewModel.activeTemplates)
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingWeeklyTemplatePicker = true
                    } label: {
                        Label("Apply Weekly Template", systemImage: "rectangle.stack.badge.plus")
                    }
                    .disabled(viewModel.activeWeeklyTemplates.isEmpty)

                    Button {
                        saveTemplateName = ""
                        saveTemplateNote = ""
                        showingSaveWeekAsTemplate = true
                    } label: {
                        Label("Save Week as Template", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!viewModel.hasWorkoutsInCurrentWeek())
                } label: {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityLabel("Weekly templates")

                Button {
                    viewModel.goToNextWeek(templates: templatesViewModel.activeTemplates)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .onAppear {
            viewModel.dedupeUnattachedRuns()
            startHealthKitObserverIfNeeded()
        }
        .onChange(of: viewModel.activeUnattachedRuns.count) { newCount in
            if newCount > previousUnattachedCount {
                showingUnattachedSheet = true
            }
            previousUnattachedCount = newCount
        }
        .sheet(isPresented: $showingTemplatePicker) {
            NavigationStack {
                List {
                    if !templatesViewModel.activeTemplates.isEmpty {
                        Section("Strength") {
                            ForEach(templatesViewModel.activeTemplates) { template in
                                Button {
                                    if let date = templatePickerDate {
                                        viewModel.addTemplateSession(template: template, on: date)
                                    }
                                    showingTemplatePicker = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.body.weight(.semibold))
                                        if let note = template.note {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !templatesViewModel.activeEnduranceTemplates.isEmpty {
                        Section("Endurance") {
                            ForEach(templatesViewModel.activeEnduranceTemplates) { template in
                                Button {
                                    if let date = templatePickerDate {
                                        viewModel.addEnduranceSession(template: template, on: date)
                                    }
                                    showingTemplatePicker = false
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.body.weight(.semibold))
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
                }
                .navigationTitle("Select template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingTemplatePicker = false
                        }
                    }
                }
            }
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

    private var weeklyReportSection: some View {
        NavigationLink {
            WeeklyReportView(
                plannedRunMiles: plannedRunMiles,
                completedRunMiles: completedRunMiles,
                plannedRideMiles: plannedRideMiles,
                completedRideMiles: completedRideMiles,
                plannedStrengthCount: plannedStrengthCount,
                completedStrengthCount: completedStrengthCount
            )
        } label: {
            HStack {
                Label("Weekly report", systemImage: "chart.bar.doc.horizontal")
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "Run %.1f/%.1f mi", completedRunMiles, plannedRunMiles))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "Ride %.1f/%.1f mi", completedRideMiles, plannedRideMiles))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Strength \(completedStrengthCount)/\(plannedStrengthCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
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
                                skipNote = workout.displayNote ?? ""
                                showingSkipSheet = true
                            },
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Menu("Add workout") {
                Button {
                    viewModel.addRun(on: day.date, title: "Run", planned: true)
                } label: {
                    Label("Run", systemImage: SessionKind.run.systemImage)
                }
                Button {
                    viewModel.addCycle(on: day.date, title: "Ride", planned: true)
                } label: {
                    Label("Ride", systemImage: SessionKind.cycle.systemImage)
                }
                Button {
                    viewModel.addStrengthSession(on: day.date, title: "Strength")
                } label: {
                    Label("Strength", systemImage: SessionKind.strength.systemImage)
                }
                Button {
                    viewModel.addRun(on: day.date, title: "Detected run", planned: false)
                } label: {
                    Label("Attach detected run", systemImage: "bolt.heart")
                }
                Button {
                    templatePickerDate = day.date
                    showingTemplatePicker = true
                } label: {
                    Label("Add from template", systemImage: "doc.on.doc")
                }
            }
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
                onCompleteStatus: {
                    viewModel.setWorkoutStatus(workoutID: workout.id, status: .completed)
                },
                onUnlockStatus: {
                    viewModel.setWorkoutStatus(workoutID: workout.id, status: .planned)
                },
                onCompletedSnapshotPersist: { snapshot in
                    viewModel.updateCompletedStrengthSnapshot(workoutID: workout.id, snapshot: snapshot)
                }
            )
        } else if workout.activityType.sessionKind == .run {
            RunDetailView(
                workout: workout,
                onSave: { title, category, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation in
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
                        actualElevation: actualElevation
                    )
                }
            )
        } else {
            RideDetailView(
                workout: workout,
                onSave: { title, _, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation in
                    viewModel.updateEnduranceWorkout(
                        workoutID: workout.id,
                        title: title,
                        runType: workout.runType,
                        plannedDistance: plannedDistance,
                        plannedDuration: plannedDuration,
                        plannedElevation: plannedElevation,
                        status: status,
                        actualDistance: actualDistance,
                        actualDuration: actualDuration,
                        actualElevation: actualElevation
                    )
                }
            )
        }
    }

    private func dayHeader(for date: Date) -> String {
        let dayString = dayFormatter.string(from: date)
        let short = shortDayFormatter.string(from: date)
        return "\(short) • \(dayString)"
    }

    private var plannedRunMiles: Double {
        let workouts = viewModel.weekPlan.days.flatMap { $0.activeWorkouts }
        let runs = workouts.filter { $0.activityType.sessionKind == .run }
        return runs.reduce(0.0) { partial, workout in
            partial + miles(from: workout.plannedDistance)
        }
    }

    private var completedRunMiles: Double {
        let workouts = viewModel.weekPlan.days.flatMap { $0.activeWorkouts }
        let runs = workouts.filter { $0.activityType.sessionKind == .run && ($0.status == .completed || $0.status == .partiallyCompleted) }
        return runs.reduce(0.0) { partial, workout in
            let distance = workout.actualDistance.isEmpty ? workout.plannedDistance : workout.actualDistance
            return partial + miles(from: distance)
        }
    }

    private var plannedRideMiles: Double {
        let workouts = viewModel.weekPlan.days.flatMap { $0.activeWorkouts }
        let rides = workouts.filter { $0.activityType == .bike }
        return rides.reduce(0.0) { partial, workout in
            partial + miles(from: workout.plannedDistance)
        }
    }

    private var completedRideMiles: Double {
        let workouts = viewModel.weekPlan.days.flatMap { $0.activeWorkouts }
        let rides = workouts.filter { $0.activityType == .bike && ($0.status == .completed || $0.status == .partiallyCompleted) }
        return rides.reduce(0.0) { partial, workout in
            let distance = workout.actualDistance.isEmpty ? workout.plannedDistance : workout.actualDistance
            return partial + miles(from: distance)
        }
    }

    private var plannedStrengthCount: Int {
        viewModel.weekPlan.days.flatMap { $0.activeWorkouts }.filter { $0.activityType == .strength }.count
    }

    private var completedStrengthCount: Int {
        var count = 0
        for workout in viewModel.weekPlan.days.flatMap({ $0.activeWorkouts }) {
            if workout.activityType == .strength,
               workout.status == .completed || workout.status == .partiallyCompleted {
                count += 1
            }
        }
        return count
    }

    private func miles(from distanceString: String) -> Double {
        guard !distanceString.isEmpty else { return 0 }
        let filtered = distanceString.filter { "0123456789.".contains($0) }
        return Double(filtered) ?? 0
    }

    private func startHealthKitObserverIfNeeded() {
        guard !hasStartedHKObserver, HKHealthStore.isHealthDataAvailable() else { return }
        hasStartedHKObserver = true
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        HealthKitManager.shared.startObservingRuns {
            HealthKitManager.shared.fetchRecentRuns(since: threeDaysAgo) { runs in
                viewModel.importUnattachedRuns(runs)
            }
        }
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
            Image(systemName: workout.sessionKind.systemImage)
                .foregroundStyle(color(for: workout.sessionKind))

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.title)
                    .font(.headline)
                enduranceSummary
                strengthSummary
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(workout.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(workout.status.tint.opacity(0.15))
                    .foregroundStyle(workout.status.tint)
                    .clipShape(Capsule())
            }
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
        if workout.activityType.sessionKind == .run, let cat = workout.runType?.runCategory {
            chip(text: cat.rawValue, color: .blue)
        } else if workout.activityType == .bike {
            chip(text: "Ride", color: .orange)
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
            if let note = workout.displayNote {
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
