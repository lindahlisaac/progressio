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

    var body: some View {
        List {
            unattachedRunsSection
            mileageSection
            daysSection
        }
        .navigationTitle("This Week")
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

    private var mileageSection: some View {
        Section("Run Mileage") {
            HStack {
                Label("Completed", systemImage: "checkmark.circle")
                Spacer()
                Text(String(format: "%.1f mi", completedRunMiles))
                    .bold()
            }
            HStack {
                Label("Planned", systemImage: "figure.run")
                Spacer()
                Text(String(format: "%.1f mi", plannedRunMiles))
                    .bold()
            }
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
                            showsDisclosure: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Menu("Add workout") {
                Button {
                    viewModel.addRun(on: day.date, title: "Planned Run", planned: true)
                } label: {
                    Label("Planned run", systemImage: SessionKind.run.systemImage)
                }
                    Button {
                        viewModel.addCycle(on: day.date, title: "Planned Ride", planned: true)
                    } label: {
                        Label("Planned ride", systemImage: SessionKind.cycle.systemImage)
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
                onSave: { detail, status, actualDistance, actualDuration in
                    viewModel.updateRunDetail(sessionID: session.id, detail: detail, status: status, actualDistance: actualDistance, actualDuration: actualDuration)
                }
            )
        } else {
            RideDetailView(
                session: session,
                onSave: { detail, status, actualDistance, actualDuration in
                    viewModel.updateRunDetail(sessionID: session.id, detail: detail, status: status, actualDistance: actualDistance, actualDuration: actualDuration)
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
        let total = runs.reduce(0.0) { partial, session in
            partial + miles(from: session.runDetail?.distance)
        }
        return total
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
    var showsDisclosure: Bool = false

    private var leadingLabel: String {
        switch session.status {
        case .unplanned:
            return "Mark Planned"
        case .planned:
            return "Mark Complete"
        case .completed:
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
                            Text("Actual")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(Color.green)
                                .clipShape(Capsule())
                        }
                        if let planned = session.runDetail, !planned.distance.isEmpty {
                            Text("Planned \(planned.distance) mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let planned = session.runDetail {
                        HStack(spacing: 6) {
                            if !planned.distance.isEmpty {
                                Text("\(planned.distance) mi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if session.kind == .run {
                                if let cat = planned.category {
                                    Text(cat.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.12))
                                        .foregroundStyle(Color.blue)
                                        .clipShape(Capsule())
                                }
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
                        Text(note)
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
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(leadingLabel, systemImage: session.status == .completed ? "arrow.uturn.left" : "checkmark.circle")
            }
            .tint(session.status == .completed ? .blue : .green)
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

