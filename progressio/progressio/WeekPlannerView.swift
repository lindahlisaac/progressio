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
            if !viewModel.unattachedRuns.isEmpty {
                NavigationLink {
                    UnattachedRunsView(runs: viewModel.unattachedRuns)
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

            ForEach(viewModel.weekPlan.days) { day in
                Section(header: Text(dayHeader(for: day.date))) {
                    if day.sessions.isEmpty {
                        Text("No sessions planned").foregroundStyle(.secondary)
                    } else {
                        ForEach(day.sessions) { session in
                            NavigationLink {
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
                                } else {
                                    RunDetailView(
                                        session: session,
                                        onSave: { detail, status in
                                            viewModel.updateRunDetail(sessionID: session.id, detail: detail, status: status)
                                        }
                                    )
                                }
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
        }
        .navigationTitle("This Week")
        .onAppear {
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
                UnattachedRunsView(runs: viewModel.unattachedRuns)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingUnattachedSheet = false }
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
                runs.forEach { viewModel.addUnattachedRun($0) }
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
                .foregroundStyle(session.kind == .strength ? .blue : .purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                if session.kind == .run, let run = session.runDetail {
                    HStack(spacing: 6) {
                        if !run.distance.isEmpty {
                            Text("\(run.distance) mi")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let cat = run.category {
                            Text(cat.rawValue)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(Color.blue)
                                .clipShape(Capsule())
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
                if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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

