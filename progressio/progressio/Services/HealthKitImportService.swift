import Foundation
import HealthKit

/// Single entry point for Settings-triggered HealthKit imports (manual Unattached queue).
final class HealthKitImportService {
    static let shared = HealthKitImportService()

    /// Shared lookback for Settings import.
    static let defaultLookbackDays = 7

    private let healthKit: HealthKitManager
    private var lastFetchedUUIDFingerprint: String?

    private init(healthKit: HealthKitManager = .shared) {
        self.healthKit = healthKit
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        healthKit.requestAuthorization(completion: completion)
    }

    func startObserving(onUpdate: @escaping () -> Void) {
        healthKit.startObservingRuns(onUpdate: onUpdate)
    }

    func stopObserving() {
        healthKit.stopObservingRuns()
    }

    /// Fetches recent running workouts and maps them to import candidates.
    /// Skips the mapping work when the UUID set matches the previous fetch (observer noise).
    func fetchCandidates(
        lookbackDays: Int = HealthKitImportService.defaultLookbackDays,
        completion: @escaping ([HealthKitImportCandidate]) -> Void
    ) {
        let since = Calendar.current.date(byAdding: .day, value: -lookbackDays, to: Date())
        healthKit.fetchRecentRunCandidates(since: since) { [weak self] candidates in
            guard let self else {
                completion([])
                return
            }
            let fingerprint = Self.fingerprint(for: candidates)
            if fingerprint == self.lastFetchedUUIDFingerprint, !candidates.isEmpty {
                print("HK import: observer refetch unchanged (\(candidates.count) UUID(s)); skipping reprocess")
                completion([])
                return
            }
            self.lastFetchedUUIDFingerprint = fingerprint
            print("HK import: fetched \(candidates.count) candidate(s) (lookback \(lookbackDays)d)")
            completion(candidates)
        }
    }

    /// Force fetch without the observer fingerprint short-circuit (Settings manual import).
    func fetchCandidatesForcingRefresh(
        lookbackDays: Int = HealthKitImportService.defaultLookbackDays,
        completion: @escaping ([HealthKitImportCandidate]) -> Void
    ) {
        lastFetchedUUIDFingerprint = nil
        fetchCandidates(lookbackDays: lookbackDays, completion: completion)
    }

    private static func fingerprint(for candidates: [HealthKitImportCandidate]) -> String {
        candidates.map(\.healthKitUUID).sorted().joined(separator: "|")
    }
}
