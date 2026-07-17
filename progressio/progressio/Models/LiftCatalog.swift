import Foundation

/// Primary muscle focus for catalog browsing / filtering.
enum LiftMuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case quads = "Quads"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case core = "Core"
    case olympic = "Olympic"
    case fullBody = "Full Body"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.hiking"
        case .shoulders: return "figure.arms.open"
        case .biceps, .triceps: return "figure.boxing"
        case .quads, .hamstrings, .glutes, .calves: return "figure.walk"
        case .core: return "figure.core.training"
        case .olympic: return "figure.highintensity.intervaltraining"
        case .fullBody: return "figure.mixed.cardio"
        }
    }
}

/// Canonical lift entry used by templates and history name matching.
struct CatalogLift: Identifiable, Hashable, Sendable {
    /// Stable slug id (not display name).
    let id: String
    let name: String
    let muscleGroup: LiftMuscleGroup
    /// Alternate spellings / abbreviations that normalize to `name`.
    let aliases: [String]

    init(id: String, name: String, muscleGroup: LiftMuscleGroup, aliases: [String] = []) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.aliases = aliases
    }
}

/// Shared lift vocabulary for template pickers and strength history matching.
enum LiftCatalog {
    static let all: [CatalogLift] = rawCatalog

    private static let byNormalizedKey: [String: CatalogLift] = {
        var map: [String: CatalogLift] = [:]
        for lift in rawCatalog {
            map[normalizeKey(lift.name)] = lift
            for alias in lift.aliases {
                map[normalizeKey(alias)] = lift
            }
        }
        return map
    }()

    static func lifts(in group: LiftMuscleGroup) -> [CatalogLift] {
        all.filter { $0.muscleGroup == group }
    }

    /// Fast substring search across name + aliases (case/whitespace insensitive).
    static func search(_ query: String) -> [CatalogLift] {
        let key = normalizeKey(query)
        guard !key.isEmpty else { return all }
        return all.filter { lift in
            normalizeKey(lift.name).contains(key)
                || lift.aliases.contains { normalizeKey($0).contains(key) }
        }
    }

    /// Maps free text / alias to canonical catalog name when known; otherwise returns trimmed original.
    static func canonicalName(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let lift = byNormalizedKey[normalizeKey(trimmed)] {
            return lift.name
        }
        return trimmed
    }

    static func catalogLift(matching raw: String) -> CatalogLift? {
        byNormalizedKey[normalizeKey(raw)]
    }

