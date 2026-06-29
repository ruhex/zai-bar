import Foundation
import SwiftUI

// MARK: - API response models (https://api.z.ai/api/monitor/usage/quota/limit)

struct QuotaResponse: Decodable {
    let code: Int?
    let msg: String?
    let success: Bool?
    let data: QuotaData?
}

struct QuotaData: Decodable {
    /// Plan tier as reported by the API, e.g. "pro".
    let level: String?
    let limits: [Limit]?
}

struct Limit: Decodable, Identifiable {
    /// "TOKENS_LIMIT" (model tokens) or "TIME_LIMIT" (web-tool / MCP calls).
    let type: String
    /// Window unit: 3 = hours (5h session), 6 = weeks, 5 = month.
    let unit: Int?
    let number: Int?
    /// Total budget for the window (may be absent for some limit types).
    let usage: Double?
    /// How much has been consumed.
    let currentValue: Double?
    let remaining: Double?
    /// 0...100.
    let percentage: Double?
    /// Epoch milliseconds.
    let nextResetTime: Int64?
    let usageDetails: [UsageDetail]?

    var id: String { "\(type)-\(unit ?? 0)-\(number ?? 0)" }
}

struct UsageDetail: Decodable, Identifiable {
    let modelCode: String?
    let usage: Double?
    var id: String { modelCode ?? "—" }
}

extension Limit {
    /// Friendly label derived from the (type, unit) window coding.
    var kindLabel: String {
        switch type {
        case "TOKENS_LIMIT":
            switch unit {
            case 3:  return "Tokens · 5-hour window"
            case 6:  return "Tokens · weekly"
            default: return "Tokens"
            }
        case "TIME_LIMIT":
            switch unit {
            case 5:  return "Web tools · monthly calls"
            default: return "Tool usage"
            }
        default:
            return type.replacingOccurrences(of: "_LIMIT", with: "").lowercased()
        }
    }

    var resetDate: Date? {
        guard let ms = nextResetTime else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
    }

    /// Display order in the popover: 5h tokens first (matches the tray headline),
    /// then weekly tokens, then web tools, then anything else.
    var displayOrder: Int {
        switch type {
        case "TOKENS_LIMIT":
            switch unit { case 3: return 0; case 6: return 1; default: return 2 }
        case "TIME_LIMIT":
            return 10
        default:
            return 20
        }
    }
}

// MARK: - Formatting helpers

func statusColor(forPercentage pct: Double) -> Color {
    switch pct {
    case ..<60:  return .green
    case ..<85:  return .orange
    default:     return .red
    }
}

func countdownString(to target: Date?, now: Date) -> String {
    guard let target else { return "—" }
    let s = target.timeIntervalSince(now)
    if s <= 0 { return "now" }
    let days  = Int(s) / 86400
    let hours = (Int(s) % 86400) / 3600
    let mins  = (Int(s) % 3600) / 60
    if days > 0  { return "\(days)d \(hours)h" }
    if hours > 0 { return "\(hours)h \(mins)m" }
    return "\(mins)m"
}

func compactNumber(_ v: Double?) -> String {
    guard let v else { return "—" }
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
}
