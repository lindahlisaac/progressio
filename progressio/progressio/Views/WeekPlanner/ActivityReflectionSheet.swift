import SwiftUI

/// Optional subjective session data after a workout is marked done.
/// Dismiss / Skip leaves the workout completed — reflections are not required.
struct ActivityReflectionSheet: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    let workout: Workout
    var onSaved: () -> Void
    var onCancelled: () -> Void

    @State private var feel: SessionFeel = .ok
    @State private var sessionRPE: Int = 5
    @State private var notes: String = ""
    @State private var showingOverwriteConfirm = false
    @State private var addingDiscomfort = false

    @State private var bodyArea: BodyArea = .knee
    @State private var side: BodySide = .left
    @State private var painLevel: Int = 3
    @State private var timing: DiscomfortTiming = .during
    @State private var trend: DiscomfortTrend = .stable
    @State private var issueTitle: String = ""
    @State private var selectedExistingIssueID: UUID?
    @State private var createNewIssue = true

    private var existingReflection: ActivityReflection? {
        viewModel.activityReflection(for: workout.id)
    }

    private var matchingIssues: [PhysicalIssue] {
        viewModel.matchingActiveIssues(area: bodyArea, side: side)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(workout.title)
                        .font(.headline)
                    Text(workout.activityType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Optional — Skip to finish without logging a reflection.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("How did it feel?") {
                    Picker("Feel", selection: $feel) {
                        ForEach(SessionFeel.allCases) { value in
                            Text(value.label).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $sessionRPE, in: 1...10) {
                        Text("Session RPE: \(sessionRPE)")
                    }
                }

                Section("Notes") {
                    TextField("Performance notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Physical discomfort") {
                    Toggle("Report discomfort", isOn: $addingDiscomfort)
                    if addingDiscomfort {
                        discomfortFields
                    }
                }
            }
            .navigationTitle("Session reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { onCancelled() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                }
            }
            .keyboardDoneButton()
            .onAppear {
                if let existing = existingReflection, existing.reflectionKind == .standard {
                    feel = existing.feel ?? .ok
                    sessionRPE = existing.sessionRPE ?? 5
                    notes = existing.performanceNotes ?? ""
                }
            }
            .alert("Overwrite reflection?", isPresented: $showingOverwriteConfirm) {
                Button("Keep existing") {
                    onSaved()
                }
                Button("Overwrite", role: .destructive) { save(overwrite: true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This workout already has a reflection. Keep it, or overwrite with these answers?")
            }
        }
    }

    @ViewBuilder
    private var discomfortFields: some View {
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
        Picker("During activity", selection: $trend) {
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

    private func attemptSave() {
        if let existing = existingReflection, existing.reflectionKind == .standard {
            showingOverwriteConfirm = true
        } else {
            save(overwrite: true)
        }
    }

    private func save(overwrite: Bool) {
        if let reflection = viewModel.saveActivityReflection(
            workoutID: workout.id,
            reflectionKind: .standard,
            feel: feel,
            sessionRPE: sessionRPE,
            performanceNotes: notes,
            overwriteExisting: overwrite
        ) {
            if addingDiscomfort {
                let issue: PhysicalIssue
                if !createNewIssue, let id = selectedExistingIssueID,
                   let existing = viewModel.physicalIssues.first(where: { $0.id == id && !$0.isDeleted }) {
                    issue = existing
                } else {
                    issue = viewModel.createPhysicalIssue(
                        area: bodyArea,
                        side: side,
                        title: issueTitle,
                        notes: nil
                    )
                }
                _ = viewModel.replaceActivityIssueReport(
                    forWorkoutID: workout.id,
                    physicalIssueID: issue.id,
                    activityReflectionID: reflection.id,
                    painLevel: painLevel,
                    timing: timing,
                    trend: trend
                )
            } else if overwrite {
                viewModel.softDeleteActivityIssueReports(forWorkoutID: workout.id)
            }
        }
        onSaved()
    }
}
