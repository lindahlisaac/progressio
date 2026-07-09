import Foundation

enum TemplateAndStrengthLogMigration {

    static func migrateAll(fileManager: FileManager = .default) throws {
        try migrateTemplatesFile(fileManager: fileManager)
        try migrateWeeklyTemplatesFile(fileManager: fileManager)
        let logsMigrated = try migrateStrengthLogFiles(fileManager: fileManager)
        let embedded = try embedStrengthLogsIntoWeekPlans(fileManager: fileManager)
        print("✅ Template/strength migration: \(logsMigrated) strength log file(s), embedded \(embedded) workout snapshot(s).")
    }

    // MARK: - templates.json

    static func migrateTemplatesFile(fileManager: FileManager = .default) throws {
        let url = LegacyDataDecoder.templatesURL()
        guard fileManager.fileExists(atPath: url.path) else { return }

        let data = try Data(contentsOf: url)
        guard TemplatePersistence.jsonNeedsTemplateMetadataMigration(data) else {
            print("⏭️ templates.json already has metadata.")
            return
        }

        _ = try MigrationBackup.backupFile(at: url, fileManager: fileManager)
        let templates = try TemplatePersistence.decodeTemplates(data)
        try TemplatePersistence.saveTemplates(templates, to: url)
        print("✅ Migrated templates.json (\(templates.count) template(s)).")
    }

    // MARK: - weeklyTemplates.json

    static func migrateWeeklyTemplatesFile(fileManager: FileManager = .default) throws {
        let url = LegacyDataDecoder.weeklyTemplatesURL()
        guard fileManager.fileExists(atPath: url.path) else { return }

        let data = try Data(contentsOf: url)
        guard TemplatePersistence.jsonNeedsWeeklyTemplateMetadataMigration(data) else {
            print("⏭️ weeklyTemplates.json already has metadata.")
            return
        }

        _ = try MigrationBackup.backupFile(at: url, fileManager: fileManager)
        let templates = try TemplatePersistence.decodeWeeklyTemplates(data)
        try TemplatePersistence.saveWeeklyTemplates(templates, to: url)
        print("✅ Migrated weeklyTemplates.json (\(templates.count) template(s)).")
    }

    // MARK: - strengthlog-*.json

    @discardableResult
    static func migrateStrengthLogFiles(fileManager: FileManager = .default) throws -> Int {
        let urls = LegacyDataDecoder.strengthLogURLs(fileManager: fileManager)
        var migratedCount = 0

        for url in urls {
            let data = try Data(contentsOf: url)
            guard StrengthLogPersistence.jsonNeedsMetadataMigration(data) else { continue }

            _ = try MigrationBackup.backupFile(at: url, fileManager: fileManager)
            var state = try StrengthLogPersistence.decode(from: url, fileManager: fileManager)
            try StrengthLogPersistence.save(state, to: url)
            migratedCount += 1
        }

        if migratedCount > 0 {
            print("✅ Migrated \(migratedCount) strength log file(s).")
        }
        return migratedCount
    }

    // MARK: - Embed into week plans

    @discardableResult
    static func embedStrengthLogsIntoWeekPlans(fileManager: FileManager = .default) throws -> Int {
        let weekURLs = LegacyDataDecoder.weekPlanURLs(fileManager: fileManager)
        var embeddedCount = 0

        for url in weekURLs {
            var plan = try WeekPlanPersistence.read(from: url, fileManager: fileManager)
            var planChanged = false

            for dayIndex in plan.days.indices {
                for workoutIndex in plan.days[dayIndex].workouts.indices {
                    guard plan.days[dayIndex].workouts[workoutIndex].activityType == .strength else { continue }

                    let workoutID = plan.days[dayIndex].workouts[workoutIndex].id
                    let logURL = StrengthLogPersistence.strengthLogURL(for: workoutID, fileManager: fileManager)
                    guard fileManager.fileExists(atPath: logURL.path) else { continue }

                    guard let log = StrengthLogPersistence.load(from: logURL) else {
                        print("⚠️ Could not load strength log for workout \(workoutID.uuidString); leaving standalone file.")
                        continue
                    }

                    let snapshot = strengthSnapshot(from: log)
                    if plan.days[dayIndex].workouts[workoutIndex].completedValues.completedStrengthRoutineSnapshot != snapshot {
                        plan.days[dayIndex].workouts[workoutIndex].completedValues.completedStrengthRoutineSnapshot = snapshot
                        if log.isCompleted, plan.days[dayIndex].workouts[workoutIndex].completedValues.completedAt == nil {
                            plan.days[dayIndex].workouts[workoutIndex].completedValues.completedAt = log.updatedAt
                        }
                        planChanged = true
                        embeddedCount += 1
                    }
                }
            }

            if planChanged {
                try WeekPlanPersistence.write(plan, to: url)
            }
        }

        return embeddedCount
    }

    private static func strengthSnapshot(from log: StrengthLogState) -> StrengthRoutineSnapshot {
        let exercises = log.exercises.enumerated().map { index, exercise in
            StrengthExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                orderIndex: index,
                targetSets: exercise.sets.enumerated().map { setIndex, set in
                    StrengthSetSnapshot(
                        id: set.id,
                        setNumber: setIndex + 1,
                        targetReps: Int(set.repHint.filter { $0.isNumber }),
                        targetWeight: parseDouble(from: set.weight),
                        repHint: set.repHint.isEmpty ? nil : set.repHint,
                        actualReps: set.reps.isEmpty ? nil : set.reps,
                        actualWeight: set.weight.isEmpty ? nil : set.weight
                    )
                },
                exerciseRPE: exercise.rpe.isEmpty ? nil : exercise.rpe
            )
        }
        return StrengthRoutineSnapshot(exercises: exercises)
    }

    private static func parseDouble(from string: String) -> Double? {
        let filtered = string.filter { "0123456789.".contains($0) }
        guard !filtered.isEmpty, let value = Double(filtered) else { return nil }
        return value
    }
}
