import Foundation
import SwiftData

/// Thin client for the Vercel `/api/dog-voice` proxy. Generates short
/// dog-voice lines per the brand "translator" framing.
///
/// Every public surface returns `String?` and falls back to nil silently on
/// any failure (network, timeout, decode, server error). Callers must have a
/// templated/deterministic fallback ready — never block UI on this service.
///
/// Caching is per-kind, keyed coarsely (per-day, per-week, per-walk) so a
/// single user open burns one call per fresh surface, not one per render.
enum LLMService {
    /// Production proxy URL. Closer to App Store submission this swaps to a
    /// real domain (trot.dog target). Single constant; one-line change later.
    static let proxyBase = URL(string: "https://trot-virid.vercel.app")!

    static let timeout: TimeInterval = 8

    enum Kind: String, Codable, Sendable {
        case daily
        case walkComplete = "walk_complete"
        case insight
        case recap
        case decay
        case onboardingCard = "onboarding_card"
        /// Home tab personality voice — fun fact, joke, observation, or
        /// playful question in the dog's voice. Capped at three calls per
        /// dog per day via slotted caching in `dogChatLine(for:)`.
        case dogChat = "dog_chat"
        /// Today-tab walk-window rationale. Layered on top of the
        /// deterministic scorer so the user sees a glanceable headline
        /// immediately, then a slightly nicer LLM-flavoured caption when
        /// it lands. Cached per (dog × dayKey).
        case bestWindow = "best_window"
        /// Story-tab page generation. Sonnet 4.6 (the proxy picks the
        /// model based on kind). Returns a structured JSON payload with
        /// prose + two path teasers; iOS decodes via `StoryPagePayload`.
        /// Optional vision: caller can pass an image which the LLM
        /// analyses and weaves into the prose.
        case storyPage = "story_page"
        /// Story-tab chapter close — generates title, closing line,
        /// updated bible, and the prologue page of the next chapter.
        /// Returns structured JSON; iOS decodes via `StoryChapterClosePayload`.
        case storyChapterClose = "story_chapter_close"
    }

    /// Decoded payload for a `storyPage` response. Filled in by
    /// `storyPage(...)` after parsing the proxy's JSON text.
    struct StoryPagePayload: Decodable, Sendable {
        let prose: String
        let choiceA: String
        let choiceB: String
    }

    /// Decoded payload for a `storyChapterClose` response. The
    /// `prologueProse` / `choiceA` / `choiceB` are empty on the finale
    /// path (no next chapter); `bookTitle` / `bookClosingLine` are
    /// non-empty only on the finale path. Both groups have defaults so
    /// the same struct decodes both proxy variants.
    struct StoryChapterClosePayload: Decodable, Sendable {
        let title: String
        let closingLine: String
        let bibleUpdate: String
        let prologueProse: String
        let choiceA: String
        let choiceB: String
        let bookTitle: String
        let bookClosingLine: String

        init(
            title: String,
            closingLine: String,
            bibleUpdate: String,
            prologueProse: String,
            choiceA: String,
            choiceB: String,
            bookTitle: String = "",
            bookClosingLine: String = ""
        ) {
            self.title = title
            self.closingLine = closingLine
            self.bibleUpdate = bibleUpdate
            self.prologueProse = prologueProse
            self.choiceA = choiceA
            self.choiceB = choiceB
            self.bookTitle = bookTitle
            self.bookClosingLine = bookClosingLine
        }

        // Custom decoding so the new `bookTitle` / `bookClosingLine`
        // fields default to "" if the proxy didn't return them (older
        // deploy or non-finale path that omits them).
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.title = try c.decode(String.self, forKey: .title)
            self.closingLine = try c.decode(String.self, forKey: .closingLine)
            self.bibleUpdate = try c.decode(String.self, forKey: .bibleUpdate)
            self.prologueProse = try c.decodeIfPresent(String.self, forKey: .prologueProse) ?? ""
            self.choiceA = try c.decodeIfPresent(String.self, forKey: .choiceA) ?? ""
            self.choiceB = try c.decodeIfPresent(String.self, forKey: .choiceB) ?? ""
            self.bookTitle = try c.decodeIfPresent(String.self, forKey: .bookTitle) ?? ""
            self.bookClosingLine = try c.decodeIfPresent(String.self, forKey: .bookClosingLine) ?? ""
        }

