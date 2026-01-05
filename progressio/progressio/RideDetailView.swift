import SwiftUI

struct RideDetailView: View {
    let session: PlannedSession
    var onSave: ((RunDetailData, PlanStatus, String?, String?) -> Void)?

    @State private var plannedMiles: String
    @State private var actualMiles: String
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

    init(session: PlannedSession, onSave: ((RunDetailData, PlanStatus, String?, String?) -> Void)? = nil) {
        self.session = session
        self.onSave = onSave
        let detail = session.runDetail
        _plannedMiles = State(initialValue: detail?.distance ?? "")
        _actualMiles = State(initialValue: session.actualRun?.distance ?? "")
        let plannedDuration = detail?.duration ?? ""
        let (ph, pm, ps) = RideDetailView.split(duration: plannedDuration)
        _plannedHours = State(initialValue: ph)
        _plannedMinutes = State(initialValue: pm)
        _plannedSeconds = State(initialValue: ps)
        let actualDuration = session.actualRun?.duration ?? ""
        let (ah, am, as_) = RideDetailView.split(duration: actualDuration)
        _actualHours = State(initialValue: ah)
        _actualMinutes = State(initialValue: am)
        _actualSeconds = State(initialValue: as_)
        _effortUnit = State(initialValue: .miles)
        _isCompleted = State(initialValue: session.status == .completed)
    }

    var body: some View {
        Form {
            Section("Ride") {
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
                        Text("Planned duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        durationPickers(hours: $plannedHours, minutes: $plannedMinutes, seconds: $plannedSeconds)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Actual duration")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        durationPickers(hours: $actualHours, minutes: $actualMinutes, seconds: $actualSeconds)
                    }
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
                    let base = session.runDetail
                    let detail: RunDetailData
                    if effortUnit == .miles {
                        detail = RunDetailData(
                            title: base?.title ?? session.title,
                            notes: base?.notes ?? "",
                            distance: plannedMiles,
                            duration: "",
                            averageHR: base?.averageHR ?? "",
                            category: base?.category,
                            hkWorkoutUUID: base?.hkWorkoutUUID
                        )
                    } else {
                        let plannedDurationString = RideDetailView.durationString(h: plannedHours, m: plannedMinutes, s: plannedSeconds)
                        detail = RunDetailData(
                            title: base?.title ?? session.title,
                            notes: base?.notes ?? "",
                            distance: "",
                            duration: plannedDurationString,
                            averageHR: base?.averageHR ?? "",
                            category: base?.category,
                            hkWorkoutUUID: base?.hkWorkoutUUID
                        )
                    }

                    let actualDistanceClean = actualMiles.trimmingCharacters(in: .whitespacesAndNewlines)
                    let actualDurationString = RideDetailView.durationString(h: actualHours, m: actualMinutes, s: actualSeconds)
                    let actualDistanceValue: String? = effortUnit == .miles ? (actualDistanceClean.isEmpty ? nil : actualDistanceClean) : nil
                    let actualDurationValue: String? = effortUnit == .time ? actualDurationString : nil

                    onSave?(detail, isCompleted ? .completed : .planned, actualDistanceValue, actualDurationValue)
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
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
    }
}


