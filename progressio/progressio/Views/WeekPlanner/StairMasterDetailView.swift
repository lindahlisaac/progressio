import SwiftUI

/// StairMaster detail: time, elevation (ft), and machine level 1–20 — not miles-first.
struct StairMasterDetailView: View {
    let workout: Workout
    /// title, plannedDuration, plannedElevation, plannedLevel, status, actualDuration, actualElevation, actualLevel, timePeriod, notes
    var onSave: ((String, String, String, String, WorkoutStatus, String?, String?, String?, TimePeriod, String) -> Void)?

    @State private var title: String
    @State private var plannedElevation: String
    @State private var actualElevation: String
    @State private var plannedLevel: Int
    @State private var actualLevel: Int
    @State private var plannedHours: Int
    @State private var plannedMinutes: Int
    @State private var plannedSeconds: Int
    @State private var actualHours: Int
    @State private var actualMinutes: Int
    @State private var actualSeconds: Int
    @State private var isCompleted: Bool
    @State private var timePeriod: TimePeriod
    @State private var notes: String
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    private static let levelRange = Array(1...20)

    init(
        workout: Workout,
        onSave: ((String, String, String, String, WorkoutStatus, String?, String?, String?, TimePeriod, String) -> Void)? = nil
    ) {
        self.workout = workout
        self.onSave = onSave
        _title = State(initialValue: workout.title.isEmpty ? ActivityType.stairMaster.defaultTitle : workout.title)
        _plannedElevation = State(initialValue: workout.plannedElevation)
        _actualElevation = State(initialValue: workout.actualElevation)
        _plannedLevel = State(initialValue: Self.parseLevel(workout.plannedLevel) ?? 10)
        _actualLevel = State(initialValue: Self.parseLevel(workout.actualLevel) ?? Self.parseLevel(workout.plannedLevel) ?? 10)
        let (ph, pm, ps) = Self.split(duration: workout.plannedDuration)
        _plannedHours = State(initialValue: ph)
        _plannedMinutes = State(initialValue: pm)
        _plannedSeconds = State(initialValue: ps)
        let (ah, am, as_) = Self.split(duration: workout.actualDuration)
        _actualHours = State(initialValue: ah)
        _actualMinutes = State(initialValue: am)
        _actualSeconds = State(initialValue: as_)
        _isCompleted = State(initialValue: workout.status == .completed || workout.status == .partiallyCompleted)
        _timePeriod = State(initialValue: workout.timePeriod)
        _notes = State(initialValue: workout.notes ?? "")
    }

    var body: some View {
        Form {
            if workout.status == .skipped, let note = workout.skipReason,
               !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Skip note") {
                    Text(note).foregroundStyle(.secondary)
                }
            }
            Section("Planned") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("StairMaster", text: $title)
                        .focused($focusedField, equals: .title)
                }
                Picker("Time of day", selection: $timePeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planned duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    durationPickers(hours: $plannedHours, minutes: $plannedMinutes, seconds: $plannedSeconds)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planned elevation (ft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Feet climbed", text: $plannedElevation)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .plannedElevation)
                }
                Picker("Planned level (1–20)", selection: $plannedLevel) {
                    ForEach(Self.levelRange, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
            }

            Section("Actual") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    durationPickers(hours: $actualHours, minutes: $actualMinutes, seconds: $actualSeconds)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual elevation (ft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Feet climbed", text: $actualElevation)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .actualElevation)
                }
                Picker("Actual level (1–20)", selection: $actualLevel) {
                    ForEach(Self.levelRange, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                Toggle("Mark completed", isOn: $isCompleted)
            }

            Section("Notes") {
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                    .focused($focusedField, equals: .notes)
            }
        }
        .navigationTitle("StairMaster")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            switch ActivityMetricPreferenceStore.shared.primaryMetric(for: .stairMaster) {
            case .elevation:
                focusedField = isCompleted ? .actualElevation : .plannedElevation
            case .duration, .distance, .level:
                break
            }
        }
    }

    private func durationPickers(hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
        HStack {
            Picker("Hours", selection: hours) {
                ForEach(0..<10, id: \.self) { Text("\($0)h").tag($0) }
            }
            .labelsHidden()
            Picker("Minutes", selection: minutes) {
                ForEach(0..<60, id: \.self) { Text("\($0)m").tag($0) }
            }
            .labelsHidden()
            Picker("Seconds", selection: seconds) {
                ForEach(0..<60, id: \.self) { Text("\($0)s").tag($0) }
            }
            .labelsHidden()
        }
    }

    private func save() {
        let plannedDuration = Self.durationString(h: plannedHours, m: plannedMinutes, s: plannedSeconds)
        let actualDuration = Self.durationString(h: actualHours, m: actualMinutes, s: actualSeconds)
        let status: WorkoutStatus = isCompleted ? .completed : .planned
        let hadActual = !workout.actualDuration.isEmpty || !workout.actualElevation.isEmpty || !workout.actualLevel.isEmpty
        let actualDurationValue: String? = isCompleted || hadActual ? actualDuration : nil
        let actualElevationValue: String? = isCompleted || hadActual ? actualElevation : nil
        let actualLevelValue: String? = isCompleted || hadActual ? String(actualLevel) : nil

        onSave?(
            title,
            plannedDuration,
            plannedElevation,
            String(plannedLevel),
            status,
            actualDurationValue,
            actualElevationValue,
            actualLevelValue,
            timePeriod,
            notes
        )
        dismiss()
    }

    private enum Field: Hashable {
        case title, plannedElevation, actualElevation, notes
    }

    private static func parseLevel(_ raw: String) -> Int? {
        let filtered = raw.filter(\.isNumber)
        guard let value = Int(filtered), (1...20).contains(value) else { return nil }
        return value
    }

    private static func split(duration: String) -> (Int, Int, Int) {
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        if parts.count == 3 { return (parts[0], parts[1], parts[2]) }
        if parts.count == 2 { return (0, parts[0], parts[1]) }
        return (0, 0, 0)
    }

    private static func durationString(h: Int, m: Int, s: Int) -> String {
        String(format: "%02d:%02d:%02d", h, m, s)
    }
}
