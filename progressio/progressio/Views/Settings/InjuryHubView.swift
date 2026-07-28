import SwiftUI

/// Settings entry: browse active/resolved physical issues and resolve outside weekly reflection.
struct InjuryHubView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @State private var segment: Segment = .active

    private enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case resolved = "Resolved"
        var id: String { rawValue }
    }

    private var issues: [PhysicalIssue] {
        switch segment {
        case .active:
            return viewModel.activePhysicalIssues.sorted { $0.startedAt > $1.startedAt }
        case .resolved:
            return viewModel.resolvedPhysicalIssues
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Status", selection: $segment) {
                    ForEach(Segment.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if issues.isEmpty {
                Section {
                    ContentUnavailableView(
                        segment == .active ? "No active issues" : "No resolved issues",
                        systemImage: "cross.case",
                        description: Text(
                            segment == .active
                                ? "Issues you report during session reflections show up here."
                                : "Resolved injuries will appear in this list."
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(issues) { issue in
                        NavigationLink {
                            InjuryDetailView(viewModel: viewModel, issueID: issue.id)
                        } label: {
                            InjuryRow(
                                issue: issue,
                                latestReport: viewModel.latestIssueReport(forIssueID: issue.id)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Injuries")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InjuryRow: View {
    let issue: PhysicalIssue
    var latestReport: ActivityIssueReport?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.displayName)
                .font(.body.weight(.semibold))
            Text("\(issue.bodyArea.rawValue) · \(issue.side.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text("Started \(Self.dateFormatter.string(from: issue.startedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if let latestReport {
                    Text("· Pain \(latestReport.painLevel)/10")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let at = latestReport.createdAt {
                        Text("· \(Self.dateFormatter.string(from: at))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            if issue.status == .resolved, let resolvedAt = issue.resolvedAt {
                Text("Resolved \(Self.dateFormatter.string(from: resolvedAt))")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

struct InjuryDetailView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    let issueID: UUID
    @State private var resolveNote = ""
    @State private var showingResolveConfirm = false

    private var issue: PhysicalIssue? {
        viewModel.physicalIssues.first { $0.id == issueID && !$0.isDeleted }
    }

    private var reports: [ActivityIssueReport] {
        viewModel.issueReports(forIssueID: issueID)
    }

    private var reviews: [WeeklyIssueReview] {
        viewModel.weeklyReviews(forIssueID: issueID)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        Group {
            if let issue {
                List {
                    Section("Issue") {
                        LabeledContent("Name", value: issue.displayName)
                        LabeledContent("Area", value: "\(issue.side.rawValue) \(issue.bodyArea.rawValue)")
                        LabeledContent("Started", value: Self.dayFormatter.string(from: issue.startedAt))
                        LabeledContent("Status", value: issue.status.rawValue)
                        if let resolvedAt = issue.resolvedAt {
                            LabeledContent("Resolved", value: Self.dayFormatter.string(from: resolvedAt))
                        }
                        if let notes = issue.optionalNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Activity reports") {
                        if reports.isEmpty {
                            Text("No activity reports yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(reports.reversed()) { report in
                                reportRow(report)
                            }
                        }
                    }

                    Section("Weekly reviews") {
                        if reviews.isEmpty {
                            Text("No weekly reviews yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(reviews.reversed()) { review in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(review.weekKey)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(review.weeklyTrend.rawValue) → \(review.resultingStatus.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section {
                        if issue.status == .active {
                            TextField("Optional note on resolve", text: $resolveNote, axis: .vertical)
                                .lineLimit(2, reservesSpace: true)
                            Button("Mark resolved", role: .destructive) {
                                showingResolveConfirm = true
                            }
                        } else {
                            Button("Reopen as active") {
                                viewModel.reopenPhysicalIssue(id: issue.id)
                            }
                        }
                    }
                }
                .navigationTitle(issue.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .alert("Resolve this issue?", isPresented: $showingResolveConfirm) {
                    Button("Resolve", role: .destructive) {
                        viewModel.resolvePhysicalIssue(id: issue.id, note: resolveNote)
                        resolveNote = ""
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("It will move to the Resolved list. You can reopen it later.")
                }
            } else {
                ContentUnavailableView("Issue not found", systemImage: "cross.case")
            }
        }
    }

    @ViewBuilder
    private func reportRow(_ report: ActivityIssueReport) -> some View {
        let context = viewModel.workoutContext(forWorkoutID: report.workoutID)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(context?.title ?? "Workout")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Pain \(report.painLevel)/10")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let date = report.createdAt ?? context?.date {
                Text(Self.dateFormatter.string(from: date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("\(report.timing.rawValue) · \(report.trendDuringActivity.rawValue)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
