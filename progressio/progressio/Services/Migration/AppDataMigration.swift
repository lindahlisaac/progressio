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

  /// Highest migration step that runs in the current app release.
  /// Task 005 stub exists in `MigrationSteps.swift` but stays out of `defaultSteps` until that task ships.
  static let latestVersion = weekPlansMigratedVersion

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
