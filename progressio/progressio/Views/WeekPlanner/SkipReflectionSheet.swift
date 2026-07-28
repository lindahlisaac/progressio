import SwiftUI

/// Light skip sheet: optional reason + optional discomfort. Save finalizes `.skipped`.
struct SkipReflectionSheet: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    let workoutID: UUID
    let workoutTitle: String
    var initialReason: String
    var onFinished: () -> Void

    @State private var reason: String = ""
    @State private var addingDiscomfort = false
    @State private var bodyArea: BodyArea = .knee
    @State private var side: BodySide = .left
    @State private var painLevel: Int = 3
    @State private var timing: DiscomfortTiming = .during
    @State private var trend: DiscomfortTrend = .stable
    @State private var issueTitle: String = ""
    @State private var selectedExistingIssueID: UUID?
    @State private var createNewIssue = true

    private var matchingIssues: [PhysicalIssue] {
        viewModel.matchingActiveIssues(area: bodyArea, side: side)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(workoutTitle)
                        .font(.headline)
                    Text("Reason and discomfort are optional.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Why are you skipping? (optional)") {
                    TextField("Skip reason", text: $reason, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Physical discomfort (optional)") {
                    Toggle("Report discomfort", isOn: $addingDiscomfort)
                    if addingDiscomfort {
                        Picker("Body area", selection: $bodyArea) {
                            ForEach(BodyArea.allCases) { area in
                                Text(area.rawValue).tag(area)
                            }
                        }
                        Picker("Side", selection: $side) {
                            ForEach(BodySide.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        Stepper(value: $painLevel, in: 1...10) {
                            Text("Pain: \(painLevel)/10")
                        }
                        Picker("Timing", selection: $timing) {
                            ForEach(DiscomfortTiming.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        Picker("Trend", selection: $trend) {
                            ForEach(DiscomfortTrend.allCases) { t in
                                Text(t.rawValue).tag(t)
                            }
                        }
                        if !matchingIssues.isEmpty {
                            Picker("Link to issue", selection: Binding(
                                get: { createNewIssue ? "new" : (selectedExistingIssueID?.uuidString ?? "new") },
                                set: { value in
                                    if value == "new" {
                                        createNewIssue = true
                                        selectedExistingIssueID = nil
                                    } else if let id = UUID(uuidString: value) {
                                        createNewIssue = false
                                        selectedExistingIssueID = id
                                    }
                                }
                            )) {
                                Text("Create new issue").tag("new")
                                ForEach(matchingIssues) { issue in
                                    Text(issue.displayName).tag(issue.id.uuidString)
                                }
                            }
                        }
                        if createNewIssue {
                            TextField("Issue title (optional)", text: $issueTitle)
                        }
                    }
                }
            }
            .navigationTitle("Skip session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onFinished() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skip") { save() }
                }
            }
            .keyboardDoneButton()
            .onAppear {
                reason = initialReason
            }
        }
    }

    private func save() {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let discomfort: (
            area: BodyArea,
            side: BodySide,
            painLevel: Int,
            timing: DiscomfortTiming,
            trend: DiscomfortTrend,
            existingIssueID: UUID?,
            newIssueTitle: String?
        )? = addingDiscomfort
            ? (
                bodyArea,
                side,
                painLevel,
                timing,
                trend,
                createNewIssue ? nil : selectedExistingIssueID,
                createNewIssue ? issueTitle : nil
            )
            : nil
        _ = viewModel.finalizeSkip(
            workoutID: workoutID,
            reason: trimmed,
            discomfort: discomfort
        )
        onFinished()
    }
}
