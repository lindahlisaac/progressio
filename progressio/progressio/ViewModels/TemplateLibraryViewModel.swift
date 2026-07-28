import Foundation
import Combine

final class TemplateLibraryViewModel: ObservableObject {
    @Published private(set) var templates: [StrengthTemplate]
    @Published private(set) var enduranceTemplates: [EnduranceTemplate]
    private let store: TemplateStore
    private let enduranceStore: EnduranceTemplateStore

    var activeTemplates: [StrengthTemplate] {
        templates.filter { !$0.isDeleted && $0.category == .strength }
    }

    var activeEnduranceTemplates: [EnduranceTemplate] {
        enduranceTemplates.filter { !$0.isDeleted }
    }

    init(
        store: TemplateStore = SyncingTemplateStore(),
        enduranceStore: EnduranceTemplateStore = SyncingEnduranceTemplateStore(),
        templates: [StrengthTemplate]? = nil,
        enduranceTemplates: [EnduranceTemplate]? = nil
    ) {
        self.store = store
        self.enduranceStore = enduranceStore
        if let templates {
            self.templates = templates
        } else if let loaded = store.loadTemplates() {
            self.templates = loaded
        } else {
            self.templates = TemplateLibraryViewModel.makeSamples()
        }

        if let enduranceTemplates {
            self.enduranceTemplates = enduranceTemplates
        } else if let loaded = enduranceStore.loadTemplates() {
            self.enduranceTemplates = loaded
        } else {
            self.enduranceTemplates = []
        }

        if templates == nil, store.loadTemplates() == nil {
            persistTemplates()
        }
    }

    func addTemplate(name: String, note: String?, exercises: [StrengthExercise]) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let cleanedNote: String?
        if let note {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedNote = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            cleanedNote = nil
        }

        var newTemplate = StrengthTemplate(
            name: trimmedName,
            category: .strength,
            exercises: exercises,
            note: cleanedNote,
            runCategory: nil
        )
        SyncMetadata.stampNewRecord(&newTemplate)
        templates.append(newTemplate)
        persistTemplates()
    }

    func addEnduranceTemplate(
        name: String,
        activityType: ActivityType,
        runType: RunType? = nil,
        plannedDistance: String? = nil,
        plannedDuration: String? = nil,
        plannedElevationGain: String? = nil,
        plannedLevel: String? = nil,
        description: String? = nil,
        intensityRPE: String? = nil,
        route: String? = nil
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var newTemplate = EnduranceTemplate(
            name: trimmedName,
            activityType: activityType,
            runType: activityType.usesRunType ? runType : nil,
            plannedDistance: plannedDistance,
            plannedDuration: plannedDuration,
            plannedElevationGain: plannedElevationGain,
            plannedLevel: plannedLevel,
            description: description,
            intensityRPE: intensityRPE,
            route: route
        )
        SyncMetadata.stampNewRecord(&newTemplate)
        enduranceTemplates.append(newTemplate)
        persistEnduranceTemplates()
    }

    func updateTemplate(_ updated: StrengthTemplate) {
        guard let idx = templates.firstIndex(where: { $0.id == updated.id }) else { return }
        var next = templates
        var stamped = updated
        SyncMetadata.stampSave(&stamped)
        next[idx] = stamped
        templates = next
        persistTemplates()
    }

    func updateEnduranceTemplate(_ updated: EnduranceTemplate) {
        guard let idx = enduranceTemplates.firstIndex(where: { $0.id == updated.id }) else { return }
        var next = enduranceTemplates
        var stamped = updated
        SyncMetadata.stampSave(&stamped)
        next[idx] = stamped
        enduranceTemplates = next
        persistEnduranceTemplates()
    }

    func deleteTemplate(id: UUID) {
        guard let idx = templates.firstIndex(where: { $0.id == id }) else { return }
        var next = templates
        next[idx] = SyncMetadata.softDelete(next[idx])
        templates = next
        persistTemplates()
    }

    func deleteEnduranceTemplate(id: UUID) {
        guard let idx = enduranceTemplates.firstIndex(where: { $0.id == id }) else { return }
        var next = enduranceTemplates
        next[idx] = SyncMetadata.softDelete(next[idx])
        enduranceTemplates = next
        persistEnduranceTemplates()
    }

    func reloadFromStore() {
        if let loaded = store.loadTemplates() {
            templates = loaded
        }
        if let loaded = enduranceStore.loadTemplates() {
            enduranceTemplates = loaded
        }
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
                note: "Baseline template for push focus days.",
                runCategory: nil
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
                note: "Hybrid lower day with hinge + squat.",
                runCategory: nil
            )
        ]
    }

    private func persistTemplates() {
        store.save(templates)
    }

    private func persistEnduranceTemplates() {
        enduranceStore.save(enduranceTemplates)
    }
}
