import SwiftUI

struct WeeklyTemplateListView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    var showEmptyPrompt: Bool = true
    @State private var showingApplyAlert = false
    @State private var templateToApply: WeeklyTemplate?

    var body: some View {
        List {
            if weekViewModel.activeWeeklyTemplates.isEmpty {
                if showEmptyPrompt {
                    Text("No weekly templates yet. Tap + to create one.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                Section {
                    ForEach(weekViewModel.activeWeeklyTemplates) { template in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            if let note = template.note, !note.isEmpty {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(template.days.flatMap { $0.sessions }.count) workouts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                templateToApply = template
                                showingApplyAlert = true
                            } label: {
                                Label("Apply", systemImage: "calendar.badge.plus")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                weekViewModel.deleteWeeklyTemplate(id: template.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Weekly Templates")
        .alert("Apply Template to Current Week?", isPresented: $showingApplyAlert, presenting: templateToApply) { template in
            if weekViewModel.hasWorkoutsInCurrentWeek() {
                Button("Override existing") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: false)
                }
                Button("Keep existing") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: true)
                }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("Apply") {
                    weekViewModel.applyWeeklyTemplate(template, to: weekViewModel.currentStartOfWeek, keepExisting: false)
                }
                Button("Cancel", role: .cancel) { }
            }
        } message: { template in
            if weekViewModel.hasWorkoutsInCurrentWeek() {
                Text("You have existing workouts this week. Choose to override them or keep them alongside '\(template.name)'.")
            } else {
                Text("This will apply '\(template.name)' to the current week.")
            }
        }
    }
}