        private enum CodingKeys: String, CodingKey {
            case title, closingLine, bibleUpdate
            case prologueProse, choiceA, choiceB
            case bookTitle, bookClosingLine
        }
    }

    // MARK: - Public surfaces

    /// Daily Home line, refreshed once per local day per dog. Returns the
    /// cached line if still fresh; otherwise calls the proxy. Falls back to
    /// nil on any failure (caller should use `DogVoiceService.currentLine`).
    static func dailyLine(for dog: Dog, now: Date = .now, calendar: Calendar = .current) async -> String? {
        let dayKey = Self.localDayKey(now, calendar: calendar)
        let cacheKey = "daily.\(dog.persistentModelID.hashValue).\(dayKey)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let walks = (dog.walks ?? []).filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
        let minutesToday = walks.reduce(0) { $0 + $1.durationMinutes }
        let context: [String: any Sendable] = [
            "hourLocal": calendar.component(.hour, from: now),
            "minutesToday": minutesToday,
            "targetMinutes": dog.dailyTargetMinutes,
        ]

        guard let text = await request(kind: .daily, dog: dog, context: context) else { return nil }
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24)
        return text
    }

    /// Post-walk celebration line. No cache — each walk save is a fresh
    /// call. `pageUnlocked` flips a story-mode hint into the prompt when
    /// this walk crossed the half- or full-target line ("page 1 unlocked"
    /// or "page 2 unlocked"); the proxy can lean on it for a richer line.
    static func walkCompleteLine(
        for dog: Dog,
        minutes: Int,
        isFirstWalk: Bool,
        pageUnlocked: String?
    ) async -> String? {
        let context: [String: any Sendable] = [
            "minutes": minutes,
            "isFirstWalk": isFirstWalk,
            "pageUnlocked": pageUnlocked ?? "",
        ]
        return await request(kind: .walkComplete, dog: dog, context: context)
    }

    // insightLine removed — Insights tab is now driven by DogInsightsService
    // (templated, deterministic, free). Dog-voice for the user lives on Home
    // via dogChatLine. The `Kind.insight` case stays in case a future
    // surface wants to use it; the proxy still understands "insight".

    /// Weekly recap narrative paragraph. Refreshed weekly.
    static func recapNarrative(
        for dog: Dog,
        minutesThisWeek: Int,
        minutesLastWeek: Int,
        streakDays: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        let weekKey = Self.localWeekKey(now, calendar: calendar)
        let cacheKey = "recap.\(dog.persistentModelID.hashValue).\(weekKey)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let context: [String: any Sendable] = [
            "minutesThisWeek": minutesThisWeek,
            "minutesLastWeek": minutesLastWeek,
            "streakDays": streakDays,
        ]
        guard let text = await request(kind: .recap, dog: dog, context: context) else { return nil }
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24 * 7)
        return text
    }

    /// Decay line for dogs with 3+ days since last walk. Cached per-day so the
    /// same line shows on every open within the day rather than re-rolling.
    static func decayLine(
        for dog: Dog,
        daysSinceLastWalk: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        let dayKey = Self.localDayKey(now, calendar: calendar)
        let cacheKey = "decay.\(dog.persistentModelID.hashValue).\(dayKey)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let context: [String: any Sendable] = ["daysSinceLastWalk": daysSinceLastWalk]
        guard let text = await request(kind: .decay, dog: dog, context: context) else { return nil }
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24)
        return text
    }

    /// Walk-window rationale for the Today-tab tile. Sends the day's
    /// hourly forecast (compressed) plus the deterministic scorer's pick
    /// to the LLM, asks for one short sentence naming a *range* (not a
    /// single hour) like *"Best between 1pm and 3pm — sun, no clouds in
    /// the way."* Cached per (dog × dayKey) so we burn at most one call
    /// per dog per day.
    ///
    /// `pickedWindow` is the deterministic range string ("1pm to 3pm"),
    /// `pickedConditions` is the conditions ("Sunny, 18°"). LLM treats
    /// these as a strong hint and may rephrase but should not invent
    /// different weather.
    static func bestWindowRationale(
        for dog: Dog,
        hourlyTable: String,
        pickedWindow: String,
        pickedConditions: String,
        walkWindowSlots: [String],
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        let dayKey = Self.localDayKey(now, calendar: calendar)
        let cacheKey = "bestWindow.\(dog.persistentModelID.hashValue).\(dayKey)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let context: [String: any Sendable] = [
            "hourlyTable": hourlyTable,
            "pickedWindow": pickedWindow,
            "pickedConditions": pickedConditions,
            "walkWindowSlots": walkWindowSlots,
        ]
        guard let text = await request(kind: .bestWindow, dog: dog, context: context) else { return nil }
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24)
        return text
    }

    /// Story page generation. Returns a structured payload (prose + two
    /// path teasers). No iOS-side cache — `StoryService` persists pages
    /// directly to SwiftData and never re-asks for the same page. Optional
    /// image data triggers Sonnet vision so the LLM can weave a detail
    /// from the user's photo into the prose.
    ///
    /// On any failure (network, timeout, malformed JSON), returns nil and
    /// the caller falls back to a templated page. The fallback isn't
    /// perfect but it preserves the chapter structure so the user can
    /// retry later.
    static func storyPage(
        for dog: Dog,
        genre: StoryGenre,
        scene: StoryGenre.Scene?,
        ownerName: String,
        bible: String,
        previousPages: String,
        walkFacts: String,
        userChoice: String,
        userText: String,
        pageIndexInChapter: Int,
        isPrologue: Bool,
        imageJPEG: Data? = nil
    ) async -> StoryPagePayload? {
        let context: [String: any Sendable] = [
            "toneInstruction": genre.toneInstruction,
            "genreName": genre.displayName,
            "ownerName": ownerName,
            "bible": bible,
            "previousPages": previousPages,
            "walkFacts": walkFacts,
            "userChoice": userChoice,
            "userText": userText,
            "hasImage": imageJPEG != nil,
            "isPrologue": isPrologue,
            "pageIndexInChapter": pageIndexInChapter,
            "sceneName": scene?.displayName ?? "",
            "scenePrompt": scene?.prompt ?? "",
        ]
        guard let raw = await request(
            kind: .storyPage,
            dog: dog,
            context: context,
            imageJPEG: imageJPEG
        ) else { return nil }
        return decodeStoryPage(raw)
    }

    /// Chapter close — wraps the just-finished chapter and generates the
    /// prologue of the next. Returns the structured payload that
    /// `StoryService` uses to persist the close + open the new chapter
    /// + write its first page atomically.
    static func storyChapterClose(
        for dog: Dog,
        genre: StoryGenre,
        ownerName: String,
        bible: String,
        chapterPages: String,
        chapterIndex: Int,
        isFinale: Bool
    ) async -> StoryChapterClosePayload? {
        let context: [String: any Sendable] = [
            "toneInstruction": genre.toneInstruction,
            "genreName": genre.displayName,
            "ownerName": ownerName,
            "bible": bible,
            "chapterPages": chapterPages,
            "chapterIndex": chapterIndex,
            "isFinale": isFinale,
        ]
        guard let raw = await request(
            kind: .storyChapterClose,
            dog: dog,
            context: context
        ) else { return nil }
        return decodeStoryChapterClose(raw)
    }

    private static func decodeStoryPage(_ raw: String) -> StoryPagePayload? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StoryPagePayload.self, from: data)
    }

    private static func decodeStoryChapterClose(_ raw: String) -> StoryChapterClosePayload? {
        guard let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(StoryChapterClosePayload.self, from: data)
    }

    /// One-shot onboarding "first card" line. Persists indefinitely once
    /// generated — this is a moment, not a refresh.
    static func onboardingCardLine(for dog: Dog) async -> String? {
        let cacheKey = "onboarding.\(dog.persistentModelID.hashValue)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }
        guard let text = await request(kind: .onboardingCard, dog: dog, context: [:]) else { return nil }
        // Effectively forever — 10 years.
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24 * 365 * 10)
        return text
    }

    /// Home-tab personality line — fun fact, joke, observation, plot, trivia
    /// or playful question in the dog's voice. Cached per (dog × local-day ×
    /// time-slot) so we burn at most three LLM calls per dog per day even if
    /// the user opens the app dozens of times. The slot key is computed from
    /// the current local hour: morning (5-12), afternoon (12-17), evening
    /// (17-22). Outside those windows we reuse the evening slot's cache.
    ///
    /// Category is rotated deterministically across days using the dog's id +
    /// day key + slot, so each slot has a stable category for the whole day
    /// but the user gets visible variety across consecutive mornings/etc.
    static func dogChatLine(
        for dog: Dog,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        let dayKey = Self.localDayKey(now, calendar: calendar)
        let slot = DogChatSlot.current(now: now, calendar: calendar)
        let category = DogChatSlot.category(for: dog, dayKey: dayKey, slot: slot)
        let cacheKey = "dogChat.\(dog.persistentModelID.hashValue).\(dayKey).\(slot.rawValue)"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let context: [String: any Sendable] = [
            "category": category,
            "slot": slot.rawValue,
        ]
        guard let text = await request(kind: .dogChat, dog: dog, context: context) else { return nil }
        // 24h cache: by tomorrow's same slot a fresh line will be generated
        // and the rotation will land on a (likely) different category.
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24)
        return text
    }

    /// Three time-of-day slots used to cap how often `dogChatLine` hits the
    /// API — capped at one call per slot per dog per day, three slots per
    /// day (morning/afternoon/evening) = max three calls per dog per day.
    /// The night hours (22:00-05:00) reuse the evening slot's cache.
    enum DogChatSlot: String, Sendable, CaseIterable {
        case morning, afternoon, evening

        static func current(now: Date, calendar: Calendar) -> DogChatSlot {
            switch calendar.component(.hour, from: now) {
            case 5..<12: return .morning
            case 12..<17: return .afternoon
            default: return .evening
            }
        }

        /// Category candidates per slot. Each slot has 3 distinct flavours so
        /// the dog has a clear voice for the time of day but still varies day
        /// to day. Morning leans facts/observation, afternoon leans curiosity,
        /// evening leans wry/dramatic.
        var categories: [String] {
            switch self {
            case .morning:   return ["fact", "trivia", "observation"]
            case .afternoon: return ["question", "plot", "observation"]
            case .evening:   return ["joke", "plot", "trivia"]
            }
        }

        /// Deterministic per-day category pick — same dog × same day × same
        /// slot always yields the same category, so a retry inside a slot
        /// stays consistent. Across consecutive days the rotation moves so
        /// the user sees variety without surprises mid-day.
        static func category(for dog: Dog, dayKey: String, slot: DogChatSlot) -> String {
            let candidates = slot.categories
            // Stable hash from id hash + day string so rotation is deterministic
            // but uncorrelated with anything visible.
            var hasher = Hasher()
            hasher.combine(dog.persistentModelID.hashValue)
            hasher.combine(dayKey)
            hasher.combine(slot.rawValue)
            let value = abs(hasher.finalize())
            return candidates[value % candidates.count]
        }
    }

    /// Pre-save onboarding card. Called from `AddDogView` after the user has
    /// uploaded a photo and entered a name but BEFORE the Dog is persisted to
    /// SwiftData (so we don't have a `persistentModelID` to cache against).
    /// No cache — generate fresh each time, since this is the moment-of-meeting
    /// and the user only sees it once anyway.
    static func onboardingCardLine(
        name: String,
        breedHint: String? = nil,
        ageHintMonths: Int = 24
    ) async -> String? {
        let payload: [String: any Sendable] = [
            "name": name,
            "breed": breedHint?.isEmpty == false ? breedHint! : "Mixed",
            "ageMonths": ageHintMonths,
            "lifeStage": ageHintMonths < 12 ? "puppy" : (ageHintMonths >= 12 * 8 ? "senior" : "adult"),
        ]
        return await request(kind: .onboardingCard, dogPayload: payload, context: [:])
    }

    // MARK: - Internals

    private static func request(
        kind: Kind,
        dog: Dog,
        context: [String: any Sendable],
        imageJPEG: Data? = nil
    ) async -> String? {
        await request(
            kind: kind,
            dogPayload: dogPayload(dog),
            context: context,
            imageJPEG: imageJPEG
        )
    }

    /// Lower-level overload that takes the dog payload dict directly. Used by
    /// pre-save callers (notably the onboarding-card path, which fires before
    /// SwiftData has a `Dog` instance to refer to). Story-page callers use
    /// the `imageJPEG` parameter to send a Sonnet-vision request.
    private static func request(
        kind: Kind,
        dogPayload: [String: any Sendable],
        context: [String: any Sendable],
        imageJPEG: Data? = nil
    ) async -> String? {
        let url = proxyBase.appendingPathComponent("api/dog-voice")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Story kinds use Sonnet on the proxy and may include images;
        // bump the timeout to give vision responses time to land.
        req.timeoutInterval = (kind == .storyPage || kind == .storyChapterClose) ? 30 : timeout

        var body: [String: any Sendable] = [
            "installToken": InstallTokenService.token(),
            "kind": kind.rawValue,
            "dog": dogPayload,
            "context": context,
        ]
        if let imageJPEG {
            body["imageBase64"] = imageJPEG.base64EncodedString()
        }

        guard let payload = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return nil
        }
        req.httpBody = payload

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let bodyPreview = String(data: data.prefix(200), encoding: .utf8) ?? "(non-utf8)"
                print("LLMService.\(kind.rawValue) HTTP \(status): \(bodyPreview)")
                return nil
            }
            let decoded = try JSONDecoder().decode(SuccessResponse.self, from: data)
            let trimmed = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                print("LLMService.\(kind.rawValue) empty response")
                return nil
            }
            return trimmed
        } catch {
            print("LLMService.\(kind.rawValue) error: \(error.localizedDescription)")
            return nil
        }
    }

    private static func dogPayload(_ dog: Dog) -> [String: any Sendable] {
        [
            "name": dog.name,
            "breed": dog.breedPrimary,
            "ageMonths": ageMonths(from: dog.dateOfBirth),
            "lifeStage": lifeStage(for: dog).rawValue,
        ]
    }

    private static func ageMonths(from dob: Date?) -> Int {
        guard let dob else { return 12 }
        let months = Calendar.current.dateComponents([.month], from: dob, to: .now).month ?? 12
        return max(0, months)
    }

    private static func lifeStage(for dog: Dog) -> LifeStageHint {
        let months = ageMonths(from: dog.dateOfBirth)
        if months < 12 { return .puppy }
        // Conservative senior threshold; the proxy doesn't actually use this for
        // numeric calculation — it's just a phrasing hint for the model.
        if months >= 12 * 8 { return .senior }
        return .adult
    }

    private enum LifeStageHint: String { case puppy, adult, senior }

    private static func localDayKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    private static func localWeekKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }

    private static func stableHash(_ s: String) -> String {
        // Tiny cache disambiguator — collisions don't matter (worst case is a
        // stale cache entry overwritten by the next call).
        var h: UInt64 = 14_695_981_039_346_656_037
        for byte in s.utf8 {
            h ^= UInt64(byte)
            h &*= 1_099_511_628_211
        }
        return String(h, radix: 16)
    }

    private struct SuccessResponse: Decodable {
        let text: String
        let modelVersion: String?
        let source: String?
    }
}

// MARK: - Cache (UserDefaults-backed, hash-keyed, TTL'd)

private enum LLMCache {
    private static let prefix = "trot.llm.cache."
    private static let expiryPrefix = "trot.llm.cacheExpiry."

    static func get(key: String) -> String? {
        let storedKey = prefix + key
        let expiryKey = expiryPrefix + key
        let expiry = UserDefaults.standard.double(forKey: expiryKey)
        guard expiry > 0, Date().timeIntervalSince1970 < expiry else {
            // Expired or missing — clean up either way.
            UserDefaults.standard.removeObject(forKey: storedKey)
            UserDefaults.standard.removeObject(forKey: expiryKey)
            return nil
        }
        return UserDefaults.standard.string(forKey: storedKey)
    }

    static func set(key: String, value: String, ttl: TimeInterval) {
        UserDefaults.standard.set(value, forKey: prefix + key)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + ttl, forKey: expiryPrefix + key)
    }
}
