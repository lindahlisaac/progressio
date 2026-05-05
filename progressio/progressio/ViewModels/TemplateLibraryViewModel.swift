import Foundation
import Combine

final class TemplateLibraryViewModel: ObservableObject {
    @Published var templates: [StrengthTemplate]
    private let store: TemplateStore

    init(store: TemplateStore = FileTemplateStore(), templates: [StrengthTemplate]? = nil) {
        self.store = store
        if let templates {
            self.templates = templates
        } else if let loaded = store.loadTemplates() {
            self.templates = loaded
        } else {
            let samples = TemplateLibraryViewModel.makeSamples()
            self.templates = samples
            persistTemplates()
        }
    }

    func addTemplate(name: String, note: String?, category: TemplateCategory, exercises: [StrengthExercise], runCategory: RunCategory? = nil) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let cleanedNote: String?
        if let note {
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            cleanedNote = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            cleanedNote = nil
        }

        var newTemplate = StrengthTemplate(name: trimmedName, category: category, exercises: exercises, note: cleanedNote, runCategory: runCategory)
        newTemplate.updatedAt = Date()
        templates.append(newTemplate)
        persistTemplates()
    }

    func updateTemplate(_ updated: StrengthTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == updated.id }) {
            var stamped = updated
            stamped.updatedAt = Date()
            templates[idx] = stamped
            persistTemplates()
        }
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
                , runCategory: nil
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
}

