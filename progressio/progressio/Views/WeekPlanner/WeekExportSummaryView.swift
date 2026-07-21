import SwiftUI
import UIKit

/// Screenshot-friendly condensed week summary with clipboard copy for coaches.
struct WeekExportSummaryView: View {
    let weekPlan: WeekPlan
    var periodizedWeekName: String? = nil
    var activityReflections: [ActivityReflection] = []
    var weeklyReflection: WeeklyReflection? = nil
    var physicalIssues: [PhysicalIssue] = []
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    private var snapshot: WeekExportSummary.Snapshot {
        WeekExportSummary.make(
            from: weekPlan,
            periodizedWeekName: periodizedWeekName,
            activityReflections: activityReflections,
            weeklyReflection: weeklyReflection,
            physicalIssues: physicalIssues
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    totalsCard
                    if !snapshot.weeklyReflectionLines.isEmpty {
                        reflectionCard
                    }
                    daysCard
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Week Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = snapshot.plainText
                        didCopy = true
                    } label: {
                        Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                    }
                }
            }
            .onChange(of: didCopy) { copied in
                guard copied else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    didCopy = false
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.weekRangeTitle)
                .font(.title2.weight(.semibold))
            if let subtitle = snapshot.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if snapshot.isWeekComplete {
                Text("Week complete")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
            Text("Plan · Actual · Vert · Reflections")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly reflection")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            ForEach(snapshot.weeklyReflectionLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var totalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly totals")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if snapshot.totals.isEmpty {
                Text("No workouts this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.totals) { total in
                    HStack(alignment: .firstTextBaseline) {
                        Label(total.activityType.rawValue, systemImage: total.activityType.systemImage)
                            .font(.subheadline.weight(.medium))
                        Spacer(minLength: 8)
                        Text(totalAmount(total))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                if !snapshot.elevationLines.isEmpty {
                    Divider().padding(.vertical, 2)
                    ForEach(snapshot.elevationLines, id: \.self) { line in
                        Text(line)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var daysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(snapshot.days) { day in
                VStack(alignment: .leading, spacing: 6) {
                    Text(day.title)
                        .font(.subheadline.weight(.semibold))

                    if day.workouts.isEmpty {
                        Text("Rest")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(day.workouts) { workout in
                            workoutRow(workout)
                        }
                    }
                }
                if day.id != snapshot.days.last?.id {
                    Divider()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func workoutRow(_ workout: WeekExportSummary.WorkoutLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(workout.timePeriod)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                Text(workout.activityType)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(workout.title)
                    .font(.caption.weight(.medium))
                    .strikethrough(workout.isSkipped)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(workout.status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if !workout.detail.isEmpty {
                Text(workout.detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.leading, 28)
            }
            if let reflection = workout.reflectionLine {
                Text(reflection)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 28)
            }
        }
        .padding(.vertical, 2)
    }

    private func totalAmount(_ total: WeekModalityTotal) -> String {
        let completed: String
        let planned: String
        if total.activityType == .strength {
            completed = String(Int(total.completedAmount.rounded()))
            planned = String(Int(total.plannedAmount.rounded()))
        } else if total.completedAmount == total.completedAmount.rounded(),
                  total.plannedAmount == total.plannedAmount.rounded() {
            completed = String(Int(total.completedAmount.rounded()))
            planned = String(Int(total.plannedAmount.rounded()))
        } else {
            completed = String(format: "%.1f", total.completedAmount)
            planned = String(format: "%.1f", total.plannedAmount)
        }
        return "\(completed) / \(planned) \(total.unitLabel)"
    }
}
