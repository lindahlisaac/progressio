import XCTest
@testable import progressio

final class StrengthSetUXTests: XCTestCase {

    func testMidpointRepsFromRangeAndSingle() {
        XCTAssertEqual(TemplateSnapshot.midpointReps(from: "8-12"), 10)
        XCTAssertEqual(TemplateSnapshot.midpointReps(from: "8–12"), 10)
        XCTAssertEqual(TemplateSnapshot.midpointReps(from: "10"), 10)
        XCTAssertEqual(TemplateSnapshot.midpointReps(from: " 5 to 7 "), 6)
        XCTAssertNil(TemplateSnapshot.midpointReps(from: ""))
        XCTAssertNil(TemplateSnapshot.midpointReps(from: "amrap"))
    }

    func testStrengthSetSnapshotDecodesMissingIsSkippedAsFalse() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "setNumber": 1,
          "repHint": "8-12",
          "actualReps": "10",
          "actualWeight": "135"
        }
        """.data(using: .utf8)!
        let set = try JSONDecoder().decode(StrengthSetSnapshot.self, from: json)
        XCTAssertFalse(set.isSkipped)
        XCTAssertEqual(set.actualWeight, "135")
    }

    func testCompletedSnapshotRoundTripsIsSkipped() {
        let exercises = [
            ExerciseLog(
                name: "Squat",
                sets: [
                    SetLog(weight: "135", reps: "8", repHint: "8-12", isSkipped: false),
                    SetLog(weight: "", reps: "", repHint: "8-12", isSkipped: true),
                    SetLog(weight: "135", reps: "8", repHint: "8-12", isSkipped: false)
                ]
            )
        ]
        let snapshot = TemplateSnapshot.completedSnapshot(from: exercises)
        XCTAssertEqual(snapshot.exercises[0].targetSets.map(\.isSkipped), [false, true, false])
        XCTAssertNil(snapshot.exercises[0].targetSets[1].actualWeight)
        XCTAssertNil(snapshot.exercises[0].targetSets[1].actualReps)

        let logs = TemplateSnapshot.exerciseLogs(from: snapshot, preferActuals: true)
        XCTAssertEqual(logs[0].sets.map(\.isSkipped), [false, true, false])
    }

    func testAutofillOnlyFillsEmptyNonSkippedSets() {
        var sets = [
            SetLog(weight: "135", reps: "8", repHint: "8", isSkipped: false),
            SetLog(weight: "", reps: "", repHint: "8", isSkipped: false),
            SetLog(weight: "140", reps: "8", repHint: "8", isSkipped: false),
            SetLog(weight: "", reps: "", repHint: "8", isSkipped: true),
            SetLog(weight: "", reps: "", repHint: "8", isSkipped: false)
        ]
        let sourceWeight = sets[0].weight
        let previousSeed = ""
        for index in 1..<sets.count {
            guard !sets[index].isSkipped else { continue }
            guard StrengthWeightAutofill.shouldUpdate(existing: sets[index].weight, previousSeed: previousSeed) else { continue }
            sets[index].weight = sourceWeight
        }
        XCTAssertEqual(sets.map(\.weight), ["135", "135", "140", "", "135"])
    }

    func testAutofillKeepsPaceWhileTypingFullWeight() {
        var followers = ["", "", "140"]
        var seed = ""
        for typed in ["1", "13", "135"] {
            for index in followers.indices {
                guard StrengthWeightAutofill.shouldUpdate(existing: followers[index], previousSeed: seed) else { continue }
                followers[index] = typed
            }
            seed = typed
        }
        XCTAssertEqual(followers, ["135", "135", "140"])
    }
}
