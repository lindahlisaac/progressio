import SwiftUI

struct PeriodizedBlocksSection: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @Binding var blockPendingDelete: PeriodizedBlockTemplate?
    @Binding var showingDeleteAlert: Bool
    @Binding var blockToApply: PeriodizedBlockTemplate?
    @Binding var showingApplyAlert: Bool

    var body: some View {
        Section("Periodized blocks") {
            if weekViewModel.activePeriodizedBlocks.isEmpty {
                Text("No periodized blocks yet. Create a 2–12 week block from weekly templates or manual days.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(weekViewModel.activePeriodizedBlocks) { block in
                    NavigationLink {
                        PeriodizedBlockDetailView(block: block, weekViewModel: weekViewModel)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.name)
                                .font(.headline)
                            if let notes = block.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(block.weekCount) weeks · \(block.weeks.map(\.displayName).joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            blockToApply = block
                            showingApplyAlert = true
                        } label: {
                            Label("Apply", systemImage: "calendar.badge.plus")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            blockPendingDelete = block
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

struct PeriodizedBlockDetailView: View {
    let block: PeriodizedBlockTemplate
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var showingEdit = false
    @State private var draft: PeriodizedBlockTemplate
    @State private var showingWeeklyPickerForWeek: Int?

    init(block: PeriodizedBlockTemplate, weekViewModel: WeekPlannerViewModel) {
        self.block = block
        self.weekViewModel = weekViewModel
        _draft = State(initialValue: block)
    }

    private var liveBlock: PeriodizedBlockTemplate {
        weekViewModel.periodizedBlocks.first(where: { $0.id == block.id }) ?? block
    }

    var body: some View {
        List {
            if let notes = liveBlock.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
            ForEach(liveBlock.weeks.sorted(by: { $0.weekIndex < $1.weekIndex })) { week in
                Section(week.displayName) {
                    Text("\(week.workoutCount) workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(week.daySnapshots.sorted(by: weekdayOrder), id: \.id) { day in
                        if day.workoutEntries.isEmpty {
                            Text("\(weekdayName(day.weekday)): Rest")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(day.workoutEntries) { entry in
                                HStack {
                                    Image(systemName: entry.activityType.systemImage)
                                        .foregroundStyle(.secondary)
                                    Text("\(weekdayName(day.weekday)): \(entry.title)")
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(liveBlock.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    draft = liveBlock
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                PeriodizedBlockEditorForm(
                    draft: $draft,
                    weeklyTemplates: weekViewModel.activeWeeklyTemplates,
                    showingWeeklyPickerForWeek: $showingWeeklyPickerForWeek
                )
                .navigationTitle("Edit Block")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingEdit = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            weekViewModel.updatePeriodizedBlock(draft)
                            showingEdit = false
                        }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .sheet(item: Binding(
                    get: { showingWeeklyPickerForWeek.map { WeekPickerToken(index: $0) } },
                    set: { showingWeeklyPickerForWeek = $0?.index }
                )) { token in
                    weeklyTemplatePicker(for: token.index)
                }
            }
        }
    }

    private func weeklyTemplatePicker(for weekIndex: Int) -> some View {
        NavigationStack {
            List(weekViewModel.activeWeeklyTemplates) { template in
                Button {
                    guard draft.weeks.indices.contains(weekIndex) else { return }
                    draft.weeks[weekIndex].applyWeeklyTemplateSnapshot(template)
                    showingWeeklyPickerForWeek = nil
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .foregroundStyle(.primary)
                        Text("\(template.days.flatMap(\.workoutEntries).count) workouts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Weekly Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingWeeklyPickerForWeek = nil }
                }
            }
        }
    }

    private func weekdayOrder(_ lhs: DayTemplate, _ rhs: DayTemplate) -> Bool {
        let order: (Int) -> Int = { $0 == 1 ? 8 : $0 }
        return order(lhs.weekday) < order(rhs.weekday)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = .current
        return fmt.shortWeekdaySymbols[(weekday - 1 + 7) % 7]
    }
}

private struct WeekPickerToken: Identifiable {
    let index: Int
    var id: Int { index }
}

struct PeriodizedBlockEditorForm: View {
    @Binding var draft: PeriodizedBlockTemplate
    let weeklyTemplates: [WeeklyTemplate]
    @Binding var showingWeeklyPickerForWeek: Int?

    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $draft.name)
                TextField("Notes (optional)", text: Binding(
                    get: { draft.notes ?? "" },
                    set: { draft.notes = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                ), axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                Stepper(
                    "Weeks: \(draft.weekCount)",
                    value: Binding(
                        get: { draft.weekCount },
                        set: { draft.resize(to: $0) }
                    ),
                    in: PeriodizedBlockTemplate.minWeekCount...PeriodizedBlockTemplate.maxWeekCount
                )
            }

            ForEach(draft.weeks.indices, id: \.self) { index in
                Section {
                    TextField("Week name", text: $draft.weeks[index].displayName)
                    Button("Link weekly template…") {
                        showingWeeklyPickerForWeek = index
                    }
                    .disabled(weeklyTemplates.isEmpty)
                    if draft.weeks[index].linkedWeeklyTemplateId != nil {
                        Text("Linked template snapshot (\(draft.weeks[index].workoutCount) workouts)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Manual / empty week (\(draft.weeks[index].workoutCount) workouts)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Clear week to rest") {
                        draft.weeks[index].daySnapshots = PeriodizedBlockWeek.blankDays()
                        draft.weeks[index].linkedWeeklyTemplateId = nil
                    }
                    .foregroundStyle(.red)
                } header: {
                    Text(PeriodizedBlockWeek.defaultName(for: index))
                }
            }
        }
    }
}

struct CreatePeriodizedBlockSheet: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @Binding var isPresented: Bool
    @State private var draft = PeriodizedBlockTemplate(name: "", weekCount: 4)
    @State private var showingWeeklyPickerForWeek: Int?

    var body: some View {
        NavigationStack {
            PeriodizedBlockEditorForm(
                draft: $draft,
                weeklyTemplates: weekViewModel.activeWeeklyTemplates,
                showingWeeklyPickerForWeek: $showingWeeklyPickerForWeek
            )
            .navigationTitle("New Periodized Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        weekViewModel.addPeriodizedBlock(draft)
                        isPresented = false
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: Binding(
                get: { showingWeeklyPickerForWeek.map { WeekPickerToken(index: $0) } },
                set: { showingWeeklyPickerForWeek = $0?.index }
            )) { token in
                NavigationStack {
                    List(weekViewModel.activeWeeklyTemplates) { template in
                        Button {
                            draft.weeks[token.index].applyWeeklyTemplateSnapshot(template)
                            showingWeeklyPickerForWeek = nil
                        } label: {
                            Text(template.name).foregroundStyle(.primary)
                        }
                    }
                    .navigationTitle("Weekly Template")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingWeeklyPickerForWeek = nil }
                        }
                    }
                }
            }
        }
    }
}
