import SwiftUI

struct UnattachedRunsView: View {
    let runs: [UnattachedRun]

    var body: some View {
        List {
            if runs.isEmpty {
                Text("No unattached runs detected.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(runs) { run in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(run.detail.title.isEmpty ? "Run" : run.detail.title)
                            .font(.headline)
                        HStack(spacing: 12) {
                            if !run.detail.distance.isEmpty {
                                Text("\(run.detail.distance) mi")
                                    .font(.subheadline)
                            }
                            if !run.detail.duration.isEmpty {
                                Text(run.detail.duration)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let cat = run.detail.category {
                                Text(cat.rawValue)
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(dateFormatter.string(from: run.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let src = run.source {
                            Text(src)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Unattached Runs")
    }
}

private let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .short
    return fmt
}()

