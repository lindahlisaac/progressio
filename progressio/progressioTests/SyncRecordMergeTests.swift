import XCTest
@testable import progressio

final class SyncRecordMergeTests: XCTestCase {

    private struct MergeFixture: Equatable {
        let id: UUID
        var updatedAt: Date?
        var isDeleted: Bool
    }

    private let baseDate = Date(timeIntervalSince1970: 1_000_000)

    private func date(offset seconds: TimeInterval) -> Date {
        baseDate.addingTimeInterval(seconds)
    }

    private func pick(local: MergeFixture, remote: MergeFixture) -> MergeFixture {
        SyncRecordMerge.pick(
            local: local,
            remote: remote,
            updatedAt: \.updatedAt,
            isDeleted: \.isDeleted
        )
    }

    func testNewerActiveWinsOverOlderTombstone() {
        let id = UUID()
        let local = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: false)
        let remote = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: true)

        XCTAssertEqual(pick(local: local, remote: remote), local)
    }

    func testNewerTombstoneWinsOverOlderActive() {
        let id = UUID()
        let local = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: true)
        let remote = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: false)

        XCTAssertEqual(pick(local: local, remote: remote), local)
    }

    func testNewerTombstoneBlocksResurrectionOfOlderActive() {
        let id = UUID()
        let local = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: true)
        let remote = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: false)

        XCTAssertEqual(pick(local: local, remote: remote), local)
    }

    func testNewerRemoteTombstoneWinsOverOlderActive() {
        let id = UUID()
        let local = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: false)
        let remote = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: true)

        XCTAssertEqual(pick(local: local, remote: remote), remote)
    }

    func testSameDeletionStateUsesLastWriterWins() {
        let id = UUID()
        let local = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: false)
        let remote = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: false)

        XCTAssertEqual(pick(local: local, remote: remote), remote)

        let localTombstone = MergeFixture(id: id, updatedAt: date(offset: 600), isDeleted: true)
        let remoteTombstone = MergeFixture(id: id, updatedAt: date(offset: 0), isDeleted: true)

        XCTAssertEqual(pick(local: localTombstone, remote: remoteTombstone), localTombstone)
    }

    func testEqualTimestampsPreferTombstone() {
        let id = UUID()
        let sameTime = date(offset: 300)

        let localActive = MergeFixture(id: id, updatedAt: sameTime, isDeleted: false)
        let remoteTombstone = MergeFixture(id: id, updatedAt: sameTime, isDeleted: true)
        XCTAssertEqual(pick(local: localActive, remote: remoteTombstone), remoteTombstone)

        let localTombstone = MergeFixture(id: id, updatedAt: sameTime, isDeleted: true)
        let remoteActive = MergeFixture(id: id, updatedAt: sameTime, isDeleted: false)
        XCTAssertEqual(pick(local: localTombstone, remote: remoteActive), localTombstone)
    }
}
