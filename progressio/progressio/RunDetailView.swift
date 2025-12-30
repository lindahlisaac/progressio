import SwiftUI

struct RunDetailView: View {
    let session: PlannedSession
    var onSave: ((RunDetailData, PlanStatus) -> Void)?

    @State private var title: String
    @State private var notes: String
    @State private var distance: String
    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var avgHR: String
    @State private var isCompleted: Bool
    @State private var category: RunCategory = .easy
    @Environment(\.dismiss) private var dismiss

    init(session: PlannedSession, onSave: ((RunDetailData, PlanStatus) -> Void)? = nil) {
        self.session = session
        self.onSave = onSave
        let detail = session.runDetail
        _title = State(initialValue: detail?.title ?? session.title)
        _notes = State(initialValue: detail?.notes ?? (session.note ?? ""))
        _distance = State(initialValue: detail?.distance ?? "")
        let durationString = detail?.duration ?? ""
        let parts = durationString.split(separator: ":").compactMap { Int($0) }
        let h = parts.count > 0 ? parts[0] : 0
        let m = parts.count > 1 ? parts[1] : 0
        let s = parts.count > 2 ? parts[2] : 0
        _hours = State(initialValue: h)
        _minutes = State(initialValue: m)
        _seconds = State(initialValue: s)
        _avgHR = State(initialValue: detail?.averageHR ?? "")
        _isCompleted = State(initialValue: session.status == .completed)
        _category = State(initialValue: detail?.category ?? .easy)
    }

    var body: some View {
        Form {
            Section("Run Info") {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3, reservesSpace: true)
                Picker("Run type", selection: $category) {
                    ForEach(RunCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
            }

            Section("Metrics") {
                TextField("Distance (mi)", text: $distance)
                    .keyboardType(.decimalPad)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("Hours", selection: $hours) {
                            ForEach(0...500, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        Picker("Minutes", selection: $minutes) {
                            ForEach(0..<60) { Text("\($0)m").tag($0) }
                        }
                        Picker("Seconds", selection: $seconds) {
                            ForEach(0..<60) { Text("\($0)s").tag($0) }
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }
                TextField("Avg HR (bpm)", text: $avgHR)
                    .keyboardType(.numberPad)
            }

            Section {
                Toggle("Mark complete", isOn: $isCompleted)
            }
        }
        .navigationTitle("Run Details")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let durationString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                    let detail = RunDetailData(title: title, notes: notes, distance: distance, duration: durationString, averageHR: avgHR, category: category)
                    onSave?(detail, isCompleted ? .completed : .planned)
                    dismiss()
                }
            }
        }
    }
}

