import Testing
import Foundation
@testable import Trot

@Suite("AddDogFormState validation")
struct AddDogFormStateTests {

    @Test("blank state is invalid")
    func blankIsInvalid() {
        let state = AddDogFormState()
        #expect(state.isValid == false)
    }

    @Test("name and breed required")
    func nameAndBreedRequired() {
        var state = AddDogFormState()
        state.weightKg = 10
        state.dateOfBirth = .now.addingTimeInterval(-86_400 * 365)

        #expect(state.isValid == false, "missing name and breed")

        state.name = "Luna"
        #expect(state.isValid == false, "missing breed")

        state.breedPrimary = "Beagle"
        #expect(state.isValid == true, "all required fields filled")
    }

    @Test("whitespace-only name and breed are invalid")
    func whitespaceFieldsInvalid() {
        var state = AddDogFormState()
        state.name = "   "
        state.breedPrimary = "  \n "
        state.weightKg = 10
        #expect(state.isValid == false)
    }

    @Test("future date of birth is invalid")
    func futureDOBInvalid() {
        var state = AddDogFormState()
        state.name = "Luna"
        state.breedPrimary = "Beagle"
        state.weightKg = 10
        state.dateOfBirth = .now.addingTimeInterval(86_400)
        #expect(state.isValid == false)
    }

    @Test("zero or negative weight is invalid")
    func nonPositiveWeightInvalid() {
        var state = AddDogFormState()
        state.name = "Luna"
        state.breedPrimary = "Beagle"
        state.dateOfBirth = .now.addingTimeInterval(-86_400 * 365)

        state.weightKg = 0
        #expect(state.isValid == false)

        state.weightKg = -1
        #expect(state.isValid == false)

        state.weightKg = 0.5
        #expect(state.isValid == true)
    }

    @Test("makeDog reflects the form state and trims whitespace")
    func makeDogReflectsState() {
        var state = AddDogFormState()
        state.name = "  Luna  "
        state.breedPrimary = " Beagle "
        state.weightKg = 12
        state.sex = .female
        state.isNeutered = true
        state.activityLevel = .moderate
        state.healthNotes = " has been good "
        state.hasArthritis = true

        let dog = state.makeDog()
        #expect(dog.name == "Luna")
        #expect(dog.breedPrimary == "Beagle")
        #expect(dog.weightKg == 12)
        #expect(dog.sex == .female)
        #expect(dog.isNeutered == true)
        #expect(dog.activityLevel == .moderate)
        #expect(dog.healthNotes == "has been good")
        #expect(dog.hasArthritis == true)
        #expect(dog.dailyTargetMinutes == state.computedDailyTargetMinutes,
                "makeDog wires the breed-table-derived target onto the dog")
        #expect(dog.dailyTargetMinutes > 0)
    }

    @Test("from(dog) round-trips into apply(to:)")
    func roundTripFromApply() {
        let original = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 1_500_000_000),
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            activityLevel: .moderate
        )
        original.healthNotes = "no issues"
        original.hasArthritis = true
        original.dailyTargetMinutes = 75
        original.llmRationale = "Beagles benefit from..."

        var state = AddDogFormState.from(original)
        #expect(state.name == "Luna")
        #expect(state.breedPrimary == "Beagle")
        #expect(state.weightKg == 12)
        #expect(state.sex == .female)
        #expect(state.isNeutered == true)
        #expect(state.activityLevel == .moderate)
        #expect(state.healthNotes == "no issues")
        #expect(state.hasArthritis == true)

        // Mutate state and apply back
        state.name = "Bruno"
        state.weightKg = 30
        state.sex = .male
        state.isNeutered = false
        state.activityLevel = .high
        state.healthNotes = "  edited  "
        state.hasHipDysplasia = true
        state.hasArthritis = false
        state.apply(to: original)

        #expect(original.name == "Bruno")
        #expect(original.weightKg == 30)
        #expect(original.sex == .male)
        #expect(original.isNeutered == false)
        #expect(original.activityLevel == .high)
        #expect(original.healthNotes == "edited", "trimmed whitespace on apply")
        #expect(original.hasHipDysplasia == true)
        #expect(original.hasArthritis == false)
        #expect(original.dailyTargetMinutes == state.computedDailyTargetMinutes,
                "apply recomputes the target from breed-table inputs that may have changed")
        #expect(original.dailyTargetMinutes != 75, "the original 75 was overwritten")
        #expect(original.llmRationale == state.computedRationale,
                "apply writes the templated rationale; LLM personalisation overwrites later")
        #expect(original.llmRationale != "Beagles benefit from...", "the original rationale was overwritten")
    }
}
