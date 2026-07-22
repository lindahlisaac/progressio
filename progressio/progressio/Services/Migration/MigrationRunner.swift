import Foundation

final class MigrationRunner {
  static let shared = MigrationRunner()

  private let fileManager: FileManager
  private let steps: [MigrationStep]
  private let versionFileURL: URL

  init(
    fileManager: FileManager = .default,
    steps: [MigrationStep] = MigrationRunner.defaultSteps,
    versionFileURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.steps = steps.sorted { $0.resultingVersion < $1.resultingVersion }
    self.versionFileURL = versionFileURL ?? StoragePaths.file(AppDataMigration.versionFileName)
  }

  /// Active migration steps for the current release.
  private static let defaultSteps: [MigrationStep] = [
    MigrationBaselineStep(),
    MigrateWeekPlansAndWorkoutsStep(),
    MigrateTemplatesAndStrengthLogsStep(),
    MigrateEnduranceTemplatesStep(),
    MigrateWeeklyTemplateSnapshotsStep(),
    MigrateHealthKitImportReferencesStep(),
    MigrateStrengthLogEmbedStep(),
  ]

  /// Runs pending migrations on app launch. Safe to call multiple times.
  func runIfNeeded() {
    do {
      try runMigrations()
    } catch {
      print("❌ Migration failed: \(error.localizedDescription)")
    }
    // Best-effort cleanup of leftover files after v7 embed (Task 031). Safe to run every launch.
    StrengthLogPersistence.sweepOrphanFiles(fileManager: fileManager)
  }

  func runMigrations() throws {
    _ = StoragePaths.baseDirectory

    var currentVersion = loadCurrentVersion()
    guard currentVersion < AppDataMigration.latestVersion else {
      print("✅ Migration: app data already at version \(currentVersion).")
      return
    }

    print("🔄 Migration: upgrading app data from v\(currentVersion) to v\(AppDataMigration.latestVersion).")

    while currentVersion < AppDataMigration.latestVersion {
      guard let step = steps.first(where: { $0.resultingVersion == currentVersion + 1 }) else {
        throw MigrationError.missingStep(forVersion: currentVersion + 1)
      }

      print("🔄 Migration step: \(step.name) (v\(currentVersion) → v\(step.resultingVersion))")
      try step.migrate(from: currentVersion)
      currentVersion = step.resultingVersion
      try saveVersion(currentVersion, migrationName: step.name)
      print("✅ Migration step complete: \(step.name) (now v\(currentVersion))")
    }

    print("✅ Migration complete: app data at version \(currentVersion).")
  }

  func loadCurrentVersion() -> Int {
    guard fileManager.fileExists(atPath: versionFileURL.path) else {
      return AppDataMigration.legacyVersion
    }

    do {
      let data = try Data(contentsOf: versionFileURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let record = try decoder.decode(AppDataVersionRecord.self, from: data)
      return record.version
    } catch {
      print("⚠️ Migration: could not read data version file, assuming legacy v0: \(error)")
      return AppDataMigration.legacyVersion
    }
  }

  func saveVersion(_ version: Int, migrationName: String?) throws {
    let record = AppDataVersionRecord(version: version, updatedAt: Date(), lastMigrationName: migrationName)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted]
    let data = try encoder.encode(record)
    try data.write(to: versionFileURL, options: .atomic)
  }
}

enum MigrationError: LocalizedError {
  case missingStep(forVersion: Int)

  var errorDescription: String? {
    switch self {
    case .missingStep(let version):
      return "No migration step registered for target version \(version)."
    }
  }
}
