import Foundation

/// Computes a defensible daily exercise target (in minutes) from breed + age + weight + health.
///
/// Reads `BreedData.json` (compiled from `docs/breed-table.md`) once, lazily, and caches it.
/// Strategy:
///   - Find the breed by name or alias (case- and punctuation-insensitive). Fall back to the
///     size table (size inferred from weight) if not found.
///   - Pick life stage (puppy <1yr; senior at size-specific threshold; adult otherwise).
///   - Base target: puppy/senior take the conservative low end; adult takes the midpoint.
///     Per `docs/breed-table.md`: "When sources disagree, the lower figure wins for puppies
///     and seniors. The mid-point of the range is used for healthy adults."
///   - Apply the LARGEST applicable health-condition reduction (not multiplicative — stacking
///     was deemed too aggressive; the LLM proxy can do something nuanced later).
///   - Round to nearest 5 minutes for clean UI.
///
/// This is the safe floor. The LLM proxy personalises within range on top of this.
enum ExerciseTargetService {
    static func dailyTargetMinutes(
        breedPrimary: String,
        dateOfBirth: Date,
        weightKg: Double,
        hasArthritis: Bool,
        hasHipDysplasia: Bool,
        isBrachycephalic: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let data = Self.data
        let size: Size
        let stages: BreedData.LifeStages

        if let entry = match(breed: breedPrimary, in: data.breeds) {
            size = entry.size
            stages = entry.lifeStages
        } else {
            size = sizeForWeight(weightKg)
            stages = data.fallback[size.rawValue]
                ?? data.fallback[Size.medium.rawValue]
                ?? .zero
        }

        let stage = lifeStage(
            dateOfBirth: dateOfBirth,
            size: size,
            today: today,
            calendar: calendar,
            seniorAgeYearsBySize: data.seniorAgeYearsBySize
        )

        let range: BreedData.Range
        switch stage {
        case .puppy: range = stages.puppy
        case .adult: range = stages.adult
        case .senior: range = stages.senior
        }

        let base: Double
        switch stage {
        case .puppy, .senior:
            base = Double(range.min)
        case .adult:
            base = Double(range.min + range.max) / 2.0
        }

        let reductionPercent = largestReduction(
            hasArthritis: hasArthritis,
            hasHipDysplasia: hasHipDysplasia,
            isBrachycephalic: isBrachycephalic,
            conditions: data.conditions
        )
        let reduced = base * (1.0 - reductionPercent / 100.0)
        return roundToNearestFive(reduced)
    }

    /// Templated one-line rationale for the daily target. Used as a sensible default
    /// before the LLM proxy fills `dog.llmRationale` with something more personal,
    /// and as a permanent fallback when the LLM call fails or is offline.
    /// Per `brand.md`: plain English, no em dashes, no exclamation marks.
    static func templatedRationale(
        breedPrimary: String,
        dateOfBirth: Date,
        weightKg: Double,
        hasArthritis: Bool,
        hasHipDysplasia: Bool,
        isBrachycephalic: Bool,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let data = Self.data
        let entry = match(breed: breedPrimary, in: data.breeds)
        let size: Size = entry?.size ?? sizeForWeight(weightKg)
        let stage = lifeStage(
            dateOfBirth: dateOfBirth,
            size: size,
            today: today,
            calendar: calendar,
            seniorAgeYearsBySize: data.seniorAgeYearsBySize
        )
        let target = dailyTargetMinutes(
            breedPrimary: breedPrimary,
            dateOfBirth: dateOfBirth,
            weightKg: weightKg,
            hasArthritis: hasArthritis,
            hasHipDysplasia: hasHipDysplasia,
            isBrachycephalic: isBrachycephalic,
            today: today,
            calendar: calendar
        )

        let subject = entry?.breed ?? "\(size.rawValue.capitalized) dog"
        let stageLabel: String
        switch stage {
        case .puppy: stageLabel = "puppy"
        case .adult: stageLabel = "adult"
        case .senior: stageLabel = "senior"
        }

        let flagPhrase = primaryConditionPhrase(
            hasArthritis: hasArthritis,
            hasHipDysplasia: hasHipDysplasia,
            isBrachycephalic: isBrachycephalic
        )

        let header = "\(subject) \(stageLabel). Around \(target) minutes a day"
        let middle: String
        if let flagPhrase {
            middle = "\(header), reduced for \(flagPhrase)."
        } else {
            middle = "\(header) reflects standard breed needs."
        }

        let coda: String?
        switch stage {
        case .puppy:
            coda = "Keep walks short while growth plates close."
        case .senior:
            coda = "Joints matter more than distance."
        case .adult:
            coda = nil
        }

        if let coda {
            return "\(middle) \(coda)"
        }
        return middle
    }

