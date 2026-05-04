import SwiftUI

struct RunDetailView: View {
    let session: PlannedSession
    var onSave: ((RunDetailData, PlanStatus, String?, String?, String?) -> Void)?

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
    @Environment(\.dismiss) private var dismiss

    init(session: PlannedSession, onSave: ((RunDetailData, PlanStatus, String?, String?, String?) -> Void)? = nil) {
        self.session = session
        self.onSave = onSave
        let detail = session.runDetail
        _distance = State(initialValue: detail?.distance ?? "")
        _actualDistance = State(initialValue: session.actualRun?.distance ?? "")
        _plannedElevation = State(initialValue: detail?.elevationGain ?? "")
        _actualElevation = State(initialValue: session.actualRun?.elevationGain ?? "")
        let plannedDuration = detail?.duration ?? ""
        let (ph, pm, ps) = RunDetailView.split(duration: plannedDuration)
        _plannedHours = State(initialValue: ph)
        _plannedMinutes = State(initialValue: pm)
        _plannedSeconds = State(initialValue: ps)
        let actualDuration = session.actualRun?.duration ?? ""
        let (ah, am, as_) = RunDetailView.split(duration: actualDuration)
        _actualHours = State(initialValue: ah)
        _actualMinutes = State(initialValue: am)
        _actualSeconds = State(initialValue: as_)
        _effortUnit = State(initialValue: .miles)
        _isCompleted = State(initialValue: session.status == .completed)
        _category = State(initialValue: detail?.category ?? .easy)
    }

    var body: some View {
        Form {
            Section("Planned") {
                Picker("Effort unit", selection: $effortUnit) {
                    ForEach(EffortUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Run type", selection: $category) {
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

            Section {
                Toggle("Mark complete", isOn: $isCompleted)
            }
        }
        .navigationTitle("Run Details")
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
        case plannedMiles
        case actualMiles
        case plannedElevation
        case actualElevation
    }

    private func save(statusOverride: PlanStatus?, dismissAfter: Bool) {
        let base = session.runDetail
        let detail: RunDetailData
        if effortUnit == .miles {
            detail = RunDetailData(
                title: base?.title ?? session.title,
                notes: base?.notes ?? "",
                distance: distance,
                duration: "",
                averageHR: base?.averageHR ?? "",
                category: category,
                hkWorkoutUUID: base?.hkWorkoutUUID,
                elevationGain: plannedElevation
            )
        } else {
            let plannedDurationString = RunDetailView.durationString(h: plannedHours, m: plannedMinutes, s: plannedSeconds)
            detail = RunDetailData(
                title: base?.title ?? session.title,
                notes: base?.notes ?? "",
                distance: "",
                duration: plannedDurationString,
                averageHR: base?.averageHR ?? "",
                category: category,
                hkWorkoutUUID: base?.hkWorkoutUUID,
                elevationGain: plannedElevation
            )
        }

        let actualDistanceClean = actualDistance.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualDurationString = RunDetailView.durationString(h: actualHours, m: actualMinutes, s: actualSeconds)
        let actualDistanceValue: String? = effortUnit == .miles ? (actualDistanceClean.isEmpty ? nil : actualDistanceClean) : nil
        let actualDurationValue: String? = effortUnit == .time ? actualDurationString : nil
        let actualElevationClean = actualElevation.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualElevationValue: String? = actualElevationClean.isEmpty ? nil : actualElevationClean

        let status = statusOverride ?? (isCompleted ? .completed : .planned)
        onSave?(detail, status, actualDistanceValue, actualDurationValue, actualElevationValue)
        if dismissAfter {
            dismiss()
        }
    }
}

