import Foundation

/// Helpers for non-destructive migrations in later tasks.
enum MigrationBackup {
  static func backupFile(at url: URL, fileManager: FileManager = .default) throws -> URL? {
    guard fileManager.fileExists(atPath: url.path) else { return nil }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
    let backupName = "\(url.lastPathComponent).backup-\(stamp)"
    let backupURL = url.deletingLastPathComponent().appendingPathComponent(backupName)

    if fileManager.fileExists(atPath: backupURL.path) {
      return backupURL
    }

    try fileManager.copyItem(at: url, to: backupURL)
    print("📦 Migration backup created: \(backupURL.lastPathComponent)")
    return backupURL
  }
}
