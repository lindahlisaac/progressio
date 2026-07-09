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

// MARK: - Task 004 stub (inactive until added to `MigrationRunner.defaultSteps`)

struct MigrateWeekPlansAndWorkoutsStep: MigrationStep {
  let name = "Migrate week plans and workouts"
  let resultingVersion = AppDataMigration.weekPlansMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    // Task 004 will transform weekplan-*.json using LegacySessionMapper.
    print("⏭️ \(name): no-op stub (Task 004).")
  }
}

// MARK: - Task 005 stub (inactive until added to `MigrationRunner.defaultSteps`)

struct MigrateTemplatesAndStrengthLogsStep: MigrationStep {
  let name = "Migrate templates and strength logs"
  let resultingVersion = AppDataMigration.templatesMigratedVersion

  func migrate(from currentVersion: Int) throws {
    guard currentVersion < resultingVersion else { return }
    // Task 005 will migrate templates.json, weeklyTemplates.json, strengthlog-*.json.
    print("⏭️ \(name): no-op stub (Task 005).")
  }
}
