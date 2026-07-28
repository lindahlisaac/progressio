import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    private init() {}

    /// Activity types included in Settings discovery → Unattached pipeline.
    /// StairMaster maps from `.stairClimbing` and `.stairs` (documented in ImplementationNotes).
    private static let importActivityTypes: [HKWorkoutActivityType] = [
        .running,
        .stairClimbing,
        .stairs
    ]

    private var readTypes: Set<HKObjectType> {
        return [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
    }

    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            DispatchQueue.main.async {
                completion(success, error)
            }
        }
    }

    func fetchRecentRunCandidates(
        since startDate: Date?,
        limit: Int = 50,
        completion: @escaping ([HealthKitImportCandidate]) -> Void
    ) {
        let typePredicates = Self.importActivityTypes.map { HKQuery.predicateForWorkouts(with: $0) }
        var predicates: [NSPredicate] = [
            NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
        ]
        if let startDate {
            predicates.append(
                HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
            )
        }
        let datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: datePredicate,
            limit: limit,
            sortDescriptors: [sort]
        ) { [weak self] _, samples, error in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            guard error == nil, let workouts = samples as? [HKWorkout] else {
                if let error {
                    print("HK fetch error: \(error)")
                }
                DispatchQueue.main.async { completion([]) }
                return
            }
            let candidates = workouts.compactMap { self.makeCandidate(from: $0) }
            DispatchQueue.main.async {
                completion(candidates)
            }
        }
        healthStore.execute(query)
    }

    /// Legacy bridge used by older call sites; prefer `fetchRecentRunCandidates`.
    func fetchRecentRuns(since startDate: Date?, limit: Int = 50, completion: @escaping ([UnattachedRun]) -> Void) {
        fetchRecentRunCandidates(since: startDate, limit: limit) { candidates in
            completion(candidates.map(\.unattachedRun))
        }
    }

    /// Clears any previously enabled HealthKit background delivery (from older observer builds).
    func disableBackgroundDeliveryIfNeeded() {
        stopObservingRuns()
        healthStore.disableBackgroundDelivery(for: .workoutType()) { _, error in
            if let error {
                print("HK disable background delivery: \(error.localizedDescription)")
            }
        }
    }

    func stopObservingRuns() {
        if let observerQuery {
            healthStore.stop(observerQuery)
            self.observerQuery = nil
        }
    }

    /// Not used by the app (imports are Settings-triggered). Kept for possible future use;
    /// stores the query so it can be stopped and does not enable `.immediate` delivery.
    func startObservingRuns(onUpdate: @escaping () -> Void) {
        stopObservingRuns()
        let typePredicates = Self.importActivityTypes.map { HKQuery.predicateForWorkouts(with: $0) }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: typePredicates)
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: predicate) { _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            DispatchQueue.main.async {
                onUpdate()
            }
        }
        observerQuery = query
        healthStore.execute(query)
    }

    private func makeCandidate(from workout: HKWorkout) -> HealthKitImportCandidate? {
        guard let activityType = Self.mapActivityType(workout.workoutActivityType) else { return nil }

        let distanceMi: String = {
            if activityType == .stairMaster { return "" }
            if let dist = workout.totalDistance?.doubleValue(for: .meter()) {
                let miles = dist / 1609.344
                return String(format: "%.2f", miles)
            }
            return ""
        }()

        let durationString: String = {
            let seconds = Int(workout.duration)
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            let s = seconds % 60
            return String(format: "%02d:%02d:%02d", h, m, s)
        }()

        let elevation: String? = {
            // Prefer flights × ~10 ft when flights are available; otherwise leave nil.
            if let flights = workout.totalFlightsClimbed?.doubleValue(for: .count()), flights > 0 {
                return String(Int((flights * 10).rounded()))
            }
            return nil
        }()

        let detail = RunDetailData(
            title: activityType.defaultTitle,
            notes: "",
            distance: distanceMi,
            duration: durationString,
            averageHR: "",
            category: nil,
            hkWorkoutUUID: workout.uuid.uuidString,
            elevationGain: elevation,
            eventDate: workout.startDate
        )

        return HealthKitImportCandidate(
            healthKitUUID: workout.uuid.uuidString,
            startDate: workout.startDate,
            activityType: activityType,
            detail: detail,
            sourceName: workout.sourceRevision.source.name
        )
    }

    private static func mapActivityType(_ hkType: HKWorkoutActivityType) -> ActivityType? {
        switch hkType {
        case .running:
            return .roadRun
        case .stairClimbing, .stairs:
            return .stairMaster
        default:
            return nil
        }
    }
}
