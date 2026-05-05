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
        #expect(dog.dailyTargetMinutes == 60, "default until LLM service overwrites")
    }
}
