import Foundation

// MARK: - Store protocols

protocol ActivityReflectionStore {
    func load() -> [ActivityReflection]
    func save(_ items: [ActivityReflection])
}

protocol WeeklyReflectionStore {
    func load() -> [WeeklyReflection]
    func save(_ items: [WeeklyReflection])
}

protocol PhysicalIssueStore {
    func load() -> [PhysicalIssue]
    func save(_ items: [PhysicalIssue])
}

protocol ActivityIssueReportStore {
    func load() -> [ActivityIssueReport]
    func save(_ items: [ActivityIssueReport])
}

protocol WeeklyIssueReviewStore {
    func load() -> [WeeklyIssueReview]
    func save(_ items: [WeeklyIssueReview])
}

// MARK: - File helpers

private enum JSONArrayFileStore {
    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> [T] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([T].self, from: data)
        } catch {
            print("Failed to load \(url.lastPathComponent): \(error)")
            return []
        }
    }

    static func save<T: Encodable>(_ items: [T], to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist \(url.lastPathComponent): \(error)")
        }
    }
}

struct FileActivityReflectionStore: ActivityReflectionStore {
    private let url = StoragePaths.file("activityReflections.json")
    func load() -> [ActivityReflection] { JSONArrayFileStore.load(ActivityReflection.self, from: url) }
    func save(_ items: [ActivityReflection]) { JSONArrayFileStore.save(items, to: url) }
}

struct FileWeeklyReflectionStore: WeeklyReflectionStore {
    private let url = StoragePaths.file("weeklyReflections.json")
    func load() -> [WeeklyReflection] { JSONArrayFileStore.load(WeeklyReflection.self, from: url) }
    func save(_ items: [WeeklyReflection]) { JSONArrayFileStore.save(items, to: url) }
}

struct FilePhysicalIssueStore: PhysicalIssueStore {
    private let url = StoragePaths.file("physicalIssues.json")
    func load() -> [PhysicalIssue] { JSONArrayFileStore.load(PhysicalIssue.self, from: url) }
    func save(_ items: [PhysicalIssue]) { JSONArrayFileStore.save(items, to: url) }
}

struct FileActivityIssueReportStore: ActivityIssueReportStore {
    private let url = StoragePaths.file("activityIssueReports.json")
    func load() -> [ActivityIssueReport] { JSONArrayFileStore.load(ActivityIssueReport.self, from: url) }
    func save(_ items: [ActivityIssueReport]) { JSONArrayFileStore.save(items, to: url) }
}

struct FileWeeklyIssueReviewStore: WeeklyIssueReviewStore {
    private let url = StoragePaths.file("weeklyIssueReviews.json")
    func load() -> [WeeklyIssueReview] { JSONArrayFileStore.load(WeeklyIssueReview.self, from: url) }
    func save(_ items: [WeeklyIssueReview]) { JSONArrayFileStore.save(items, to: url) }
}
