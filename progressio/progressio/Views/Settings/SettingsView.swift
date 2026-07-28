import SwiftUI
import HealthKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @EnvironmentObject private var metricPreferences: ActivityMetricPreferenceStore
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var exportURL: URL?
    @State private var showingWeekImporter = false
    @State private var weekImportMessage: String?
    @State private var isSyncing = false
    @State private var showingDuplicateCleanupConfirm = false
    @State private var cleanupMessage: String?

    private var lastImportText: String {
        guard let date = weekViewModel.lastHealthKitImportAt else {
            return "No Apple Health import yet"
        }
        return "Last import: \(Self.dateTimeFormatter.string(from: date))"
    }

    private var syncStatusText: String {
        if let error = weekViewModel.lastSyncMessage, error.lowercased().contains("fail") {
            return error
        }
        if let date = weekViewModel.lastSyncAt {
            let base = "Last sync: \(Self.dateTimeFormatter.string(from: date))"
            if let message = weekViewModel.lastSyncMessage {
                return "\(base) — \(message)"
            }
            return base
        }
        return weekViewModel.lastSyncMessage ?? "Not synced yet this session"
    }

    var body: some View {
        List {
            Section {
                ForEach(ActivityMetricPreferenceStore.enduranceTypes) { activity in
                    Picker(activity.rawValue, selection: preferenceBinding(for: activity)) {
                        ForEach(ActivityMetricPreferenceStore.allowedMetrics(for: activity)) { metric in
                            Text(metric.settingsLabel).tag(metric)
                        }
                    }
                }
            } header: {
                Text("Primary metrics")
            } footer: {
                Text("Controls the Plan week summary for each activity and the default entry mode when logging. Change anytime; updates apply on next Plan render.")
            }

            Section {
                Button {
                    HealthKitImportService.shared.requestAuthorization { success, error in
                        if let error {
                            print("HK auth error: \(error)")
                        } else {
                            print("HK auth \(success ? "granted" : "not granted")")
                        }
                    }
                } label: {
                    Label("Request Health Access", systemImage: "shield.lefthalf.filled")
                }
                Button {
                    guard HKHealthStore.isHealthDataAvailable() else {
                        importMessage = "Health data not available on this device."
                        return
                    }
                    isImporting = true
                    HealthKitImportService.shared.requestAuthorization { success, error in
                        if let error {
                            importMessage = "Auth failed: \(error.localizedDescription)"
                            isImporting = false
                            return
                        }
                        guard success else {
                            importMessage = "Health access was not granted."
                            isImporting = false
                            return
                        }
                        HealthKitImportService.shared.fetchCandidatesForcingRefresh { candidates in
                            let summary = weekViewModel.processHealthKitCandidates(candidates)
                            importMessage = summary.userMessage + " Open Plan → Unattached to attach them."
                            isImporting = false
                        }
                    }
                } label: {
                    Label("Import last 7 days of runs", systemImage: "arrow.down.circle")
                }
                .accessibilityHint("Imports Apple Health runs into the Unattached list on Plan for manual attach")
                if isImporting {
                    HStack {
                        ProgressView()
                        Text("Importing…")
                    }
                } else if let importMessage {
                    Text(importMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(lastImportText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Apple Health")
            } footer: {
                Text("Imports land in Plan → Unattached. Attach manually to a planned workout or create a new one. Already-imported HealthKit UUIDs are skipped.")
            }

            Section("iCloud Sync") {
                Text(syncStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task {
                        isSyncing = true
                        await weekViewModel.forceSync()
                        isSyncing = false
                    }
                } label: {
                    Label("Sync now", systemImage: "arrow.clockwise")
                }
                .disabled(isSyncing)
                if isSyncing {
                    HStack {
                        ProgressView()
                        Text("Syncing…")
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDuplicateCleanupConfirm = true
                } label: {
                    Label("Clean up duplicate imports", systemImage: "doc.on.doc")
                }
                if let cleanupMessage {
                    Text(cleanupMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button(role: .destructive) {
                    weekViewModel.clearUnattachedRuns()
                } label: {
                    Label("Clear unattached runs", systemImage: "trash")
                }
                .disabled(weekViewModel.activeUnattachedRuns.isEmpty)
                if !weekViewModel.activeUnattachedRuns.isEmpty {
                    Text("Unattached runs: \(weekViewModel.activeUnattachedRuns.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Maintenance")
            } footer: {
                Text("Cleanup removes auto-imported calendar copies across weeks and restores unique HealthKit runs to Unattached. Planned workouts are not removed.")
            }

            Section {
                Button {
                    exportURL = weekViewModel.exportCurrentWeek()
                    weekImportMessage = "Week exported successfully"
                } label: {
                    Label("Export current week", systemImage: "square.and.arrow.up")
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share exported file", systemImage: "square.and.arrow.up.on.square")
                    }
                }
                Button {
                    showingWeekImporter = true
                } label: {
                    Label("Import week from file", systemImage: "square.and.arrow.down")
                }
                if let weekImportMessage {
                    Text(weekImportMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Week data")
            } footer: {
                Text("Export includes embedded strength snapshots. Import restores the week JSON as-is.")
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Clean up duplicate imports?",
            isPresented: $showingDuplicateCleanupConfirm,
            titleVisibility: .visible
        ) {
            Button("Clean up duplicates", role: .destructive) {
                let removed = weekViewModel.cleanupDuplicateImports()
                cleanupMessage = removed == 0
                    ? "No duplicates found."
                    : "Removed \(removed) duplicate import(s)."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes auto-imported Apple Health calendar workouts and restores unique runs to Unattached for manual attach. Does not change planned workouts.")
        }
        .fileImporter(isPresented: $showingWeekImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                weekViewModel.importWeek(from: url)
                weekImportMessage = "Week imported successfully from \(url.lastPathComponent)"
            case .failure(let error):
                weekImportMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }

    private func preferenceBinding(for activity: ActivityType) -> Binding<PrimaryMetric> {
        Binding(
            get: { metricPreferences.primaryMetric(for: activity) },
            set: { metricPreferences.setPrimaryMetric($0, for: activity) }
        )
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SettingsView(weekViewModel: WeekPlannerViewModel(templates: TemplateLibraryViewModel.makeSamples()))
        .environmentObject(ActivityMetricPreferenceStore.shared)
}
