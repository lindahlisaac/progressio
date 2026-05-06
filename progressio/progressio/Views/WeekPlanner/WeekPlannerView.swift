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
                    viewModel.goToPreviousWeek(templates: templatesViewModel.templates)
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingWeeklyTemplatePicker = true
                } label: {
                    Image(systemName: "calendar.badge.plus")
                }
                .disabled(viewModel.weeklyTemplates.isEmpty)
                
                Button {
                    viewModel.goToNextWeek(templates: templatesViewModel.templates)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .onAppear {
            viewModel.dedupeUnattachedRuns()
            startHealthKitObserverIfNeeded()
        }
        .onChange(of: viewModel.unattachedRuns.count) { newCount in
            if newCount > previousUnattachedCount {
                showingUnattachedSheet = true
            }
            previousUnattachedCount = newCount
        }
        .sheet(isPresented: $showingTemplatePicker) {
            NavigationStack {
                List {
                    ForEach(templatesViewModel.templates) { template in
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
                    runs: viewModel.unattachedRuns,
                    days: viewModel.weekPlan.days,
                    onAttach: { date, run, sessionID in
                        viewModel.attachActualRun(to: date, run: run, toSessionID: sessionID)
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
                    ForEach(viewModel.weeklyTemplates) { template in
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
                                Text("\(template.days.flatMap { $0.sessions }.count) workouts")
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
                                viewModel.setSessionStatus(sessionID: id, status: .skipped, note: skipNote)
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
            if !viewModel.unattachedRuns.isEmpty {
                NavigationLink {
                    UnattachedRunsView(
                        runs: viewModel.unattachedRuns,
                        days: viewModel.weekPlan.days,
                        onAttach: { date, run, sessionID in
                            viewModel.attachActualRun(to: date, run: run, toSessionID: sessionID)
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
                            Text("\(viewModel.unattachedRuns.count)")
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
            if day.sessions.isEmpty {
                Text("No sessions planned")
                    .foregroundStyle(.secondary)
            } else {
                let sessions = day.sessions
                ForEach(sessions) { session in
                    NavigationLink {
                        sessionDestination(session)
                    } label: {
                        SessionRow(
                            session: session,
                            onToggle: { viewModel.toggleStatus(sessionID: session.id) },
                            onDelete: { viewModel.removeSession(dayID: day.id, sessionID: session.id) },
                            onSkip: {
                                skipSessionID = session.id
                                skipNote = session.note ?? ""
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
    private func sessionDestination(_ session: PlannedSession) -> some View {
        if session.kind == .strength {
            StrengthLogView(
                session: session,
                template: templatesViewModel.templates.first(where: { $0.name == session.templateName }),
                onNoteChange: { note in
                    viewModel.setSessionNote(sessionID: session.id, note: note)
                },
                onCompleteStatus: {
                    viewModel.setSessionStatus(sessionID: session.id, status: .completed)
                },
                onUnlockStatus: {
                    viewModel.setSessionStatus(sessionID: session.id, status: .planned)
                }
            )
        } else if session.kind == .run {
            RunDetailView(
                session: session,
                onSave: { detail, status, actualDistance, actualDuration, actualElevation in
                    viewModel.updateRunDetail(sessionID: session.id, detail: detail, status: status, actualDistance: actualDistance, actualDuration: actualDuration, actualElevation: actualElevation)
                }
            )
        } else {
            RideDetailView(
                session: session,
                onSave: { detail, status, actualDistance, actualDuration, actualElevation in
                    viewModel.updateRunDetail(sessionID: session.id, detail: detail, status: status, actualDistance: actualDistance, actualDuration: actualDuration, actualElevation: actualElevation)
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
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        let runs = sessions.filter { $0.kind == .run }
        let total = runs.reduce(0.0) { partial, session in
            partial + miles(from: session.runDetail?.distance)
        }
        return total
    }

    private var completedRunMiles: Double {
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        let runs = sessions.filter { $0.kind == .run && $0.status == .completed }
        return runs.reduce(0.0) { partial, session in
            partial + miles(from: session.actualRun?.distance ?? session.runDetail?.distance)
        }
    }

    private var plannedRideMiles: Double {
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        let rides = sessions.filter { $0.kind == .cycle }
        return rides.reduce(0.0) { partial, session in
            partial + miles(from: session.runDetail?.distance)
        }
    }

    private var completedRideMiles: Double {
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        let rides = sessions.filter { $0.kind == .cycle && $0.status == .completed }
        return rides.reduce(0.0) { partial, session in
            partial + miles(from: session.actualRun?.distance ?? session.runDetail?.distance)
        }
    }

    private var plannedStrengthCount: Int {
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        return sessions.filter { $0.kind == .strength }.count
    }

    private var completedStrengthCount: Int {
        let sessions = viewModel.weekPlan.days.flatMap { $0.sessions }
        return sessions.filter { $0.kind == .strength && $0.status == .completed }.count
    }

    private func miles(from distanceString: String?) -> Double {
        guard let s = distanceString else { return 0 }
        let filtered = s.filter { "0123456789.".contains($0) }
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

struct SessionRow: View {
    let session: PlannedSession
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onSkip: () -> Void
    var showsDisclosure: Bool = false

    private var leadingLabel: String {
        switch session.status {
        case .unplanned:
            return "Mark Planned"
        case .planned:
            return "Mark Complete"
        case .completed:
            return "Mark Planned"
        case .skipped:
            return "Mark Planned"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.kind.systemImage)
                .foregroundStyle(color(for: session.kind))

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                if session.kind == .run || session.kind == .cycle {
                    if let actual = session.actualRun {
                        HStack(spacing: 6) {
                            if !actual.distance.isEmpty {
                                Text("Actual \(actual.distance) mi")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        if let planned = session.runDetail, !planned.distance.isEmpty {
                            Text("Planned \(planned.distance) mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if session.kind == .run, let cat = session.runDetail?.category ?? session.actualRun?.category {
                            chip(text: cat.rawValue, color: .blue)
                        } else if session.kind == .cycle {
                            chip(text: "Ride", color: .orange)
                        }
                    } else if let planned = session.runDetail {
                        HStack(spacing: 6) {
                            if !planned.distance.isEmpty {
                                Text("\(planned.distance) mi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if session.kind == .run, let cat = planned.category {
                                chip(text: cat.rawValue, color: .blue)
                            } else if session.kind == .cycle {
                                chip(text: "Ride", color: .orange)
                            }
                        }
                    }
                } else {
                    if let template = session.templateName {
                        Text(template)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let note = session.note {
                        Text(truncated(note, limit: 60))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(session.status.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(session.status.tint.opacity(0.15))
                    .foregroundStyle(session.status.tint)
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
                Label(leadingLabel, systemImage: session.status == .completed ? "arrow.uturn.left" : "checkmark.circle")
            }
            .tint(session.status == .completed ? .blue : .green)
            Button {
                onSkip()
            } label: {
                Label("Skip", systemImage: "slash.circle")
            }
            .tint(.gray)
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
