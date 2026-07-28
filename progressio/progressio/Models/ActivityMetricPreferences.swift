import Foundation
import Combine

/// Primary rollup / default-entry metric for an endurance activity type.
enum PrimaryMetric: String, Codable, CaseIterable, Identifiable {
    case distance
    case duration
    case elevation
    case level

    var id: String { rawValue }

    var settingsLabel: String {
        switch self {
        case .distance: return "Distance (mi)"
        case .duration: return "Time"
        case .elevation: return "Elevation (ft)"
        case .level: return "Level"
        }
    }

    var weekUnitLabel: String {
        switch self {
        case .distance: return "mi"
        case .duration: return "hr"
        case .elevation: return "ft"
        case .level: return "lvl"
        }
    }
}

/// UserDefaults-backed map of `ActivityType` → `PrimaryMetric` (solo v1 settings; not CloudKit).
final class ActivityMetricPreferenceStore: ObservableObject {
    static let shared = ActivityMetricPreferenceStore()

    static let enduranceTypes: [ActivityType] = [.roadRun, .trailRun, .walk, .bike, .stairMaster]

    private let defaults: UserDefaults
    private let keyPrefix = "progressio.primaryMetric."

    @Published private(set) var revision: Int = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    static func defaultMetric(for activity: ActivityType) -> PrimaryMetric {
        switch activity {
        case .roadRun, .trailRun, .walk:
            return .distance
        case .bike, .stairMaster:
            return .duration
        case .strength:
            return .duration
        }
    }

    static func allowedMetrics(for activity: ActivityType) -> [PrimaryMetric] {
        switch activity {
        case .roadRun, .trailRun, .walk, .bike:
            return [.distance, .duration, .elevation]
        case .stairMaster:
            return [.duration, .elevation, .level]
        case .strength:
            return []
        }
    }

    func primaryMetric(for activity: ActivityType) -> PrimaryMetric {
        let allowed = Self.allowedMetrics(for: activity)
        guard !allowed.isEmpty else { return Self.defaultMetric(for: activity) }
        let key = keyPrefix + activity.rawValue
        if let raw = defaults.string(forKey: key),
           let metric = PrimaryMetric(rawValue: raw),
           allowed.contains(metric) {
            return metric
        }
        return Self.defaultMetric(for: activity)
    }

    func setPrimaryMetric(_ metric: PrimaryMetric, for activity: ActivityType) {
        let allowed = Self.allowedMetrics(for: activity)
        guard allowed.contains(metric) else { return }
        defaults.set(metric.rawValue, forKey: keyPrefix + activity.rawValue)
        revision += 1
    }
}
