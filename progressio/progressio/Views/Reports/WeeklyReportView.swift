import SwiftUI

struct WeeklyReportView: View {
    let totals: [WeekModalityTotal]

    var body: some View {
        List {
            if totals.isEmpty {
                Text("No workouts this week")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(totals) { total in
                    Section(total.activityType.rawValue) {
                        HStack {
                            Text("Completed")
                            Spacer()
                            Text(amountText(total.completedAmount, unit: total.unitLabel, strength: total.activityType == .strength))
                                .bold()
                        }
                        HStack {
                            Text("Planned")
                            Spacer()
                            Text(amountText(total.plannedAmount, unit: total.unitLabel, strength: total.activityType == .strength))
                                .bold()
                        }
                    }
                }
            }
        }
        .navigationTitle("Weekly Report")
    }

    private func amountText(_ value: Double, unit: String, strength: Bool) -> String {
        if strength {
            return "\(Int(value.rounded()))"
        }
        if value == value.rounded() {
            return "\(Int(value.rounded())) \(unit)"
        }
        return String(format: "%.1f %@", value, unit)
    }
}
