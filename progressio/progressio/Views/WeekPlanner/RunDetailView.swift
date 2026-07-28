import SwiftUI

struct RunDetailView: View {
    let workout: Workout
    /// title, activityType, runCategory, plannedDistance, plannedDuration, plannedElevation, status, actualDistance, actualDuration, actualElevation, timePeriod, notes
    var onSave: ((String, ActivityType, RunCategory?, String, String, String, WorkoutStatus, String?, String?, String?, TimePeriod, String) -> Void)?

    @State private var title: String
    @State private var activityType: ActivityType
    @State private var distance: String
    @State private var actualDistance: String
    @State private var plannedElevation: String
    @State private var actualElevation: String
    @FocusState private var focusedField: Field?
    @State private var plannedHours: Int
    @State private var plannedMinutes: Int
    @State private var plannedSeconds: Int
    @State private var actualHours: Int
    @State private var actualMinutes: Int
    @State private var actualSeconds: Int
    @State private var effortUnit: EffortUnit
    @State private var isCompleted: Bool
    @State private var category: RunCategory = .easy
    @State private var timePeriod: TimePeriod
    @State private var notes: String
    @Environment(\.dismiss) private var dismiss

    private static let runActivityTypes: [ActivityType] = [.roadRun, .trailRun, .walk]

    init(
        workout: Workout,
        onSave: ((String, ActivityType, RunCategory?, String, String, String, WorkoutStatus, String?, String?, String?, TimePeriod, String) -> Void)? = nil
    ) {
        self.workout = workout
        self.onSave = onSave
        let initialActivity = Self.runActivityTypes.contains(workout.activityType) ? workout.activityType : .roadRun
        _activityType = State(initialValue: initialActivity)
        _title = State(initialValue: workout.title.isEmpty ? initialActivity.defaultTitle : workout.title)
        _distance = State(initialValue: workout.plannedDistance)
        _actualDistance = State(initialValue: workout.actualDistance)
        _plannedElevation = State(initialValue: workout.plannedElevation)
        _actualElevation = State(initialValue: workout.actualElevation)
        let (ph, pm, ps) = RunDetailView.split(duration: workout.plannedDuration)
        _plannedHours = State(initialValue: ph)
        _plannedMinutes = State(initialValue: pm)
        _plannedSeconds = State(initialValue: ps)
        let (ah, am, as_) = RunDetailView.split(duration: workout.actualDuration)
        _actualHours = State(initialValue: ah)
        _actualMinutes = State(initialValue: am)
        _actualSeconds = State(initialValue: as_)
        _effortUnit = State(initialValue: Self.effortUnit(for: ActivityMetricPreferenceStore.shared.primaryMetric(for: initialActivity)))
        _isCompleted = State(initialValue: workout.status == .completed || workout.status == .partiallyCompleted)
        _category = State(initialValue: workout.runType?.runCategory ?? .easy)
        _timePeriod = State(initialValue: workout.timePeriod)
        _notes = State(initialValue: workout.notes ?? "")
    }

    var body: some View {
        Form {
            if workout.status == .skipped, let note = workout.skipReason, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section("Skip note") {
                    Text(note)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Planned") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session title")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(activityType.defaultTitle, text: $title)
                        .focused($focusedField, equals: .title)
                }
                Picker("Activity", selection: $activityType) {
                    ForEach(Self.runActivityTypes) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .onChange(of: activityType) { newType in
                    // Keep title in sync when it still matches a default modality label.
                    let defaults = Set(Self.runActivityTypes.map(\.defaultTitle))
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || defaults.contains(title) {
                        title = newType.defaultTitle
                    }
                }
                Picker("Time of day", selection: $timePeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Effort unit", selection: $effortUnit) {
                    ForEach(EffortUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Training type", selection: $category) {
                    ForEach(RunCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }

                if effortUnit == .miles {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Planned mileage (mi)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Planned mileage (mi)", text: $distance)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .plannedMiles)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Planned duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        durationPickers(hours: $plannedHours, minutes: $plannedMinutes, seconds: $plannedSeconds)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planned elevation gain (ft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Planned elevation gain", text: $plannedElevation)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .plannedElevation)
                }
            }

            Section("Actual") {
                if effortUnit == .miles {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actual mileage (mi)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Actual mileage (mi)", text: $actualDistance)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .actualMiles)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actual duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        durationPickers(hours: $actualHours, minutes: $actualMinutes, seconds: $actualSeconds)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actual elevation gain (ft)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Actual elevation gain", text: $actualElevation)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .actualElevation)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
                    .focused($focusedField, equals: .notes)
            }

