import SwiftUI

/// Searchable catalog picker for canonical lift names.
struct LiftPickerView: View {
    var title: String = "Choose Lift"
    var onSelect: (CatalogLift) -> Void
    var onSelectCustom: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedGroup: LiftMuscleGroup?
    @State private var showingCustom = false
    @State private var customName: String = ""

    private var filtered: [CatalogLift] {
        let base: [CatalogLift]
        if let selectedGroup {
            base = LiftCatalog.lifts(in: selectedGroup)
        } else {
            base = LiftCatalog.all
        }
        let key = LiftCatalog.normalizeKey(query)
        guard !key.isEmpty else { return base }
        return base.filter { lift in
            LiftCatalog.normalizeKey(lift.name).contains(key)
                || lift.aliases.contains { LiftCatalog.normalizeKey($0).contains(key) }
        }
    }

    private var grouped: [(LiftMuscleGroup, [CatalogLift])] {
        let groups = LiftMuscleGroup.allCases
        return groups.compactMap { group in
            let lifts = filtered.filter { $0.muscleGroup == group }
            return lifts.isEmpty ? nil : (group, lifts)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            groupChip(title: "All", selected: selectedGroup == nil) {
                                selectedGroup = nil
                            }
                            ForEach(LiftMuscleGroup.allCases) { group in
                                groupChip(title: group.rawValue, selected: selectedGroup == group) {
                                    selectedGroup = group
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No matching lifts",
                        systemImage: "magnifyingglass",
                        description: Text("Try another search, or add a custom lift name.")
                    )
                } else if selectedGroup == nil, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ForEach(grouped, id: \.0) { group, lifts in
                        Section(group.rawValue) {
                            ForEach(lifts) { lift in
                                liftRow(lift)
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(filtered) { lift in
                            liftRow(lift)
                        }
                    }
                }

                if onSelectCustom != nil {
                    Section {
                        Button {
                            customName = query
                            showingCustom = true
                        } label: {
                            Label("Custom lift…", systemImage: "plus.circle")
                        }
                    } footer: {
                        Text("Prefer catalog names when possible so history can match prior sessions.")
                    }
                }
            }
            .searchable(text: $query, prompt: "Search lifts")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingCustom) {
                NavigationStack {
                    Form {
                        TextField("Lift name", text: $customName)
                            .textInputAutocapitalization(.words)
                    }
                    .navigationTitle("Custom Lift")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingCustom = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                onSelectCustom?(LiftCatalog.canonicalName(for: trimmed))
                                showingCustom = false
                                dismiss()
                            }
                            .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func liftRow(_ lift: CatalogLift) -> some View {
        Button {
            onSelect(lift)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lift.name)
                        .foregroundStyle(.primary)
                    if selectedGroup == nil {
                        Text(lift.muscleGroup.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func groupChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