    /// The condition driving the largest reduction, in user-facing copy.
    /// Returns nil if no flag is set. Mirrors the largest-reduction tie-breaking
    /// rule used in `dailyTargetMinutes`.
    private static func primaryConditionPhrase(
        hasArthritis: Bool,
        hasHipDysplasia: Bool,
        isBrachycephalic: Bool
    ) -> String? {
        let conditions = Self.data.conditions
        var ranked: [(percent: Double, phrase: String)] = []
        if hasArthritis {
            ranked.append((conditions.arthritis.reductionPercent, "arthritis"))
        }
        if hasHipDysplasia {
            ranked.append((conditions.hipDysplasia.reductionPercent, "hip dysplasia"))
        }
        if isBrachycephalic {
            ranked.append((conditions.brachycephalic.reductionPercent, "their breathing"))
        }
        return ranked.max(by: { $0.percent < $1.percent })?.phrase
    }

    // MARK: - Helpers

    enum LifeStage {
        case puppy, adult, senior
    }

    enum Size: String, Decodable, Hashable, Sendable {
        case tiny, small, medium, large, giant
    }

    private static func match(breed: String, in breeds: [BreedData.Entry]) -> BreedData.Entry? {
        let normalized = normalize(breed)
        guard !normalized.isEmpty else { return nil }
        return breeds.first { entry in
            if normalize(entry.breed) == normalized { return true }
            return entry.aliases.contains { normalize($0) == normalized }
        }
    }

    private static func normalize(_ string: String) -> String {
        string
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private static func sizeForWeight(_ kg: Double) -> Size {
        switch kg {
        case ..<5: return .tiny
        case ..<10: return .small
        case ..<25: return .medium
        case ..<45: return .large
        default: return .giant
        }
    }

    private static func lifeStage(
        dateOfBirth: Date,
        size: Size,
        today: Date,
        calendar: Calendar,
        seniorAgeYearsBySize: [String: Int]
    ) -> LifeStage {
        let years = calendar.dateComponents([.year], from: dateOfBirth, to: today).year ?? 0
        if years < 1 { return .puppy }
        let seniorThreshold = seniorAgeYearsBySize[size.rawValue] ?? 8
        if years >= seniorThreshold { return .senior }
        return .adult
    }

    private static func largestReduction(
        hasArthritis: Bool,
        hasHipDysplasia: Bool,
        isBrachycephalic: Bool,
        conditions: BreedData.Conditions
    ) -> Double {
        var values: [Double] = []
        if hasArthritis { values.append(conditions.arthritis.reductionPercent) }
        if hasHipDysplasia { values.append(conditions.hipDysplasia.reductionPercent) }
        if isBrachycephalic { values.append(conditions.brachycephalic.reductionPercent) }
        return values.max() ?? 0
    }

    private static func roundToNearestFive(_ value: Double) -> Int {
        let rounded = (value / 5.0).rounded() * 5.0
        return max(5, Int(rounded))
    }

    // MARK: - Loading

    static let data: BreedData = {
        guard let url = Bundle.main.url(forResource: "BreedData", withExtension: "json") else {
            assertionFailure("BreedData.json missing from bundle")
            return BreedData.empty
        }
        do {
            let raw = try Data(contentsOf: url)
            return try JSONDecoder().decode(BreedData.self, from: raw)
        } catch {
            assertionFailure("BreedData.json failed to decode: \(error)")
            return BreedData.empty
        }
    }()
}

// MARK: - JSON model

struct BreedData: Decodable, Sendable {
    let breeds: [Entry]
    let fallback: [String: LifeStages]
    let seniorAgeYearsBySize: [String: Int]
    let conditions: Conditions

    struct Entry: Decodable, Sendable {
        let breed: String
        let aliases: [String]
        let size: ExerciseTargetService.Size
        let defaultIntensity: String
        let lifeStages: LifeStages
    }

    struct LifeStages: Decodable, Sendable {
        let puppy: Range
        let adult: Range
        let senior: Range

        static let zero = LifeStages(
            puppy: .init(min: 0, max: 0),
            adult: .init(min: 60, max: 60),
            senior: .init(min: 0, max: 0)
        )
    }

    struct Range: Decodable, Sendable {
        let min: Int
        let max: Int
    }

    struct Conditions: Decodable, Sendable {
        let brachycephalic: Adjustment
        let hipDysplasia: Adjustment
        let arthritis: Adjustment
    }

    struct Adjustment: Decodable, Sendable {
        let reductionPercent: Double
        let intensityCap: String?
    }

    static let empty = BreedData(
        breeds: [],
        fallback: [:],
        seniorAgeYearsBySize: [:],
        conditions: Conditions(
            brachycephalic: Adjustment(reductionPercent: 0, intensityCap: nil),
            hipDysplasia: Adjustment(reductionPercent: 0, intensityCap: nil),
            arthritis: Adjustment(reductionPercent: 0, intensityCap: nil)
        )
    )
}
