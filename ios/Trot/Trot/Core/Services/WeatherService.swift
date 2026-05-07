import Foundation

/// Open-Meteo client + lightweight cache. No API key, generous free tier
/// (10k calls/day), good UK coverage. Two operations:
///
///   1. `location(for: postcode)` — geocodes a UK postcode into lat/lon. The
///      result is cached in UserDefaults forever (postcodes don't move). Saves
///      a round-trip on every weather refresh.
///   2. `forecast(for:)` — fetches the next 24 hours of hourly weather:
///      temperature, precipitation probability, weather code (sunny/cloudy/
///      rain/snow/...), wind. Cached for 30 minutes per location so opening
///      the app twice in an hour doesn't double-call.
///
/// Location is per *user*, not per dog (multi-dog households share a postcode).
/// Stored in UserDefaults via `UserPreferences`.
enum WeatherService {
    /// We previously tried Open-Meteo's geocoding endpoint, but that one
    /// resolves *place names* (e.g. "London"), not UK postcodes — every UK
    /// postcode lookup came back empty. We now hit postcodes.io directly via
    /// `URL(string:)` inside `location(for:)`. Free, no key, UK-specific.
    private static let forecastBase = URL(string: "https://api.open-meteo.com/v1/forecast")!
    private static let timeout: TimeInterval = 8

    // MARK: - Public

    /// Geocode a UK postcode into a `WeatherLocation` via postcodes.io. Cached
    /// after first successful lookup (postcodes don't move). Returns nil on
    /// network failure / unknown postcode — caller can prompt the user to
    /// re-enter.
    static func location(for postcode: String) async -> WeatherLocation? {
        let trimmed = postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let cached = UserPreferences.cachedLocation(for: trimmed) {
            return cached
        }

        // postcodes.io accepts the postcode in the URL path with or without an
        // internal space. We strip it because UK postcodes are A-Z and 0-9 only
        // once the space is gone — that gives us a guaranteed URL-safe path
        // component without having to fight Foundation's percent-encoding (
        // appendingPathComponent will re-encode an already-encoded "%20" into
        // "%2520", which silently 404s).
        let pathComponent = trimmed
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
        guard let url = URL(string: "https://api.postcodes.io/postcodes/\(pathComponent)")
        else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(PostcodesIOResponse.self, from: data)
            guard let result = decoded.result else { return nil }

            let displayName = [result.admin_district, result.region, "UK"]
                .compactMap { $0?.isEmpty == false ? $0 : nil }
                .joined(separator: ", ")
            let location = WeatherLocation(
                postcode: trimmed,
                latitude: result.latitude,
                longitude: result.longitude,
                displayName: displayName
            )
            UserPreferences.setCachedLocation(location)
            return location
        } catch {
            return nil
        }
    }

    /// Fetch the next 24 hours of hourly weather for the given location.
    /// Cached for 30 minutes per location. Returns nil on failure.
    static func forecast(for location: WeatherLocation) async -> WeatherForecast? {
        let cacheKey = "weather.forecast.\(location.latitude.rounded(toPlaces: 3))_\(location.longitude.rounded(toPlaces: 3))"
        if let cached = ForecastCache.get(key: cacheKey) {
            return cached
        }

        var components = URLComponents(url: forecastBase, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weathercode,windspeed_10m"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
        ]
        guard let url = components.url else { return nil }

        var req = URLRequest(url: url)
        req.timeoutInterval = timeout

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(ForecastResponse.self, from: data)
            guard let forecast = decoded.toForecast(location: location) else { return nil }
            ForecastCache.set(key: cacheKey, value: forecast, ttl: 30 * 60)
            return forecast
        } catch {
            return nil
        }
    }
}

// MARK: - Domain models

struct WeatherLocation: Codable, Sendable, Equatable {
    let postcode: String
    let latitude: Double
    let longitude: Double
    let displayName: String
}

struct WeatherForecast: Codable, Sendable {
    let location: WeatherLocation
    let hourly: [HourlySnapshot]
    let fetchedAt: Date

    /// Returns the snapshot closest to (and >=) the given time. Falls back to
    /// the latest snapshot if every entry is in the past.
    func snapshot(at time: Date) -> HourlySnapshot? {
        hourly.first(where: { $0.time >= time }) ?? hourly.last
    }
}

