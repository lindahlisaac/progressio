import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("HealthKit") {
                Label("Runs are read from HealthKit only", systemImage: "shield.lefthalf.filled")
                Label("Grant run + HR read access in Settings", systemImage: "heart.text.square")
            }
            Section("Coming soon") {
                Label("Attach detected runs to planned days", systemImage: "bolt.heart")
                Label("Log strength sets with weight/reps/RPE", systemImage: "list.bullet.clipboard")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}



