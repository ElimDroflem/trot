import Testing
import Foundation
@testable import Trot

@Suite("ExerciseTargetService")
struct ExerciseTargetServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private let today: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 5
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: components) ?? .now
    }()

    private func dob(yearsAgo: Int, monthsAgo: Int = 0) -> Date {
        var comp = DateComponents(); comp.year = -yearsAgo; comp.month = -monthsAgo
        return calendar.date(byAdding: comp, to: today) ?? today
    }

    @Test("adult Labrador returns midpoint of breed range")
    func adultLab() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 5),
            weightKg: 30,
            hasArthritis: false,
            hasHipDysplasia: false,
            isBrachycephalic: false,
            today: today,
            calendar: calendar
        )
        // Labrador adult is min 80, max 120 in BreedData.json → midpoint 100
        #expect(target == 100)
    }

    @Test("puppy returns conservative low end")
    func puppyLab() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 0, monthsAgo: 6),
            weightKg: 10,
            hasArthritis: false,
            hasHipDysplasia: false,
            isBrachycephalic: false,
            today: today,
            calendar: calendar
        )
        // Labrador puppy min = 15
        #expect(target == 15)
    }

    @Test("senior returns conservative low end")
    func seniorLab() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 10),
            weightKg: 30,
            hasArthritis: false,
            hasHipDysplasia: false,
            isBrachycephalic: false,
            today: today,
            calendar: calendar
        )
        // Labrador senior min = 30 (large breed senior threshold = 7y, so 10y is senior)
        #expect(target == 30)
    }

    @Test("alias matches the primary breed entry")
    func aliasMatch() {
        let viaAlias = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Lab",
            dateOfBirth: dob(yearsAgo: 5),
            weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        let viaCanonical = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 5),
            weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(viaAlias == viaCanonical)
    }

    @Test("breed match is case- and punctuation-insensitive")
    func caseInsensitive() {
        let lower = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "labrador retriever",
            dateOfBirth: dob(yearsAgo: 5), weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        let upper = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "LABRADOR-RETRIEVER",
            dateOfBirth: dob(yearsAgo: 5), weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(lower > 0)
        #expect(lower == upper)
    }

    @Test("unknown breed falls back to size-based table")
    func unknownBreedMediumFallback() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Made Up Breed",
            dateOfBirth: dob(yearsAgo: 4),
            weightKg: 15, // medium
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        // medium adult: (45+90)/2 = 67.5, rounded to nearest 5 → 70 (rounds up)
        // Foundation .rounded() defaults to .toNearestOrEven, so 67.5/5 = 13.5 → 14 → 70
        #expect(target == 70)
    }

    @Test("unknown breed weight maps to giant fallback")
    func unknownBreedGiantFallback() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "?",
            dateOfBirth: dob(yearsAgo: 4),
            weightKg: 50, // giant
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        // giant adult: (45+90)/2 = 67.5 → 70
        #expect(target == 70)
    }

    @Test("unknown breed senior with large weight uses size-specific threshold")
    func unknownBreedLargeSenior() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "?",
            dateOfBirth: dob(yearsAgo: 8), // large threshold = 7y
            weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        // large senior min = 30
        #expect(target == 30)
    }

    @Test("brachycephalic reduces by 30%")
    func brachycephalicReduction() {
        let baseline = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Pug",
            dateOfBirth: dob(yearsAgo: 4), weightKg: 8,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        let reduced = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Pug",
            dateOfBirth: dob(yearsAgo: 4), weightKg: 8,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: true,
            today: today, calendar: calendar
        )
        #expect(reduced < baseline)
        // 30% reduction
        let expected = Int(((Double(baseline) * 0.7) / 5.0).rounded() * 5.0)
        #expect(reduced == expected)
    }

    @Test("combined conditions take the largest single reduction, not stacked")
    func combinedConditionsTakeLargest() {
        // arthritis (30%) and hipDysplasia (20%) together → 30% reduction, NOT 44% (1 - 0.7*0.8)
        let arthritisOnly = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 5), weightKg: 30,
            hasArthritis: true, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        let both = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 5), weightKg: 30,
            hasArthritis: true, hasHipDysplasia: true, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(arthritisOnly == both)
    }

    @Test("result is rounded to nearest 5 minutes")
    func roundsToFive() {
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "Made Up",
            dateOfBirth: dob(yearsAgo: 4),
            weightKg: 7, // small → adult range 30-60, midpoint 45 → 45 (clean)
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(target % 5 == 0)
        #expect(target >= 5)
    }

    @Test("never returns less than 5")
    func neverBelowFloor() {
        // Maximally reduced senior tiny dog
        let target = ExerciseTargetService.dailyTargetMinutes(
            breedPrimary: "?",
            dateOfBirth: dob(yearsAgo: 12),
            weightKg: 3, // tiny
            hasArthritis: true, hasHipDysplasia: true, isBrachycephalic: true,
            today: today, calendar: calendar
        )
        // tiny senior min = 20, × 0.7 = 14 → 15
        #expect(target >= 5)
    }

    // MARK: - Templated rationale

    @Test("rationale: adult known breed mentions breed and target")
    func rationaleAdultKnownBreed() {
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Beagle",
            dateOfBirth: dob(yearsAgo: 4), weightKg: 12,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(line.contains("Beagle"))
        #expect(line.contains("adult"))
        #expect(line.contains("minutes a day"))
        #expect(!line.contains("—"), "no em dashes per brand.md")
        #expect(!line.contains("!"), "no exclamation marks in regular flows")
    }

    @Test("rationale: puppy includes growth-plate guidance")
    func rationalePuppyCoda() {
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 0, monthsAgo: 4), weightKg: 8,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(line.contains("puppy"))
        #expect(line.lowercased().contains("growth plates"))
    }

    @Test("rationale: senior includes joint guidance")
    func rationaleSeniorCoda() {
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 10), weightKg: 30,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(line.contains("senior"))
        #expect(line.lowercased().contains("joints"))
    }

    @Test("rationale: brachycephalic flag mentions breathing")
    func rationaleBrachycephalic() {
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Pug",
            dateOfBirth: dob(yearsAgo: 4), weightKg: 8,
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: true,
            today: today, calendar: calendar
        )
        #expect(line.lowercased().contains("breathing"))
        #expect(line.contains("reduced"))
    }

    @Test("rationale: combined flags pick the largest reduction (arthritis over hip)")
    func rationaleLargestReductionPhrase() {
        // arthritis 30%, hipDysplasia 20% — line should mention arthritis
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Labrador Retriever",
            dateOfBirth: dob(yearsAgo: 5), weightKg: 30,
            hasArthritis: true, hasHipDysplasia: true, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(line.lowercased().contains("arthritis"))
        #expect(!line.lowercased().contains("hip dysplasia"),
                "phrase shows the dominant flag only, not both")
    }

    @Test("rationale: unknown breed falls back to size descriptor")
    func rationaleUnknownBreedSize() {
        let line = ExerciseTargetService.templatedRationale(
            breedPrimary: "Made Up Breed",
            dateOfBirth: dob(yearsAgo: 4), weightKg: 15, // medium
            hasArthritis: false, hasHipDysplasia: false, isBrachycephalic: false,
            today: today, calendar: calendar
        )
        #expect(line.contains("Medium dog") || line.contains("Medium"),
                "size word stands in for missing breed name")
        #expect(!line.contains("Made Up Breed"))
    }
}
