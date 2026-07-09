import XCTest
@testable import progressio

final class MigrationRunnerTests: XCTestCase {
    private var tempDirectory: URL!
    private var versionFileURL: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("progressio-migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        versionFileURL = tempDirectory.appendingPathComponent(AppDataMigration.versionFileName)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testFreshInstallRunsBaselineAndPersistsVersionOne() throws {
        let runner = MigrationRunner(versionFileURL: versionFileURL)

        try runner.runMigrations()

        XCTAssertEqual(runner.loadCurrentVersion(), AppDataMigration.baselineVersion)
        let record = try loadVersionRecord()
        XCTAssertEqual(record.version, AppDataMigration.baselineVersion)
        XCTAssertEqual(record.lastMigrationName, "Migration baseline")
    }

    func testRelaunchDoesNotRerunCompletedMigration() throws {
        let runner = MigrationRunner(versionFileURL: versionFileURL)
        try runner.runMigrations()
        try runner.runMigrations()

        XCTAssertEqual(runner.loadCurrentVersion(), AppDataMigration.baselineVersion)
    }

    func testCorruptVersionFileFallsBackToLegacyAndRerunsBaseline() throws {
        try Data("not json".utf8).write(to: versionFileURL)

        let runner = MigrationRunner(versionFileURL: versionFileURL)
        XCTAssertEqual(runner.loadCurrentVersion(), AppDataMigration.legacyVersion)

        try runner.runMigrations()
        XCTAssertEqual(runner.loadCurrentVersion(), AppDataMigration.baselineVersion)
    }

    func testFailedStepDoesNotAdvanceVersion() {
        struct FailingStep: MigrationStep {
            let name = "Failing step"
            let resultingVersion = AppDataMigration.baselineVersion

            func migrate(from currentVersion: Int) throws {
                throw NSError(domain: "MigrationRunnerTests", code: 1)
            }
        }

        let runner = MigrationRunner(
            steps: [FailingStep()],
            versionFileURL: versionFileURL
        )

        XCTAssertThrowsError(try runner.runMigrations())
        XCTAssertFalse(FileManager.default.fileExists(atPath: versionFileURL.path))
        XCTAssertEqual(runner.loadCurrentVersion(), AppDataMigration.legacyVersion)
    }

    func testMissingStepThrowsWithoutWritingVersionFile() {
        struct OrphanStep: MigrationStep {
            let name = "Orphan step"
            let resultingVersion = 99

            func migrate(from currentVersion: Int) throws {}
        }

        let runner = MigrationRunner(
            steps: [OrphanStep()],
            versionFileURL: versionFileURL
        )

        XCTAssertThrowsError(try runner.runMigrations()) { error in
            guard case MigrationError.missingStep(let version) = error else {
                return XCTFail("Expected MigrationError.missingStep, got \(error)")
            }
            XCTAssertEqual(version, AppDataMigration.baselineVersion)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: versionFileURL.path))
    }

    private func loadVersionRecord() throws -> AppDataVersionRecord {
        let data = try Data(contentsOf: versionFileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppDataVersionRecord.self, from: data)
    }
}
