import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    private init() {}

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

    func fetchRecentRuns(since startDate: Date?, limit: Int = 50, completion: @escaping ([UnattachedRun]) -> Void) {
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let datePredicate: NSPredicate?
        if let startDate {
            datePredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                predicate,
                HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
            ])
        } else {
            datePredicate = predicate
        }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: .workoutType(), predicate: datePredicate, limit: limit, sortDescriptors: [sort]) { [weak self] _, samples, error in
            guard let self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            guard error == nil, let workouts = samples as? [HKWorkout] else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            let runs = workouts.map { workout in
                self.makeUnattachedRun(from: workout)
            }
            DispatchQueue.main.async {
                completion(runs)
            }
        }
        healthStore.execute(query)
    }

    func startObservingRuns(onUpdate: @escaping () -> Void) {
        let predicate = HKQuery.predicateForWorkouts(with: .running)
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: predicate) { _, _, error in
            if error == nil {
                DispatchQueue.main.async {
                    onUpdate()
                }
            }
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error: \(error)")
            } else {
                print("Background delivery \(success ? "enabled" : "not enabled")")
            }
        }
    }

    private func makeUnattachedRun(from workout: HKWorkout) -> UnattachedRun {
        let title = workout.workoutActivityType == .running ? "Run" : workout.workoutActivityType.name
        let distanceMi: String = {
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

        let avgHR: String = "" // Will be populated when querying heart rate samples if available

        let detail = RunDetailData(
            title: title,
            notes: "",
            distance: distanceMi,
            duration: durationString,
            averageHR: avgHR,
            category: nil,
            hkWorkoutUUID: workout.uuid.uuidString,
            elevationGain: nil,
            eventDate: workout.startDate
        )

        return UnattachedRun(detail: detail, date: workout.startDate, source: workout.sourceRevision.source.name)
    }
}

private extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Run"
        default: return "Workout"
        }
    }
}

