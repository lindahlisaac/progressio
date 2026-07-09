import SwiftUI

struct RideDetailView: View {
    let workout: Workout
    var onSave: ((String, RunCategory?, String, String, String, WorkoutStatus, String?, String?, String?) -> Void)?

    @State private var title: String
    @State private var plannedMiles: String
    @State private var actualMiles: String
    @State private var plannedElevation: String
    @State private var actualElevation: String
    @State private var plannedHours: Int
    @State private var plannedMinutes: Int
    @State private var plannedSeconds: Int
    @State private var actualHours: Int
    @State private var actualMinutes: Int
    @State private var actualSeconds: Int
    @State private var effortUnit: EffortUnit
    @State private var isCompleted: Bool
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    init(
        workout: Workout,
        onSave: ((String, RunCategory?, String, String, String, WorkoutStatus, String?, String?, String?) -> Void)? = nil
    ) {
        self.workout = workout
        self.onSave = onSave
        _title = State(initialValue: workout.title.isEmpty ? "Ride" : workout.title)
        _plannedMiles = State(initialValue: workout.plannedDistance)
        _actualMiles = State(initialValue: workout.actualDistance)
        _plannedElevation = State(initialValue: workout.plannedElevation)
        _actualElevation = State(initialValue: workout.actualElevation)
        let (ph, pm, ps) = RideDetailView.split(duration: workout.plannedDuration)
        _plannedHours = State(initialValue: ph)
        _plannedMinutes = State(initialValue: pm)
        _plannedSeconds = State(initialValue: ps)
        let (ah, am, as_) = RideDetailView.split(duration: workout.actualDuration)
        _actualHours = State(initialValue: ah)
        _actualMinutes = State(initialValue: am)
        _actualSeconds = State(initialValue: as_)
        _effortUnit = State(initialValue: .miles)
        _isCompleted = State(initialValue: workout.status == .completed || workout.status == .partiallyCompleted)
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
                    TextField("Ride", text: $title)
                        .focused($focusedField, equals: .title)
                }
                Picker("Effort unit", selection: $effortUnit) {
                    ForEach(EffortUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                if effortUnit == .miles {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Planned mileage (mi)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Planned mileage (mi)", text: $plannedMiles)
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
                        TextField("Actual mileage (mi)", text: $actualMiles)
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

            Section {
                Toggle("Mark complete", isOn: $isCompleted)
            }
        }
        .navigationTitle("Ride Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save(statusOverride: nil, dismissAfter: true)
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
    }

    private func save(statusOverride: WorkoutStatus?, dismissAfter: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle = trimmedTitle.isEmpty ? "Ride" : trimmedTitle

        let plannedDistance: String
        let plannedDuration: String
        if effortUnit == .miles {
            plannedDistance = plannedMiles
            plannedDuration = ""
        } else {
            plannedDistance = ""
            plannedDuration = RideDetailView.durationString(h: plannedHours, m: plannedMinutes, s: plannedSeconds)
        }

        let actualDistanceClean = actualMiles.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualDurationString = RideDetailView.durationString(h: actualHours, m: actualMinutes, s: actualSeconds)
        let actualDistanceValue: String? = effortUnit == .miles ? (actualDistanceClean.isEmpty ? nil : actualDistanceClean) : nil
        let actualDurationValue: String? = effortUnit == .time ? actualDurationString : nil
        let actualElevationClean = actualElevation.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualElevationValue: String? = actualElevationClean.isEmpty ? nil : actualElevationClean

        let status = statusOverride ?? (isCompleted ? WorkoutStatus.completed : .planned)
        onSave?(
            effectiveTitle,
            nil,
            plannedDistance,
            plannedDuration,
            plannedElevation,
            status,
            actualDistanceValue,
            actualDurationValue,
            actualElevationValue
        )
        if dismissAfter {
            dismiss()
        }
    }
}
