import SwiftUI
import Combine

enum SessionKind: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength"
    case run = "Run"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .run: return "figure.run"
        }
    }
}

enum PlanStatus: String, CaseIterable, Codable {
    case planned = "Planned"
    case completed = "Completed"
    case unplanned = "Unplanned"

    var tint: Color {
        switch self {
        case .planned: return .blue.opacity(0.8)
        case .completed: return .green.opacity(0.85)
        case .unplanned: return .orange.opacity(0.85)
        }
    }
}

struct PlannedSession: Identifiable, Codable {
    let id: UUID
    var title: String
    var kind: SessionKind
    var status: PlanStatus
    var note: String?
    var templateName: String?

    init(id: UUID = UUID(), title: String, kind: SessionKind, status: PlanStatus = .planned, note: String? = nil, templateName: String? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.status = status
        self.note = note
        self.templateName = templateName
    }
}

struct DayPlan: Identifiable, Codable {
    let id: UUID
    let date: Date
    var sessions: [PlannedSession]

    init(id: UUID = UUID(), date: Date, sessions: [PlannedSession] = []) {
        self.id = id
        self.date = date
        self.sessions = sessions
    }
}

struct WeekPlan: Codable {
    let startOfWeek: Date
    var days: [DayPlan]
}

enum TemplateCategory: String, CaseIterable, Identifiable, Codable {
    case strength = "Strength"
    case run = "Run"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell"
        case .run: return "figure.run"
        }
    }
}

struct StrengthTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: TemplateCategory
    var exercises: [StrengthExercise]
    var note: String?

    init(id: UUID = UUID(), name: String, category: TemplateCategory, exercises: [StrengthExercise], note: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.exercises = exercises
        self.note = note
    }
}

struct StrengthExercise: Identifiable, Codable {
    let id: UUID
    var name: String
    var sets: [StrengthSetTemplate]

    init(id: UUID = UUID(), name: String, sets: [StrengthSetTemplate]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct StrengthSetTemplate: Identifiable, Codable {
    let id: UUID
    var targetReps: Int
    var targetWeight: Double
    var targetRPE: Double?
    var repRange: String?

    init(id: UUID = UUID(), targetReps: Int, targetWeight: Double, targetRPE: Double? = nil, repRange: String? = nil) {
        self.id = id
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetRPE = targetRPE
        self.repRange = repRange
    }
}

struct NewExerciseInput: Identifiable {
    let id = UUID()
    var name: String
    var setsCount: Int
    var repRange: String
    var createdAt: Date = Date()
}

final class TemplateLibraryViewModel: ObservableObject {
    @Published var templates: [StrengthTemplate]

    private static var storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("templates.json")
    }()

    init(templates: [StrengthTemplate]? = nil) {
        if let templates {
            self.templates = templates
        } else if let loaded = TemplateLibraryViewModel.loadPersistedTemplates() {
            self.templates = loaded
        } else {
            let samples = TemplateLibraryViewModel.makeSamples()
            self.templates = samples
            persistTemplates()
        }
    }

    func addTemplate(name: String, note: String?, category: TemplateCategory, exercises: [StrengthExercise]) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let cleanedNote: String?
        if let note {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedNote = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            cleanedNote = nil
        }

        let newTemplate = StrengthTemplate(name: trimmedName, category: category, exercises: exercises, note: cleanedNote)
        templates.append(newTemplate)
        persistTemplates()
    }

    func deleteTemplate(id: UUID) {
        templates.removeAll { $0.id == id }
        persistTemplates()
    }

