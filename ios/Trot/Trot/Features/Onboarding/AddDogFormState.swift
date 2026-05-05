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
}