            Section {
                Toggle("Mark complete", isOn: $isCompleted)
            }
        }
        .navigationTitle("\(activityType.rawValue) Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save(statusOverride: nil, dismissAfter: true)
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onChange(of: isCompleted) { _ in
            save(statusOverride: isCompleted ? .completed : .planned, dismissAfter: false)
        }
        .onAppear {
            if ActivityMetricPreferenceStore.shared.primaryMetric(for: activityType) == .elevation {
                focusedField = isCompleted ? .actualElevation : .plannedElevation
            }
        }
    }

    private static func effortUnit(for metric: PrimaryMetric) -> EffortUnit {
        switch metric {
        case .duration: return .time
        case .distance, .elevation, .level: return .miles
        }
    }

    private func durationPickers(hours: Binding<Int>, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
        HStack {
            Picker("Hours", selection: hours) {
                ForEach(0...500, id: \.self) { Text("\($0)h").tag($0) }
            }
            Picker("Minutes", selection: minutes) {
                ForEach(0..<60) { Text("\($0)m").tag($0) }
            }
            Picker("Seconds", selection: seconds) {
                ForEach(0..<60) { Text("\($0)s").tag($0) }
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 140)
    }

    private static func split(duration: String) -> (Int, Int, Int) {
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        let h = parts.count > 0 ? parts[0] : 0
        let m = parts.count > 1 ? parts[1] : 0
        let s = parts.count > 2 ? parts[2] : 0
        return (h, m, s)
    }

    private static func durationString(h: Int, m: Int, s: Int) -> String {
        String(format: "%02d:%02d:%02d", h, m, s)
    }

    private enum EffortUnit: String, CaseIterable, Identifiable {
        case miles
        case time
        var id: String { rawValue }
        var label: String {
            switch self {
            case .miles: return "Miles"
            case .time: return "Time"
            }
        }
    }

    private enum Field {
        case title
        case plannedMiles
        case actualMiles
        case plannedElevation
        case actualElevation
        case notes
    }

    private func save(statusOverride: WorkoutStatus?, dismissAfter: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle = trimmedTitle.isEmpty ? activityType.defaultTitle : trimmedTitle

        let plannedDistance: String
        let plannedDuration: String
        if effortUnit == .miles {
            plannedDistance = distance
            plannedDuration = ""
        } else {
            plannedDistance = ""
            plannedDuration = RunDetailView.durationString(h: plannedHours, m: plannedMinutes, s: plannedSeconds)
        }

        let actualDistanceClean = actualDistance.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualDurationString = RunDetailView.durationString(h: actualHours, m: actualMinutes, s: actualSeconds)
        let actualDistanceValue: String? = effortUnit == .miles ? (actualDistanceClean.isEmpty ? nil : actualDistanceClean) : nil
        let actualDurationValue: String? = effortUnit == .time ? actualDurationString : nil
        let actualElevationClean = actualElevation.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualElevationValue: String? = actualElevationClean.isEmpty ? nil : actualElevationClean

        let status = statusOverride ?? (isCompleted ? WorkoutStatus.completed : .planned)
        onSave?(
            effectiveTitle,
            activityType,
            category,
            plannedDistance,
            plannedDuration,
            plannedElevation,
            status,
            actualDistanceValue,
            actualDurationValue,
            actualElevationValue,
            timePeriod,
            notes
        )
        if dismissAfter {
            dismiss()
        }
    }
}