    static func normalizeKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "–", with: " ")
            .replacingOccurrences(of: "—", with: " ")
    }

    // MARK: - Catalog data (~180 common lifts)

    private static let rawCatalog: [CatalogLift] = [
        // MARK: Chest
        .init(id: "bench-press", name: "Bench Press", muscleGroup: .chest, aliases: ["Barbell Bench Press", "Flat Bench Press", "BB Bench"]),
        .init(id: "incline-bench-press", name: "Incline Bench Press", muscleGroup: .chest, aliases: ["Incline Barbell Bench", "Incline BB Bench"]),
        .init(id: "decline-bench-press", name: "Decline Bench Press", muscleGroup: .chest),
        .init(id: "dumbbell-bench-press", name: "Dumbbell Bench Press", muscleGroup: .chest, aliases: ["DB Bench Press", "Flat DB Press"]),
        .init(id: "incline-dumbbell-press", name: "Incline Dumbbell Press", muscleGroup: .chest, aliases: ["Incline DB Press"]),
        .init(id: "decline-dumbbell-press", name: "Decline Dumbbell Press", muscleGroup: .chest),
        .init(id: "dumbbell-fly", name: "Dumbbell Fly", muscleGroup: .chest, aliases: ["DB Fly", "Flat Dumbbell Flye", "Dumbbell Flye"]),
        .init(id: "incline-dumbbell-fly", name: "Incline Dumbbell Fly", muscleGroup: .chest, aliases: ["Incline DB Fly"]),
        .init(id: "cable-fly", name: "Cable Fly", muscleGroup: .chest, aliases: ["Cable Crossover", "Cable Chest Fly"]),
        .init(id: "pec-deck", name: "Pec Deck", muscleGroup: .chest, aliases: ["Machine Fly", "Pec Deck Fly"]),
        .init(id: "push-up", name: "Push-Up", muscleGroup: .chest, aliases: ["Push Up", "Pushups", "Push-Ups"]),
        .init(id: "diamond-push-up", name: "Diamond Push-Up", muscleGroup: .chest),
        .init(id: "chest-dip", name: "Chest Dip", muscleGroup: .chest, aliases: ["Dips Chest", "Parallel Bar Dip"]),
        .init(id: "machine-chest-press", name: "Machine Chest Press", muscleGroup: .chest, aliases: ["Chest Press Machine"]),
        .init(id: "smith-machine-bench-press", name: "Smith Machine Bench Press", muscleGroup: .chest),

        // MARK: Back
        .init(id: "deadlift", name: "Deadlift", muscleGroup: .back, aliases: ["Conventional Deadlift", "Barbell Deadlift"]),
        .init(id: "sumo-deadlift", name: "Sumo Deadlift", muscleGroup: .back),
        .init(id: "romanian-deadlift", name: "Romanian Deadlift", muscleGroup: .hamstrings, aliases: ["RDL", "Barbell RDL"]),
        .init(id: "stiff-leg-deadlift", name: "Stiff-Leg Deadlift", muscleGroup: .hamstrings, aliases: ["SLDL", "Stiff Leg Deadlift"]),
        .init(id: "pull-up", name: "Pull-Up", muscleGroup: .back, aliases: ["Pull Up", "Pullups", "Pull-Ups"]),
        .init(id: "chin-up", name: "Chin-Up", muscleGroup: .back, aliases: ["Chin Up", "Chinups"]),
        .init(id: "lat-pulldown", name: "Lat Pulldown", muscleGroup: .back, aliases: ["Lat Pull Down", "Lat Pull-Down", "Wide Grip Lat Pulldown"]),
        .init(id: "close-grip-lat-pulldown", name: "Close-Grip Lat Pulldown", muscleGroup: .back),
        .init(id: "barbell-row", name: "Barbell Row", muscleGroup: .back, aliases: ["Bent-Over Row", "Bent Over Barbell Row", "BB Row"]),
        .init(id: "pendlay-row", name: "Pendlay Row", muscleGroup: .back),
        .init(id: "dumbbell-row", name: "Dumbbell Row", muscleGroup: .back, aliases: ["One-Arm Dumbbell Row", "Single Arm DB Row", "DB Row"]),
        .init(id: "chest-supported-row", name: "Chest-Supported Row", muscleGroup: .back, aliases: ["Incline DB Row", "Supported Row"]),
        .init(id: "seated-cable-row", name: "Seated Cable Row", muscleGroup: .back, aliases: ["Cable Row", "Sitting Cable Row"]),
        .init(id: "t-bar-row", name: "T-Bar Row", muscleGroup: .back, aliases: ["T Bar Row"]),
        .init(id: "face-pull", name: "Face Pull", muscleGroup: .shoulders, aliases: ["Cable Face Pull"]),
        .init(id: "straight-arm-pulldown", name: "Straight-Arm Pulldown", muscleGroup: .back, aliases: ["Straight Arm Pulldown", "Lat Prayer"]),
        .init(id: "meadows-row", name: "Meadows Row", muscleGroup: .back),
        .init(id: "inverted-row", name: "Inverted Row", muscleGroup: .back, aliases: ["Bodyweight Row", "Australian Pull-Up"]),
        .init(id: "machine-row", name: "Machine Row", muscleGroup: .back, aliases: ["Hammer Strength Row"]),
        .init(id: "rack-pull", name: "Rack Pull", muscleGroup: .back),
        .init(id: "good-morning", name: "Good Morning", muscleGroup: .hamstrings, aliases: ["Barbell Good Morning"]),

        // MARK: Shoulders
        .init(id: "overhead-press", name: "Overhead Press", muscleGroup: .shoulders, aliases: ["OHP", "Military Press", "Barbell Overhead Press", "Strict Press"]),
        .init(id: "push-press", name: "Push Press", muscleGroup: .shoulders),
        .init(id: "seated-dumbbell-press", name: "Seated Dumbbell Press", muscleGroup: .shoulders, aliases: ["DB Shoulder Press", "Seated DB Press"]),
        .init(id: "standing-dumbbell-press", name: "Standing Dumbbell Press", muscleGroup: .shoulders),
        .init(id: "arnold-press", name: "Arnold Press", muscleGroup: .shoulders),
        .init(id: "lateral-raise", name: "Lateral Raise", muscleGroup: .shoulders, aliases: ["Side Raise", "Dumbbell Lateral Raise", "DB Lateral Raise"]),
        .init(id: "cable-lateral-raise", name: "Cable Lateral Raise", muscleGroup: .shoulders),
        .init(id: "front-raise", name: "Front Raise", muscleGroup: .shoulders, aliases: ["Dumbbell Front Raise"]),
        .init(id: "rear-delt-fly", name: "Rear Delt Fly", muscleGroup: .shoulders, aliases: ["Rear-delt Fly", "Reverse Fly", "Rear Delt Raise", "Bent-Over Reverse Fly", "Rear Delt Flye"]),
        .init(id: "rear-delt-fly-machine", name: "Rear Delt Fly (Machine)", muscleGroup: .shoulders, aliases: ["Rear-delt Fly (Machine)", "Machine Rear Delt Fly", "Rear Delt Fly Machine", "Reverse Pec Deck", "Rear Delt Machine"]),
        .init(id: "machine-shoulder-press", name: "Machine Shoulder Press", muscleGroup: .shoulders),
        .init(id: "upright-row", name: "Upright Row", muscleGroup: .shoulders),
        .init(id: "shrug", name: "Shrug", muscleGroup: .shoulders, aliases: ["Barbell Shrug", "Dumbbell Shrug", "Trap Shrug"]),
        .init(id: "landmine-press", name: "Landmine Press", muscleGroup: .shoulders),
        .init(id: "cuban-press", name: "Cuban Press", muscleGroup: .shoulders),

        // MARK: Biceps
        .init(id: "barbell-curl", name: "Barbell Curl", muscleGroup: .biceps, aliases: ["BB Curl", "Standing Barbell Curl"]),
        .init(id: "ez-bar-curl", name: "EZ-Bar Curl", muscleGroup: .biceps, aliases: ["EZ Bar Curl", "EZ Curl"]),
        .init(id: "dumbbell-curl", name: "Dumbbell Curl", muscleGroup: .biceps, aliases: ["DB Curl", "Standing Dumbbell Curl"]),
        .init(id: "hammer-curl", name: "Hammer Curl", muscleGroup: .biceps, aliases: ["DB Hammer Curl"]),
        .init(id: "incline-dumbbell-curl", name: "Incline Dumbbell Curl", muscleGroup: .biceps),
        .init(id: "preacher-curl", name: "Preacher Curl", muscleGroup: .biceps, aliases: ["EZ Preacher Curl"]),
        .init(id: "concentration-curl", name: "Concentration Curl", muscleGroup: .biceps),
        .init(id: "cable-curl", name: "Cable Curl", muscleGroup: .biceps, aliases: ["Standing Cable Curl"]),
        .init(id: "spider-curl", name: "Spider Curl", muscleGroup: .biceps),
        .init(id: "chin-up-biceps", name: "Close-Grip Chin-Up", muscleGroup: .biceps, aliases: ["Close Grip Chin Up"]),
        .init(id: "bayesian-curl", name: "Bayesian Curl", muscleGroup: .biceps, aliases: ["Cable Bayesian Curl"]),

        // MARK: Triceps
        .init(id: "tricep-pushdown", name: "Tricep Pushdown", muscleGroup: .triceps, aliases: ["Cable Pushdown", "Triceps Pushdown", "Rope Pushdown"]),
        .init(id: "overhead-tricep-extension", name: "Overhead Tricep Extension", muscleGroup: .triceps, aliases: ["French Press", "DB Overhead Extension"]),
        .init(id: "skull-crusher", name: "Skull Crusher", muscleGroup: .triceps, aliases: ["Lying Tricep Extension", "EZ Skull Crusher"]),
        .init(id: "close-grip-bench-press", name: "Close-Grip Bench Press", muscleGroup: .triceps, aliases: ["CGBP", "Close Grip Bench"]),
        .init(id: "diamond-push-up-triceps", name: "Close-Grip Push-Up", muscleGroup: .triceps),
        .init(id: "tricep-dip", name: "Tricep Dip", muscleGroup: .triceps, aliases: ["Bench Dip", "Dips Triceps"]),
        .init(id: "kickback", name: "Tricep Kickback", muscleGroup: .triceps, aliases: ["Dumbbell Kickback"]),
        .init(id: "jm-press", name: "JM Press", muscleGroup: .triceps),
        .init(id: "cable-overhead-extension", name: "Cable Overhead Extension", muscleGroup: .triceps),

        // MARK: Quads
        .init(id: "back-squat", name: "Back Squat", muscleGroup: .quads, aliases: ["Barbell Squat", "Squat", "High Bar Squat", "Low Bar Squat"]),
        .init(id: "front-squat", name: "Front Squat", muscleGroup: .quads),
        .init(id: "goblet-squat", name: "Goblet Squat", muscleGroup: .quads),
        .init(id: "leg-press", name: "Leg Press", muscleGroup: .quads),
        .init(id: "hack-squat", name: "Hack Squat", muscleGroup: .quads),
        .init(id: "leg-extension", name: "Leg Extension", muscleGroup: .quads, aliases: ["Quad Extension"]),
        .init(id: "bulgarian-split-squat", name: "Bulgarian Split Squat", muscleGroup: .quads, aliases: ["Rear Foot Elevated Split Squat", "RFESS"]),
        .init(id: "walking-lunge", name: "Walking Lunge", muscleGroup: .quads, aliases: ["Dumbbell Walking Lunge"]),
        .init(id: "reverse-lunge", name: "Reverse Lunge", muscleGroup: .quads),
        .init(id: "step-up", name: "Step-Up", muscleGroup: .quads, aliases: ["Dumbbell Step Up"]),
        .init(id: "sissy-squat", name: "Sissy Squat", muscleGroup: .quads),
        .init(id: "pendulum-squat", name: "Pendulum Squat", muscleGroup: .quads),
        .init(id: "belt-squat", name: "Belt Squat", muscleGroup: .quads),
        .init(id: "pistol-squat", name: "Pistol Squat", muscleGroup: .quads),
        .init(id: "smith-machine-squat", name: "Smith Machine Squat", muscleGroup: .quads),

        // MARK: Hamstrings
        .init(id: "lying-leg-curl", name: "Lying Leg Curl", muscleGroup: .hamstrings, aliases: ["Prone Leg Curl", "Hamstring Curl"]),
        .init(id: "seated-leg-curl", name: "Seated Leg Curl", muscleGroup: .hamstrings),
        .init(id: "nordic-curl", name: "Nordic Curl", muscleGroup: .hamstrings, aliases: ["Nordic Hamstring Curl"]),
        .init(id: "dumbbell-rdl", name: "Dumbbell Romanian Deadlift", muscleGroup: .hamstrings, aliases: ["DB RDL"]),
        .init(id: "single-leg-rdl", name: "Single-Leg Romanian Deadlift", muscleGroup: .hamstrings, aliases: ["Single Leg RDL"]),
        .init(id: "glute-ham-raise", name: "Glute-Ham Raise", muscleGroup: .hamstrings, aliases: ["GHR"]),
        .init(id: "cable-pull-through", name: "Cable Pull-Through", muscleGroup: .hamstrings, aliases: ["Pull Through"]),

        // MARK: Glutes
        .init(id: "hip-thrust", name: "Hip Thrust", muscleGroup: .glutes, aliases: ["Barbell Hip Thrust"]),
        .init(id: "glute-bridge", name: "Glute Bridge", muscleGroup: .glutes),
        .init(id: "cable-kickback", name: "Cable Glute Kickback", muscleGroup: .glutes, aliases: ["Glute Kickback"]),
        .init(id: "hip-abduction", name: "Hip Abduction", muscleGroup: .glutes, aliases: ["Abductor Machine", "Cable Hip Abduction"]),
        .init(id: "hip-adduction", name: "Hip Adduction", muscleGroup: .glutes, aliases: ["Adductor Machine"]),
        .init(id: "frog-pump", name: "Frog Pump", muscleGroup: .glutes),
        .init(id: "smith-hip-thrust", name: "Smith Machine Hip Thrust", muscleGroup: .glutes),
        .init(id: "kas-glute-bridge", name: "Kas Glute Bridge", muscleGroup: .glutes),

        // MARK: Calves
        .init(id: "standing-calf-raise", name: "Standing Calf Raise", muscleGroup: .calves, aliases: ["Calf Raise"]),
        .init(id: "seated-calf-raise", name: "Seated Calf Raise", muscleGroup: .calves),
        .init(id: "leg-press-calf-raise", name: "Leg Press Calf Raise", muscleGroup: .calves),
        .init(id: "donkey-calf-raise", name: "Donkey Calf Raise", muscleGroup: .calves),
        .init(id: "single-leg-calf-raise", name: "Single-Leg Calf Raise", muscleGroup: .calves),

        // MARK: Core
        .init(id: "plank", name: "Plank", muscleGroup: .core),
        .init(id: "side-plank", name: "Side Plank", muscleGroup: .core),
        .init(id: "hanging-leg-raise", name: "Hanging Leg Raise", muscleGroup: .core, aliases: ["Hanging Knee Raise"]),
        .init(id: "captains-chair-leg-raise", name: "Captain's Chair Leg Raise", muscleGroup: .core),
        .init(id: "cable-crunch", name: "Cable Crunch", muscleGroup: .core, aliases: ["Kneeling Cable Crunch"]),
        .init(id: "ab-wheel", name: "Ab Wheel Rollout", muscleGroup: .core, aliases: ["Ab Wheel", "Rollout"]),
        .init(id: "dead-bug", name: "Dead Bug", muscleGroup: .core),
        .init(id: "bird-dog", name: "Bird Dog", muscleGroup: .core),
        .init(id: "russian-twist", name: "Russian Twist", muscleGroup: .core),
        .init(id: "pallof-press", name: "Pallof Press", muscleGroup: .core),
        .init(id: "sit-up", name: "Sit-Up", muscleGroup: .core, aliases: ["Sit Up"]),
        .init(id: "crunch", name: "Crunch", muscleGroup: .core),
        .init(id: "decline-sit-up", name: "Decline Sit-Up", muscleGroup: .core),
        .init(id: "toes-to-bar", name: "Toes-to-Bar", muscleGroup: .core, aliases: ["Toes to Bar", "T2B"]),
        .init(id: "dragon-flag", name: "Dragon Flag", muscleGroup: .core),
        .init(id: "woodchop", name: "Cable Woodchop", muscleGroup: .core, aliases: ["Woodchopper"]),

        // MARK: Olympic / power
        .init(id: "power-clean", name: "Power Clean", muscleGroup: .olympic),
        .init(id: "hang-clean", name: "Hang Clean", muscleGroup: .olympic),
        .init(id: "clean-and-jerk", name: "Clean and Jerk", muscleGroup: .olympic, aliases: ["Clean & Jerk"]),
        .init(id: "snatch", name: "Snatch", muscleGroup: .olympic),
        .init(id: "hang-snatch", name: "Hang Snatch", muscleGroup: .olympic),
        .init(id: "power-snatch", name: "Power Snatch", muscleGroup: .olympic),
        .init(id: "clean-pull", name: "Clean Pull", muscleGroup: .olympic),
        .init(id: "snatch-pull", name: "Snatch Pull", muscleGroup: .olympic),
        .init(id: "push-jerk", name: "Push Jerk", muscleGroup: .olympic),
        .init(id: "split-jerk", name: "Split Jerk", muscleGroup: .olympic),
        .init(id: "muscle-clean", name: "Muscle Clean", muscleGroup: .olympic),
        .init(id: "high-pull", name: "High Pull", muscleGroup: .olympic),

        // MARK: Full body / conditioning hybrids common in gyms
        .init(id: "kettlebell-swing", name: "Kettlebell Swing", muscleGroup: .fullBody, aliases: ["KB Swing", "Russian Swing", "American Swing"]),
        .init(id: "thruster", name: "Thruster", muscleGroup: .fullBody, aliases: ["Barbell Thruster"]),
        .init(id: "burpee", name: "Burpee", muscleGroup: .fullBody),
        .init(id: "farmer-carry", name: "Farmer Carry", muscleGroup: .fullBody, aliases: ["Farmer's Walk", "Farmers Walk"]),
        .init(id: "sled-push", name: "Sled Push", muscleGroup: .fullBody),
        .init(id: "sled-pull", name: "Sled Pull", muscleGroup: .fullBody),
        .init(id: "battle-rope", name: "Battle Ropes", muscleGroup: .fullBody),
        .init(id: "box-jump", name: "Box Jump", muscleGroup: .fullBody),
        .init(id: "medicine-ball-slam", name: "Medicine Ball Slam", muscleGroup: .fullBody, aliases: ["Med Ball Slam"]),
        .init(id: "turkish-get-up", name: "Turkish Get-Up", muscleGroup: .fullBody, aliases: ["TGU"]),
        .init(id: "man-maker", name: "Man Maker", muscleGroup: .fullBody),
        .init(id: "clean-and-press", name: "Clean and Press", muscleGroup: .fullBody),
    ]
}