    static func makeSamples() -> [StrengthTemplate] {
        [
            StrengthTemplate(
                name: "Upper Push",
                category: .strength,
                exercises: [
                    StrengthExercise(
                        name: "Bench Press",
                        sets: [
                            StrengthSetTemplate(targetReps: 8, targetWeight: 135, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 8, targetWeight: 140, targetRPE: 8.0),
                            StrengthSetTemplate(targetReps: 8, targetWeight: 145, targetRPE: 8.5)
                        ]
                    ),
                    StrengthExercise(
                        name: "Overhead Press",
                        sets: [
                            StrengthSetTemplate(targetReps: 10, targetWeight: 75, targetRPE: 7.0),
                            StrengthSetTemplate(targetReps: 10, targetWeight: 80, targetRPE: 7.5)
                        ]
                    )
                ],
                note: "Baseline template for push focus days."
            ),
            StrengthTemplate(
                name: "Lower Mixed",
                category: .strength,
                exercises: [
                    StrengthExercise(
                        name: "Back Squat",
                        sets: [
                            StrengthSetTemplate(targetReps: 6, targetWeight: 185, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 6, targetWeight: 195, targetRPE: 8.0)
                        ]
                    ),
                    StrengthExercise(
                        name: "Romanian Deadlift",
                        sets: [
                            StrengthSetTemplate(targetReps: 10, targetWeight: 155, targetRPE: 7.5),
                            StrengthSetTemplate(targetReps: 10, targetWeight: 160, targetRPE: 8.0)
                        ]
                    )
                ],
                note: "Hybrid lower day with hinge + squat."
            )
        ]
    }

    private func persistTemplates() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(templates)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist templates: \(error)")
        }
    }

    private static func loadPersistedTemplates() -> [StrengthTemplate]? {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode([StrengthTemplate].self, from: data)
        } catch {
            print("Failed to load templates: \(error)")
            return nil
        }
    }
}

final class WeekPlannerViewModel: ObservableObject {
    private let calendar: Calendar

    @Published var weekPlan: WeekPlan
    private static var storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("weekplan.json")
    }()

    init(calendar: Calendar = .current, templates: [StrengthTemplate]) {
        self.calendar = calendar
        if let loaded = WeekPlannerViewModel.loadPersistedWeek() {
            self.weekPlan = loaded
        } else {
            let sample = WeekPlannerViewModel.makeSampleWeek(calendar: calendar, templates: templates)
            self.weekPlan = sample
            persistWeek()
        }
    }

    func addStrengthSession(template: StrengthTemplate, on date: Date) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: template.name,
                kind: .strength,
                status: .planned,
                note: "From template",
                templateName: template.name
            )
        )
        persistWeek()
    }

    func addRun(on date: Date, title: String = "Run", planned: Bool = true) {
        guard let dayIndex = dayIndex(for: date) else { return }
        weekPlan.days[dayIndex].sessions.append(
            PlannedSession(
                title: title,
                kind: .run,
                status: planned ? .planned : .unplanned,
                note: planned ? "Attach the detected HealthKit run" : "Logged from detected run"
            )
        )
        persistWeek()
    }

    func toggleStatus(sessionID: UUID) {
        for dayIdx in weekPlan.days.indices {
            if let sessionIndex = weekPlan.days[dayIdx].sessions.firstIndex(where: { $0.id == sessionID }) {
                let status = weekPlan.days[dayIdx].sessions[sessionIndex].status
                switch status {
                case .unplanned:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .planned
                case .planned:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .completed
                case .completed:
                    weekPlan.days[dayIdx].sessions[sessionIndex].status = .planned
                }
                persistWeek()
                break
            }
        }
    }

    func removeSession(dayID: UUID, sessionID: UUID) {
        guard let dayIndex = weekPlan.days.firstIndex(where: { $0.id == dayID }) else { return }
        weekPlan.days[dayIndex].sessions.removeAll { $0.id == sessionID }
        persistWeek()
    }

    private func dayIndex(for date: Date) -> Int? {
        weekPlan.days.firstIndex { calendar.isDate($0.date, inSameDayAs: date) }
    }

    static func makeSampleWeek(calendar: Calendar, templates: [StrengthTemplate]) -> WeekPlan {
        let start = calendar.startOfWeek(for: Date())
        let days: [DayPlan] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            var sessions: [PlannedSession] = []
            if offset == 0, let template = templates.first {
                sessions.append(
                    PlannedSession(
                        title: template.name,
                        kind: .strength,
                        status: .planned,
                        note: "Tap to log sets and mark complete",
                        templateName: template.name
                    )
                )
            }
            if offset == 2 {
                sessions.append(
                    PlannedSession(
                        title: "Easy Run 4 mi",
                        kind: .run,
                        status: .planned,
                        note: "Will prompt to attach when HealthKit run is detected"
                    )
                )
            }
            if offset == 4, templates.count > 1 {
                sessions.append(
                    PlannedSession(
                        title: templates[1].name,
                        kind: .strength,
                        status: .planned,
                        note: "Use template for progressive overload",
                        templateName: templates[1].name
                    )
                )
            }
            return DayPlan(date: date, sessions: sessions)
        }
        return WeekPlan(startOfWeek: start, days: days)
    }

    private func persistWeek() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        do {
            let data = try encoder.encode(weekPlan)
            try data.write(to: Self.storageURL, options: .atomic)
        } catch {
            print("Failed to persist week: \(error)")
        }
    }

    private static func loadPersistedWeek() -> WeekPlan? {
        let url = storageURL
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(WeekPlan.self, from: data)
        } catch {
            print("Failed to load week: \(error)")
            return nil
        }
    }
}

