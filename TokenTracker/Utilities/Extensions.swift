import SwiftUI
import Foundation

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Number Formatters

extension Int64 {
    /// Format token count: 1234567 → "1.2M"
    var formattedTokens: String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", Double(self) / 1_000_000_000)
        } else if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000)
        }
        return "\(self)"
    }
}

extension Double {
    /// Format currency: 12.5 → "$12.50" or "¥12.50" or "1.2M Tokens"
    func formattedCurrency(_ currency: String) -> String {
        let trimmedCurrency = currency.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCurrency.isEmpty {
            return formattedQuotaValue
        }

        // Special case for non-monetary units like tokens or generic quota
        if trimmedCurrency == "Tokens" {
            return Int64(self).formattedTokens + " " + trimmedCurrency
        }
        if trimmedCurrency.contains("单位") || trimmedCurrency.contains("额度") {
            return formattedQuotaValue
        }
        
        let symbol: String
        switch trimmedCurrency.uppercased() {
        case "USD": symbol = "$"
        case "CNY", "RMB": symbol = "¥"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        default: symbol = trimmedCurrency + " "
        }
        return String(format: "%@%.2f", symbol, self)
    }
    
    /// Format as percentage: 0.75 → "75%"
    var formattedPercentage: String {
        String(format: "%.1f%%", self * 100)
    }

    /// Format plain quota numbers without currency/unit decorations.
    var formattedQuotaValue: String {
        Int64(max(self, 0)).formattedTokens
    }

    /// Format as balance/amount with currency symbol
    func formattedBalanceValue(_ currency: String) -> String {
        let symbol: String
        switch currency.uppercased() {
        case "USD": symbol = "$"
        case "CNY", "RMB": symbol = "¥"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        default: symbol = ""
        }
        return String(format: "%@%.2f", symbol, self)
    }
}

extension Date {
    /// "11:05 AM" style
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    
    /// Start of today at midnight
    static var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    /// N days ago from now
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
}
