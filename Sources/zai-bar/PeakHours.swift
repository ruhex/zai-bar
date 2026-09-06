import Foundation

/// z.ai coding-plan peak-hours rules.
///
/// Peak = 14:00–18:00 in UTC+8 (China time). During peak, advanced models
/// (GLM-5.2 / GLM-5-Turbo) consume quota at 3×; off-peak normally 2×, but a
/// limited-time promo makes off-peak 1× through the end of September.
/// GLM-4.7 is always 1×.
enum PeakHours {
    /// China Standard Time is UTC+8 year-round (no DST) — the reference for peak hours.
    static let timezone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!
    static let startHour = 14
    static let endHour = 18 // exclusive

    /// Per-model quota multipliers as z.ai publishes them. Neither the monitor
    /// API nor the model catalog (/api/paas/v4/models) exposes rates, so this
    /// table is the single place to edit when the lineup or rates change.
    /// GLM-5.3 / 5.3-Flash rates follow the 2026-07-30 usage revision
    /// (docs.z.ai/devpack/notice/usage-revision); the legacy-plan promo keeps
    /// advanced models at 1× off-peak through 2026-10-01.
    struct ModelRate {
        let model: String
        let peak: String
        let offPeak: String
    }

    static func modelRates(at date: Date = .now) -> [ModelRate] {
        let advancedOff = promoActive(at: date) ? "1× (promo)" : "2×"
        return [
            ModelRate(model: "GLM-5.2 / 5-Turbo", peak: "3×", offPeak: advancedOff),
            ModelRate(model: "GLM-5.3",           peak: "3×", offPeak: "1×"),
            ModelRate(model: "GLM-5.3-Flash",     peak: "1.2×", offPeak: "0.4×"),
            ModelRate(model: "GLM-4.7",           peak: "1×", offPeak: "1×"),
        ]
    }

    static func isPeak(at date: Date = .now) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        let h = cal.component(.hour, from: date)
        return h >= startHour && h < endHour
    }

    /// Promo: off-peak advanced-model quota is 1× (instead of 2×) through end of September 2026.
    static func promoActive(at date: Date = .now) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 1
        guard let end = cal.date(from: c) else { return false }
        return date < end
    }

    /// Effective quota multiplier for advanced models (GLM-5.2 / GLM-5-Turbo).
    static func advancedMultiplier(at date: Date = .now) -> Int {
        if isPeak(at: date) { return 3 }
        return promoActive(at: date) ? 1 : 2
    }

    /// The peak window of the current Shanghai day as instants; format these in the
    /// user's LOCAL timezone to show "peak at HH:mm–HH:mm your time".
    static func window(at date: Date = .now) -> (start: Date, end: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone
        var c = cal.dateComponents([.year, .month, .day], from: date)
        c.hour = startHour; c.minute = 0; c.second = 0
        guard let start = cal.date(from: c) else { return (date, date) }
        let end = start.addingTimeInterval(TimeInterval((endHour - startHour) * 3600))
        return (start, end)
    }
}
