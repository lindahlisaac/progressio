import SwiftUI

struct UnattachedRunsView: View {
    let runs: [UnattachedRun]
    var days: [DayPlan]
    var onAttach: (Date, UnattachedRun, UUID?) -> Void

    var body: some View {
        List {
            if runs.isEmpty {
                Text("No unattached runs detected.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runs) { run in
                    UnattachedRunRow(run: run, days: days, onAttach: onAttach)
                }
            }
        }
        .navigationTitle("Unattached Runs")
    }
}

private struct UnattachedRunRow: View {
    let run: UnattachedRun
    var days: [DayPlan]
    var onAttach: (Date, UnattachedRun, UUID?) -> Void
    @State private var selectedDate: Date?
    @State private var showDayPicker = false
    @State private var showSessionPicker = false
    @State private var sessionsForDay: [Workout] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(run.detail.title.isEmpty ? "Run" : run.detail.title)
                .font(.headline)
            HStack(spacing: 12) {
                if !run.detail.distance.isEmpty {
                    Text("\(run.detail.distance) mi")
                        .font(.subheadline)
                }
                if !run.detail.duration.isEmpty {
                    Text(run.detail.duration)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let cat = run.detail.category {
                    Text(cat.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(cat.tint.opacity(0.12))
                        .foregroundStyle(cat.tint)
                        .clipShape(Capsule())
                }
            }
            Text(dateFormatter.string(from: run.date))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let src = run.source {
                Text(src)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button {
                showDayPicker = true
            } label: {
                Label("Attach to week", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.bordered)
            .padding(.top, 6)
            .sheet(isPresented: $showDayPicker) {
                NavigationStack {
                    List {
                        ForEach(days) { day in
                            Button {
                                selectedDate = day.date
                                showDayPicker = false
                                if let date = selectedDate {
                                    let workouts = day.activeWorkouts.filter {
                                        $0.activityType == run.activityType
                                            || (run.activityType.sessionKind == .run && $0.activityType.sessionKind == .run)
                                    }
                                    sessionsForDay = workouts
                                    if workouts.isEmpty {
                                        onAttach(date, run, nil)
                                    } else {
                                        showSessionPicker = true
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(dayFormatter.string(from: day.date))
                                    Spacer()
                                    Text(shortDayFormatter.string(from: day.date))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Choose a day")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showDayPicker = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSessionPicker) {
                NavigationStack {
                    List {
                        Section("Attach to planned run") {
                            ForEach(sessionsForDay) { workout in
                                Button {
                                    if let date = selectedDate {
                                        onAttach(date, run, workout.id)
                                    }
                                    showSessionPicker = false
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(workout.title)
                                            .font(.body.weight(.semibold))
                                        if !workout.plannedDistance.isEmpty {
                                            Text("Planned \(workout.plannedDistance) mi")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        Section {
                            Button {
                                if let date = selectedDate {
                                    onAttach(date, run, nil)
                                }
                                showSessionPicker = false
                            } label: {
                                Label("Add as new run", systemImage: "plus.circle")
                            }
                        }
                    }
                    .navigationTitle("Select run")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showSessionPicker = false }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
}()

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

