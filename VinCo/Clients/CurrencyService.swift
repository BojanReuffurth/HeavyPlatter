import Foundation
import SwiftData

/// Fetches exchange rates from api.frankfurter.app (free, no API key required).
struct CurrencyService {
    /// Returns the rate to multiply values by when converting from `from` to `to`.
    /// Returns nil on network/parse failure.
    static func rate(from: String, to: String) async -> Double? {
        guard from != to else { return 1.0 }
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=\(from)&to=\(to)")
        else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let resp = try JSONDecoder().decode(FXResp.self, from: data)
            return resp.rates[to]
        } catch { return nil }
    }

    /// Converts all paidPrice and currentValue on every record in `records`
    /// from `oldCode` to `newCode` using a live exchange rate.
    /// Returns a human-readable result message.
    @MainActor
    static func convertAll(records: [Record],
                           from oldCode: String,
                           to newCode: String) async -> String {
        guard oldCode != newCode else { return "Currency updated." }
        guard let r = await rate(from: oldCode, to: newCode) else {
            return "Could not fetch exchange rate — values unchanged."
        }
        var count = 0
        for rec in records {
            if let p = rec.paidPrice    { rec.paidPrice    = p * r; count += 1 }
            if let v = rec.currentValue { rec.currentValue = v * r }
        }
        return String(format: "Converted %d records at 1 %@ = %.4f %@", count, oldCode, r, newCode)
    }
}

private nonisolated struct FXResp: Decodable {
    let rates: [String: Double]
}
