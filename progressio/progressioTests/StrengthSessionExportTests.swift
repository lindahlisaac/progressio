import XCTest
@testable import progressio

final class StrengthSessionExportTests: XCTestCase {

    private func sampleExercises() -> [ExerciseLog] {
        [
            ExerciseLog(
                name: "Machine Chest Press",
                sets: [
                    SetLog(weight: "100", reps: "10", repHint: "8-12"),
                    SetLog(weight: "100", reps: "10", repHint: "8-12"),
                    SetLog(weight: "100", reps: "8", repHint: "8-12"),
                    SetLog(weight: "", reps: "", repHint: "8-12", isSkipped: true)
                ]
            ),
            ExerciseLog(
                name: "Squat",
                sets: [
                    SetLog(weight: "135", reps: "5", repHint: "5"),
                    SetLog(weight: "", reps: "", repHint: "5")
                ]
            )
        ]
    }

    func testSummaryCountsLoggedSkipsAndVolume() {
        let summary = StrengthSessionExport.summary(from: sampleExercises())
        XCTAssertEqual(summary.exerciseCount, 2)
        XCTAssertEqual(summary.setsLogged, 4)
        XCTAssertEqual(summary.setsSkipped, 1)
        XCTAssertEqual(summary.totalReps, 33)
        XCTAssertNotNil(summary.totalVolume)
        XCTAssertEqual(summary.totalVolume!, 3475.0, accuracy: 0.001)
    }

    func testPlainTextUsesTitleAndAnnotatesSkipped() {
        let text = StrengthSessionExport.plainText(title: "Push A", exercises: sampleExercises())
        XCTAssertTrue(text.hasPrefix("Push A\n"))
        XCTAssertTrue(text.contains("Machine Chest Press – 3 sets (1 skipped)"))
        XCTAssertTrue(text.contains("Squat – 1 set"))
    }

    func testJSONDocumentIncludesSkipFlagsAndFormatVersion() throws {
        let doc = StrengthSessionExport.document(
            sessionId: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!,
            title: "Push A",
            date: Date(timeIntervalSince1970: 0),
            notes: "Felt strong",
            exercises: sampleExercises()
        )
        XCTAssertEqual(doc.formatVersion, 1)
        XCTAssertEqual(doc.exercises[0].sets.filter(\.isSkipped).count, 1)
        XCTAssertEqual(doc.exercises[0].sets[0].weight, "100")
        XCTAssertNil(doc.exercises[0].sets[3].weight)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(doc)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(StrengthSessionExportDocument.self, from: data)
        XCTAssertEqual(decoded.sessionId, doc.sessionId)
        XCTAssertEqual(decoded.exercises[0].name, "Machine Chest Press")
    }
}
