import SwiftUI
import HealthKit

struct SettingsView: View {
    @ObservedObject var weekViewModel: WeekPlannerViewModel
    @State private var isImporting = false
    @State private var importMessage: String?

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
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(weekViewModel: WeekPlannerViewModel(templates: TemplateLibraryViewModel.makeSamples()))
}



