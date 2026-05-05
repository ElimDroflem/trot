import Foundation

struct AddDogFormState {
    var name: String = ""
    var breedPrimary: String = ""
    var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -3, to: .now) ?? .now
    var weightKg: Double = 10
    var sex: Sex = .female
    var isNeutered: Bool = false
    var activityLevel: ActivityLevel = .moderate
    var healthNotes: String = ""
    var hasArthritis: Bool = false
    var hasHipDysplasia: Bool = false
    var isBrachycephalic: Bool = false
    var photoData: Data?

    var isValid: Bool {
        !trimmedName.isEmpty
            && !trimmedBreed.isEmpty
            && weightKg > 0
            && dateOfBirth <= .now
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBreed: String {
        breedPrimary.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeDog() -> Dog {
        let dog = Dog(
            name: trimmedName,
            breedPrimary: trimmedBreed,
            dateOfBirth: dateOfBirth,
            weightKg: weightKg,
            sex: sex,
            isNeutered: isNeutered,
            activityLevel: activityLevel
        )
        dog.healthNotes = healthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        dog.hasArthritis = hasArthritis
        dog.hasHipDysplasia = hasHipDysplasia
        dog.isBrachycephalic = isBrachycephalic
        dog.photo = photoData
        return dog
    }

    /// Mutates `dog` to reflect the form state. Used when editing an existing dog.
    /// Doesn't change `dog.dailyTargetMinutes` or `dog.llmRationale` — those are
    /// owned by the LLM/breed-table services, not editable in this form.
    func apply(to dog: Dog) {
        dog.name = trimmedName
        dog.breedPrimary = trimmedBreed
        dog.dateOfBirth = dateOfBirth
        dog.weightKg = weightKg
        dog.sex = sex
        dog.isNeutered = isNeutered
        dog.activityLevel = activityLevel
        dog.healthNotes = healthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        dog.hasArthritis = hasArthritis
        dog.hasHipDysplasia = hasHipDysplasia
        dog.isBrachycephalic = isBrachycephalic
        dog.photo = photoData
    }

    /// Pre-populates form state from an existing Dog for editing.
    static func from(_ dog: Dog) -> AddDogFormState {
        var state = AddDogFormState()
        state.name = dog.name
        state.breedPrimary = dog.breedPrimary
        state.dateOfBirth = dog.dateOfBirth
        state.weightKg = dog.weightKg
        state.sex = dog.sex
        state.isNeutered = dog.isNeutered
        state.activityLevel = dog.activityLevel
        state.healthNotes = dog.healthNotes
        state.hasArthritis = dog.hasArthritis
        state.hasHipDysplasia = dog.hasHipDysplasia
        state.isBrachycephalic = dog.isBrachycephalic
        state.photoData = dog.photo
        return state
    }
}
