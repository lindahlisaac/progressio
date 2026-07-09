import Foundation

// MARK: - Baseline (Task 003)

struct MigrationBaselineStep: MigrationStep {
  let name = "Migration baseline"
  let resultingVersion = AppDataMigration.baselineVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }

    _ = StoragePaths.baseDirectory

    let issues = LegacyDataDecoder.validateLegacyFiles()
    if issues.isEmpty {
      print("✅ Migration baseline: legacy data validated (no issues).")
    } else {
      print("⚠️ Migration baseline: legacy validation reported \(issues.count) issue(s):")
      for issue in issues {
        print("   - \(issue)")
      }
    }
  }
}

// MARK: - Task 004

struct MigrateWeekPlansAndWorkoutsStep: MigrationStep {
  let name = "Migrate week plans and workouts"
  let resultingVersion = AppDataMigration.weekPlansMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    try WeekPlanMigration.migrateAllWeekPlanFiles()
  }
}

// MARK: - Task 005

struct MigrateTemplatesAndStrengthLogsStep: MigrationStep {
  let name = "Migrate templates and strength logs"
  let resultingVersion = AppDataMigration.templatesMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    try TemplateAndStrengthLogMigration.migrateAll()
  }
}

// MARK: - Task 009

struct MigrateEnduranceTemplatesStep: MigrationStep {
  let name = "Migrate endurance templates"
  let resultingVersion = AppDataMigration.enduranceTemplatesMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    try EnduranceTemplateMigration.migrateAll()
  }
}

// MARK: - Task 010

struct MigrateWeeklyTemplateSnapshotsStep: MigrationStep {
  let name = "Migrate weekly template snapshots"
  let resultingVersion = AppDataMigration.weeklyTemplateSnapshotsMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    try WeeklyTemplateSnapshotMigration.migrateAll()
  }
}