struct HourlySnapshot: Codable, Sendable, Equatable {
    let time: Date
    let temperatureC: Double
    let precipitationProbability: Int  // 0-100
    let weatherCodeRaw: Int
    let windSpeedKmh: Double

    /// Open-Meteo's WMO weather codes, bucketed into the categories we care
    /// about for walk-window judgments.
    var category: WeatherCategory {
        switch weatherCodeRaw {
        case 0:       return .clear
        case 1, 2:    return .partlyCloudy
        case 3:       return .cloudy
        case 45, 48:  return .fog
        case 51, 53, 55, 56, 57: return .drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82: return .rain
        case 71, 73, 75, 77, 85, 86: return .snow
        case 95, 96, 99: return .thunder
        default:      return .cloudy
        }
    }
}

/// Coarse buckets for UI / decisioning. Animation layer (P0h) keys off these.
enum WeatherCategory: String, Codable, Sendable {
    case clear, partlyCloudy, cloudy, fog, drizzle, rain, snow, thunder
}

// MARK: - Open-Meteo response shapes

/// postcodes.io response shape. We only care about lat/lon and admin_district
/// (used in `displayName`); the API returns ~30 fields per postcode.
private struct PostcodesIOResponse: Decodable {
    struct Result: Decodable {
        let latitude: Double
        let longitude: Double
        let admin_district: String?
        let region: String?
    }
    let status: Int
    let result: Result?
}

private struct ForecastResponse: Decodable {
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let precipitation_probability: [Int?]
        let weathercode: [Int]
        let windspeed_10m: [Double]
    }
    let hourly: Hourly?

    func toForecast(location: WeatherLocation) -> WeatherForecast? {
        guard let h = hourly else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        // Open-Meteo timestamps are local-without-tz when timezone=auto. Append Z for parsing.
        let snapshots: [HourlySnapshot] = h.time.enumerated().compactMap { index, str in
            // Try direct ISO8601 first; fall back to the simple yyyy-MM-ddTHH:mm form.
            if let d = formatter.date(from: str + ":00Z") {
                return makeSnapshot(at: d, index: index, h: h)
            }
            // Fallback parser
            let fb = DateFormatter()
            fb.locale = Locale(identifier: "en_US_POSIX")
            fb.dateFormat = "yyyy-MM-dd'T'HH:mm"
            fb.timeZone = TimeZone.current
            if let d = fb.date(from: str) {
                return makeSnapshot(at: d, index: index, h: h)
            }
            return nil
        }
        return WeatherForecast(location: location, hourly: snapshots, fetchedAt: .now)
    }

    private func makeSnapshot(at time: Date, index: Int, h: Hourly) -> HourlySnapshot {
        HourlySnapshot(
            time: time,
            temperatureC: h.temperature_2m[safe: index] ?? 0,
            precipitationProbability: h.precipitation_probability[safe: index].flatMap { $0 } ?? 0,
            weatherCodeRaw: h.weathercode[safe: index] ?? 0,
            windSpeedKmh: h.windspeed_10m[safe: index] ?? 0
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let multiplier = pow(10.0, Double(places))
        return (self * multiplier).rounded() / multiplier
    }
}

// MARK: - Forecast cache (30-min TTL, UserDefaults JSON-encoded)

private enum ForecastCache {
    private static let valuePrefix = "trot.weather.forecast."
    private static let expiryPrefix = "trot.weather.forecastExpiry."

    static func get(key: String) -> WeatherForecast? {
        let expiry = UserDefaults.standard.double(forKey: expiryPrefix + key)
        guard expiry > 0, Date().timeIntervalSince1970 < expiry else {
            UserDefaults.standard.removeObject(forKey: valuePrefix + key)
            UserDefaults.standard.removeObject(forKey: expiryPrefix + key)
            return nil
        }
        guard let data = UserDefaults.standard.data(forKey: valuePrefix + key) else { return nil }
        return try? JSONDecoder.iso8601.decode(WeatherForecast.self, from: data)
    }

    static func set(key: String, value: WeatherForecast, ttl: TimeInterval) {
        guard let data = try? JSONEncoder.iso8601.encode(value) else { return }
        UserDefaults.standard.set(data, forKey: valuePrefix + key)
        UserDefaults.standard.set(Date().timeIntervalSince1970 + ttl, forKey: expiryPrefix + key)
    }
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
