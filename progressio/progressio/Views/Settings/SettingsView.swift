import SwiftUI
import HealthKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var exportURL: URL?
    @State private var showingWeekImporter = false
    @State private var weekImportMessage: String?
    @State private var syncMessage: String?
    @State private var isSyncing = false

    var body: some View {
        List {
            Section("HealthKit") {
                Button {
                    HealthKitManager.shared.requestAuthorization { success, error in
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
                    HealthKitManager.shared.requestAuthorization { success, error in
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
                        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())
                        HealthKitManager.shared.fetchRecentRuns(since: start) { runs in
                            weekViewModel.importUnattachedRuns(runs)
                            importMessage = runs.isEmpty ? "No new runs found." : "Imported \(runs.count) run(s)."
                            isImporting = false
                        }
                    }
                } label: {
                    Label("Import last 7 days of runs", systemImage: "arrow.down.circle")
                }
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
            }
            Section("Coming soon") {
                Label("Attach detected runs to planned days", systemImage: "bolt.heart")
                Label("Log strength sets with weight/reps/RPE", systemImage: "list.bullet.clipboard")
            }
            Section("Maintenance") {
                Button(role: .destructive) {
                    weekViewModel.clearUnattachedRuns()
                } label: {
                    Label("Clear imported runs", systemImage: "trash")
                }
                .disabled(weekViewModel.unattachedRuns.isEmpty)
                if !weekViewModel.unattachedRuns.isEmpty {
                    Text("Unattached runs: \(weekViewModel.unattachedRuns.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task {
                        isSyncing = true
                        syncMessage = nil
                        await weekViewModel.forceSync()
                        isSyncing = false
                        syncMessage = "Synced via CloudKit"
                    }
                } label: {
                    Label("Sync now", systemImage: "arrow.clockwise")
                }
                if isSyncing {
                    HStack {
                        ProgressView()
                        Text("Syncing…")
                    }
                } else if let syncMessage {
                    Text(syncMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Week data") {
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
            }
        }
        .navigationTitle("Settings")
        .fileImporter(isPresented: $showingWeekImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                print("📂 File selected: \(url.lastPathComponent)")
                weekViewModel.importWeek(from: url)
                weekImportMessage = "Week imported successfully from \(url.lastPathComponent)"
            case .failure(let error):
                print("❌ File import error: \(error.localizedDescription)")
                weekImportMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    SettingsView(weekViewModel: WeekPlannerViewModel(templates: TemplateLibraryViewModel.makeSamples()))
}



