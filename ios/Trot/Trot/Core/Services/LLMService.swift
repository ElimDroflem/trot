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

    /// Post-walk celebration line. No cache — each walk save is a fresh call.
    static func walkCompleteLine(
        for dog: Dog,
        minutes: Int,
        isFirstWalk: Bool,
        landmarksHit: [String],
        routeName: String?,
        nextLandmarkName: String?
    ) async -> String? {
        let context: [String: any Sendable] = [
            "minutes": minutes,
            "isFirstWalk": isFirstWalk,
            "landmarksHit": landmarksHit,
            "routeName": routeName ?? "",
            "nextLandmarkName": nextLandmarkName ?? "",
        ]
        return await request(kind: .walkComplete, dog: dog, context: context)
    }

    /// Insight tab "Luna says…" row. Refreshed weekly.
    static func insightLine(
        for dog: Dog,
        pattern: String,
        detail: String,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String? {
        let weekKey = Self.localWeekKey(now, calendar: calendar)
        let cacheKey = "insight.\(dog.persistentModelID.hashValue).\(weekKey).\(stableHash(pattern + detail))"
        if let hit = LLMCache.get(key: cacheKey) { return hit }

        let context: [String: any Sendable] = ["pattern": pattern, "detail": detail]
        guard let text = await request(kind: .insight, dog: dog, context: context) else { return nil }
        LLMCache.set(key: cacheKey, value: text, ttl: 60 * 60 * 24 * 7)
        return text
    }

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

    // MARK: - Internals

    private static func request(
        kind: Kind,
        dog: Dog,
        context: [String: any Sendable]
    ) async -> String? {
        let url = proxyBase.appendingPathComponent("api/dog-voice")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = timeout

        let body: [String: any Sendable] = [
            "installToken": InstallTokenService.token(),
            "kind": kind.rawValue,
            "dog": dogPayload(dog),
            "context": context,
        ]

        guard let payload = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            return nil
        }
        req.httpBody = payload

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(SuccessResponse.self, from: data)
            let trimmed = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
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
