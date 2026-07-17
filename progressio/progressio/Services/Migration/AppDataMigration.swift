import Foundation

/// Tracks local on-disk data migration progress (distinct from per-record `WorkoutSchema`).
enum AppDataMigration {
  /// Implicit version before any migration has run.
  static let legacyVersion = 0

  /// Baseline: migration infrastructure installed; legacy payloads validated.
  static let baselineVersion = 1

  /// Week plans migrated to `Workout` model (Task 004).
  static let weekPlansMigratedVersion = 2

  /// Templates and strength logs migrated (Task 005).
  static let templatesMigratedVersion = 3

  /// Run templates split into EnduranceTemplate (Task 009).
  static let enduranceTemplatesMigratedVersion = 4

  /// Weekly templates use workout entry snapshots (Task 010).
  static let weeklyTemplateSnapshotsMigratedVersion = 5

  /// HealthKit import UUID reference table (Task 019).
  static let healthKitImportReferencesMigratedVersion = 6

  /// Strength logs embedded in workout completed snapshots (Task 021).
  static let strengthLogEmbedMigratedVersion = 7

  /// Highest migration step that runs in the current app release.
  static let latestVersion = strengthLogEmbedMigratedVersion

  static let versionFileName = "dataVersion.json"
}

struct AppDataVersionRecord: Codable, Equatable {
  var version: Int
  var updatedAt: Date
  var lastMigrationName: String?

  init(version: Int, updatedAt: Date = Date(), lastMigrationName: String? = nil) {
    self.version = version
    self.updatedAt = updatedAt
    self.lastMigrationName = lastMigrationName
  }
}
