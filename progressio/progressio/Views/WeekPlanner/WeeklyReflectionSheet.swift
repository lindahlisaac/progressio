import SwiftUI

/// Optional weekly subjective capture when completing a week.
struct WeeklyReflectionSheet: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    var onFinished: () -> Void

    @State private var weekRating: Int = 5
    @State private var fatigue: FatigueLevel = .normal
    @State private var recovery: RecoveryLevel = .normal
    @State private var sleepQuality: SleepQualityLevel = .normal
    @State private var motivation: MotivationLevel = .moderate
    @State private var mood: MoodLevel = .okay
    @State private var lifeStress: LifeStressLevel = .moderate
    @State private var whatWentWell: String = ""
    @State private var nextWeekChanges: String = ""
    @State private var issueTrends: [UUID: WeeklyIssueTrend] = [:]

    private var issues: [PhysicalIssue] {
        viewModel.activePhysicalIssues
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rate the week") {
                    Stepper(value: $weekRating, in: 1...10) {
                        Text("Overall: \(weekRating)/10")
                    }
                    Text("The quality of the week as a whole.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("How you felt") {
                    Picker("Fatigue", selection: $fatigue) {
                        ForEach(FatigueLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                    Picker("Recovery", selection: $recovery) {
                        ForEach(RecoveryLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                    Picker("Sleep quality", selection: $sleepQuality) {
                        ForEach(SleepQualityLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                    Picker("Motivation", selection: $motivation) {
                        ForEach(MotivationLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                    Picker("Mood", selection: $mood) {
                        ForEach(MoodLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                    Picker("Life stress", selection: $lifeStress) {
                        ForEach(LifeStressLevel.allCases) { v in Text(v.label).tag(v) }
                    }
                }

                Section("Notes") {
                    TextField("What went well", text: $whatWentWell, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Changes for next week", text: $nextWeekChanges, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                if !issues.isEmpty {
                    Section("Physical issues") {
                        ForEach(issues) { issue in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(issue.displayName)
                                    .font(.subheadline.weight(.semibold))
                                let weekReports = viewModel.reports(forIssue: issue.id, inCurrentWeekOnly: true)
                                if weekReports.isEmpty {
                                    Text("No reports this week")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(weekReports) { report in
                                        Text("Pain \(report.painLevel)/10 · \(report.timing.rawValue) · \(report.trendDuringActivity.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Picker(
                                    "Trend",
                                    selection: Binding(
                                        get: { issueTrends[issue.id] ?? .stable },
                                        set: { issueTrends[issue.id] = $0 }
                                    )
                                ) {
                                    ForEach(WeeklyIssueTrend.allCases) { trend in
                                        Text(trend.rawValue).tag(trend)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Weekly reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        viewModel.markWeekComplete()
                        onFinished()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & complete") {
                        let reviews = issues.map { issue in
                            (issueID: issue.id, trend: issueTrends[issue.id] ?? .stable)
                        }
                        _ = viewModel.saveWeeklyReflection(
                            weekRating: weekRating,
                            fatigue: fatigue,
                            recovery: recovery,
                            sleepQuality: sleepQuality,
                            motivation: motivation,
                            mood: mood,
                            lifeStress: lifeStress,
                            whatWentWell: whatWentWell,
                            nextWeekChanges: nextWeekChanges,
                            issueReviews: reviews
                        )
                        viewModel.markWeekComplete()
                        onFinished()
                    }
                }
            }
            .keyboardDoneButton()
            .onAppear {
                if let existing = viewModel.weeklyReflection(for: viewModel.currentWeekKey) {
                    weekRating = existing.weekRating
                    fatigue = existing.fatigue
                    recovery = existing.recovery
                    sleepQuality = existing.sleepQuality
                    motivation = existing.motivation
                    mood = existing.mood
                    lifeStress = existing.lifeStress
                    whatWentWell = existing.whatWentWell ?? ""
                    nextWeekChanges = existing.nextWeekChanges ?? ""
                }
                for issue in issues {
                    if issueTrends[issue.id] == nil {
                        issueTrends[issue.id] = .stable
                    }
                }
            }
        }
    }
}
