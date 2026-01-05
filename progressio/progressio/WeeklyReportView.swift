import SwiftUI

struct WeeklyReportView: View {
    let plannedRunMiles: Double
    let completedRunMiles: Double
    let plannedRideMiles: Double
    let completedRideMiles: Double
    let plannedStrengthCount: Int
    let completedStrengthCount: Int

    var body: some View {
        List {
            Section("Runs") {
                statRow(label: "Completed", value: completedRunMiles, suffix: "mi")
                statRow(label: "Planned", value: plannedRunMiles, suffix: "mi")
            }
            Section("Rides") {
                statRow(label: "Completed", value: completedRideMiles, suffix: "mi")
                statRow(label: "Planned", value: plannedRideMiles, suffix: "mi")
            }
            Section("Strength") {
                countRow(label: "Completed", count: completedStrengthCount)
                countRow(label: "Planned", count: plannedStrengthCount)
            }
        }
        .navigationTitle("Weekly Report")
    }

    private func statRow(label: String, value: Double, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f %@", value, suffix))
                .bold()
        }
    }

    private func countRow(label: String, count: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(count)")
                .bold()
        }
    }
}