struct ContentView: View {
    @StateObject private var templatesViewModel: TemplateLibraryViewModel
    @StateObject private var weekViewModel: WeekPlannerViewModel

    init() {
        let templatesVM = TemplateLibraryViewModel()
        _templatesViewModel = StateObject(wrappedValue: templatesVM)
        _weekViewModel = StateObject(wrappedValue: WeekPlannerViewModel(templates: templatesVM.templates))
    }

    var body: some View {
        TabView {
            NavigationStack {
                WeekPlannerView(viewModel: weekViewModel, templatesViewModel: templatesViewModel)
            }
            .tabItem {
                Label("Week", systemImage: "calendar")
            }

            NavigationStack {
                TemplateLibraryView(viewModel: templatesViewModel)
            }
            .tabItem {
                Label("Templates", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct WeekPlannerView: View {
    @ObservedObject var viewModel: WeekPlannerViewModel
    @ObservedObject var templatesViewModel: TemplateLibraryViewModel
    @State private var showingTemplatePicker = false
    @State private var templatePickerDate: Date?

    var body: some View {
        List {
            ForEach(viewModel.weekPlan.days) { day in
                Section(header: Text(dayHeader(for: day.date))) {
                    if day.sessions.isEmpty {
                        Text("No sessions planned").foregroundStyle(.secondary)
                    } else {
                        ForEach(day.sessions) { session in
                            if session.kind == .strength {
                                NavigationLink {
                                    StrengthLogView(
                                        session: session,
                                        template: templatesViewModel.templates.first(where: { $0.name == session.templateName })
                                    )
                                } label: {
                                    SessionRow(
                                        session: session,
                                        onToggle: { viewModel.toggleStatus(sessionID: session.id) },
                                        onDelete: { viewModel.removeSession(dayID: day.id, sessionID: session.id) }
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                SessionRow(
                                    session: session,
                                    onToggle: { viewModel.toggleStatus(sessionID: session.id) },
                                    onDelete: { viewModel.removeSession(dayID: day.id, sessionID: session.id) }
                                )
                            }
                        }
                    }

                    Menu("Add workout") {
                        Button {
                            templatePickerDate = day.date
                            showingTemplatePicker = true
                        } label: {
                            Label("Strength (choose template)", systemImage: SessionKind.strength.systemImage)
                        }
                        Button {
                            viewModel.addRun(on: day.date, title: "Planned Run", planned: true)
                        } label: {
                            Label("Planned run", systemImage: SessionKind.run.systemImage)
                        }
                        Button {
                            viewModel.addRun(on: day.date, title: "Detected run", planned: false)
                        } label: {
                            Label("Attach detected run", systemImage: "bolt.heart")
                        }
                    }
                }
            }
        }
        .navigationTitle("This Week")
        .sheet(isPresented: $showingTemplatePicker) {
            NavigationStack {
                List {
                    ForEach(templatesViewModel.templates) { template in
                        Button {
                            if let date = templatePickerDate {
                                viewModel.addStrengthSession(template: template, on: date)
                            }
                            showingTemplatePicker = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.body.weight(.semibold))
                                if let note = template.note {
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Select template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingTemplatePicker = false
                        }
                    }
                }
            }
        }
    }

    private func dayHeader(for date: Date) -> String {
        let dayString = dayFormatter.string(from: date)
        let short = shortDayFormatter.string(from: date)
        return "\(short) • \(dayString)"
    }
}

struct SessionRow: View {
    let session: PlannedSession
    let onToggle: () -> Void
    let onDelete: () -> Void

    private var leadingLabel: String {
        switch session.status {
        case .unplanned:
            return "Mark Planned"
        case .planned:
            return "Mark Complete"
        case .completed:
            return "Mark Planned"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: session.kind.systemImage)
                .foregroundStyle(session.kind == .strength ? .blue : .purple)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                if let template = session.templateName {
                    Text(template)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let note = session.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(session.status.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(session.status.tint.opacity(0.15))
                .foregroundStyle(session.status.tint)
                .clipShape(Capsule())
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(leadingLabel, systemImage: session.status == .completed ? "arrow.uturn.left" : "checkmark.circle")
            }
            .tint(session.status == .completed ? .blue : .green)
        }
    }
}

struct TemplateLibraryView: View {
    @ObservedObject var viewModel: TemplateLibraryViewModel
    @State private var showingAddSheet = false
    @State private var newTemplateName: String = ""
    @State private var newTemplateNote: String = ""
    @State private var newTemplateCategory: TemplateCategory = .strength
    @State private var newExercises: [NewExerciseInput] = []
    @State private var newExerciseName: String = ""
    @State private var newExerciseSetsCount: String = ""
    @State private var newExerciseMinReps: Int = 6
    @State private var newExerciseMaxReps: Int = 10
    @State private var templatePendingDelete: StrengthTemplate?
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            ForEach(viewModel.templates) { template in
                NavigationLink {
                    TemplateDetailView(template: template)
                } label: {
                    VStack(alignment: .leading) {
                        Text(template.name)
                            .font(.headline)
                        Label(template.category.rawValue, systemImage: template.category.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let note = template.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(template.exercises.count) exercises")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        templatePendingDelete = template
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
            }
        }
        .alert("Delete template?", isPresented: $showingDeleteAlert, presenting: templatePendingDelete) { template in
            Button("Delete", role: .destructive) {
                viewModel.deleteTemplate(id: template.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: { template in
            Text("This will remove \(template.name). This action cannot be undone.")
        }
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                Form {
                    Section("Category") {
                        Picker("Template Type", selection: $newTemplateCategory) {
                            ForEach(TemplateCategory.allCases) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Template Info") {
                        TextField("Name", text: $newTemplateName)
                        TextField("Note (optional)", text: $newTemplateNote, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                    }
                    if newTemplateCategory == .strength {
                        Section("Lifts & sets") {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Lift name", text: $newExerciseName)
                                TextField("Number of sets", text: $newExerciseSetsCount)
                                    .keyboardType(.numberPad)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Rep range")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Picker("Min reps", selection: $newExerciseMinReps) {
                                            ForEach(1...30, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                        Text("to")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Picker("Max reps", selection: $newExerciseMaxReps) {
                                            ForEach(1...30, id: \.self) { value in
                                                Text("\(value)").tag(value)
                                            }
                                        }
                                        .pickerStyle(.wheel)
                                    }
                                    .frame(height: 120)
                                    if newExerciseMinReps >= newExerciseMaxReps {
                                        Text("Min must be less than max")
                                            .font(.caption2)
                                            .foregroundStyle(.red)
                                    }
                                }
                                Button {
                                    addExercise()
                                } label: {
                                    Label("Add lift", systemImage: "plus.circle.fill")
                                }
                                .disabled(newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(newExerciseSetsCount) == nil || newExerciseMinReps >= newExerciseMaxReps)
                            }
                            if !newExercises.isEmpty {
                                ForEach(newExercises) { exercise in
                                    HStack(alignment: .center, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(exercise.setsCount) sets • \(exercise.repRange)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "line.3.horizontal")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .onMove(perform: moveExercises)
                                Text("Drag the hamburger icon to reorder")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .environment(\.editMode, .constant(.active))
                    }
                }
                .navigationTitle("New Template")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismissSheet() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveTemplate()
                        }
                        .disabled(isSaveDisabled)
                    }
                }
            }
        }
    }

    private func saveTemplate() {
        let exercises: [StrengthExercise]
        if newTemplateCategory == .strength {
            exercises = newExercises.map { input in
                let sets = (0..<input.setsCount).map { _ in
                    StrengthSetTemplate(targetReps: 0, targetWeight: 0, targetRPE: nil, repRange: input.repRange)
                }
                return StrengthExercise(name: input.name, sets: sets)
            }
        } else {
            exercises = []
        }

        viewModel.addTemplate(name: newTemplateName, note: newTemplateNote, category: newTemplateCategory, exercises: exercises)
        dismissSheet()
    }

    private func dismissSheet() {
        showingAddSheet = false
        newTemplateName = ""
        newTemplateNote = ""
        newTemplateCategory = .strength
        newExercises = []
        newExerciseName = ""
        newExerciseSetsCount = ""
        newExerciseMinReps = 6
        newExerciseMaxReps = 10
    }

    private func addExercise() {
        guard let setsCount = Int(newExerciseSetsCount), setsCount > 0 else { return }
        let trimmedName = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, newExerciseMinReps < newExerciseMaxReps else { return }
        let rangeText = "\(newExerciseMinReps)-\(newExerciseMaxReps)"
        let input = NewExerciseInput(name: trimmedName, setsCount: setsCount, repRange: rangeText, createdAt: Date())
        newExercises.append(input)
        newExerciseName = ""
        newExerciseSetsCount = ""
        newExerciseMinReps = 6
        newExerciseMaxReps = 10
    }

    private func moveExercises(from offsets: IndexSet, to destination: Int) {
        newExercises.move(fromOffsets: offsets, toOffset: destination)
    }

    private var isSaveDisabled: Bool {
        let trimmedName = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return true }
        if newTemplateCategory == .strength {
            return newExercises.isEmpty
        }
        return false
    }
}

struct TemplateDetailView: View {
    let template: StrengthTemplate

    var body: some View {
        List {
            Section {
                Label(template.category.rawValue, systemImage: template.category.systemImage)
            }
            if let note = template.note {
                Section("Notes") {
                    Text(note)
                }
            }
            ForEach(template.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(exercise.sets) { set in
                        HStack {
                            if let repRange = set.repRange {
                                Text("\(repRange) reps")
                            } else {
                                Text("\(set.targetReps) reps")
                            }
                            Spacer()
                            if set.targetWeight > 0 {
                                Text("\(Int(set.targetWeight)) lb")
                                    .foregroundStyle(.secondary)
                            }
                            if let rpe = set.targetRPE {
                                Text("RPE \(String(format: "%.1f", rpe))")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(template.name)
    }
}

struct SettingsView: View {
    var body: some View {
        List {
            Section("HealthKit") {
                Label("Runs are read from HealthKit only", systemImage: "shield.lefthalf.filled")
                Label("Grant run + HR read access in Settings", systemImage: "heart.text.square")
            }
            Section("Coming soon") {
                Label("Attach detected runs to planned days", systemImage: "bolt.heart")
                Label("Log strength sets with weight/reps/RPE", systemImage: "list.bullet.clipboard")
            }
        }
        .navigationTitle("Settings")
    }
}

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

private let shortDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter
}()

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        var calendar = self
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

#Preview {
    ContentView()
}

