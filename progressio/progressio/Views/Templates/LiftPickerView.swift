import SwiftUI

/// Searchable catalog picker for canonical lift names.
struct LiftPickerView: View {
    var title: String = "Choose Lift"
    /// When false, content is pushed inside an existing `NavigationStack` (e.g. edit-template sheet).
    var embedsNavigationStack: Bool = true
    var onSelect: (CatalogLift) -> Void
    var onSelectCustom: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var selectedGroup: LiftMuscleGroup?
    @State private var customName: String = ""
    @State private var showingCustomForm = false

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
        LiftMuscleGroup.allCases.compactMap { group in
            let lifts = filtered.filter { $0.muscleGroup == group }
            return lifts.isEmpty ? nil : (group, lifts)
        }
    }

    var body: some View {
        Group {
            if embedsNavigationStack {
                NavigationStack {
                    pickerBody
                }
            } else {
                pickerBody
            }
        }
    }

    private var pickerBody: some View {
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
                    if showingCustomForm {
                        TextField("Custom lift name", text: $customName)
                            .textInputAutocapitalization(.words)
                        Button("Use custom name") {
                            let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            onSelectCustom?(LiftCatalog.canonicalName(for: trimmed))
                            dismiss()
                        }
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button {
                            customName = query
                            showingCustomForm = true
                        } label: {
                            Label("Custom lift…", systemImage: "plus.circle")
                        }
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
            if embedsNavigationStack {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
