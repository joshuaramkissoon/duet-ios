//
//  CreditModels.swift
//  Duet
//
//  Created by Joshua Ramkissoon on 20/12/2024.
//

import Foundation

// MARK: - User Credits Response
struct UserCredits: Codable {
    let credits: Int
}

// MARK: - Credit Transaction
struct CreditTransaction: Codable, Identifiable {
    let id: Int
    let amount: Int
    let transactionType: String
    let stripePaymentIntentId: String?
    let description: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, amount, description
        case transactionType = "transaction_type"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case createdAt = "created_at"
    }
    
    // MARK: - Computed Properties
    var transactionTypeDisplayName: String {
        switch transactionType.lowercased() {
        case "usage":
            return "Used"
        case "purchase":
            return "Purchased"
        case "bonus":
            return "Bonus"
        case "level_up_bonus":
            return "Level Up Bonus"
        case "refund":
            return "Refunded"
        default:
            return transactionType.capitalized
        }
    }
    
    var isPositive: Bool {
        return amount > 0
    }
    
    var formattedAmount: String {
        let prefix = isPositive ? "+" : ""
        return "\(prefix)\(amount)"
    }
    
    var formattedDate: String {
        guard let date = parseDate() else {
            return "Recently"
        }
        
        let formatter = DateFormatter()
        
        // Check if date is today
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Today at \(formatter.string(from: date))"
        }
        
        // Check if date is yesterday
        if Calendar.current.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Yesterday at \(formatter.string(from: date))"
        }
        
        // Check if date is this week
        if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE 'at' HH:mm"
            return formatter.string(from: date)
        }
        
        // Default format for older dates
        formatter.dateFormat = "MMM d 'at' HH:mm"
        return formatter.string(from: date)
    }
    
    private func parseDate() -> Date? {
        // Try multiple parsing approaches for the date string
        var date: Date?
        
        // 1. Try ISO8601DateFormatter with fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = iso8601Formatter.date(from: createdAt)
        
        // 2. Try ISO8601DateFormatter without fractional seconds
        if date == nil {
            iso8601Formatter.formatOptions = [.withInternetDateTime]
            date = iso8601Formatter.date(from: createdAt)
        }
        
        // 3. Try custom DateFormatter for the exact format
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            customFormatter.timeZone = TimeZone(abbreviation: "UTC")
            date = customFormatter.date(from: createdAt)
        }
        
        // 4. Try custom DateFormatter without microseconds
        if date == nil {
            let customFormatter = DateFormatter()
            customFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            customFormatter.timeZone = TimeZone(abbreviation: "UTC")
            date = customFormatter.date(from: createdAt)
        }
        
        return date
    }
}

// MARK: - Credit History Response
struct CreditHistory: Codable {
    let transactions: [CreditTransaction]
}

// MARK: - Insufficient Credits Error
struct InsufficientCreditsError: Codable {
    let errorCode: String
    let message: String
    let requiredAction: String
    
    enum CodingKeys: String, CodingKey {
        case errorCode = "error_code"
        case message
        case requiredAction = "required_action"
    }
}

// MARK: - Credit Error Response
struct CreditErrorResponse: Codable {
    let detail: InsufficientCreditsError
}

// MARK: - Add Credits Request (Admin)
struct AddCreditsRequest: Codable {
    let userId: String
    let amount: Int
    let reason: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case amount
        case reason
    }
}

// MARK: - Add Credits Response
struct AddCreditsResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Stripe Checkout Models
struct CreditPackage: Codable {
    let id: String
    let name: String
    let credits: Int
    let priceCents: Int
    let badge: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, credits, badge
        case priceCents = "price_cents"
    }
    
    func price(currency: String = "gbp") -> String {
        let amount = Double(priceCents) / 100.0
        let currencySymbol = currencySymbol(for: currency)
        return "\(currencySymbol)\(String(format: "%.2f", amount))"
    }
    
    private func currencySymbol(for currency: String) -> String {
        switch currency.lowercased() {
        case "usd":
            return "$"
        case "gbp":
            return "£"
        case "eur":
            return "€"
        case "cad":
            return "C$"
        case "aud":
            return "A$"
        default:
            return "£" // Default to GBP
        }
    }
    
    var videoCount: String {
        return "\(credits)"
    }
    
    var savingsPercentage: Int {
        // Calculation based on a base price of 10 credits for 1.99
        let basePrice = 1.99
        let packagePrice = Double(priceCents) / 100.0
        let pricePerCredit = packagePrice / Double(credits)
        let basePricePerCredit = basePrice / 10.0
        let savings = (basePricePerCredit - pricePerCredit) / basePricePerCredit * 100
        return max(0, Int(savings))
    }
}

struct CreditPackagesResponse: Codable {
    let packages: [CreditPackage]
    let currency: String?
    
    var effectiveCurrency: String {
        return currency ?? "gbp"
    }
}

struct CreateCheckoutSessionRequest: Codable {
    let packageId: String
    
    enum CodingKeys: String, CodingKey {
        case packageId = "package_id"
    }
}

struct CreateCheckoutSessionResponse: Codable {
    let sessionId: String
    let url: String
    let package: CreditPackage
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case url
        case package
    }
}

// MARK: - Legacy Stripe Models (deprecated)
struct StripeCheckoutRequest: Codable {
    let creditAmount: Int
    let successUrl: String
    let cancelUrl: String
    
    enum CodingKeys: String, CodingKey {
        case creditAmount = "credit_amount"
        case successUrl = "success_url"
        case cancelUrl = "cancel_url"
    }
}

struct StripeCheckoutResponse: Codable {
    let checkoutUrl: String
    let sessionId: String?
    
    enum CodingKeys: String, CodingKey {
        case checkoutUrl = "checkout_url"
        case sessionId = "session_id"
    }
}

// MARK: - Welcome Credits Response
struct WelcomeCreditsResponse: Codable {
    let welcomeCredits: Int
    let levelUpBonus: Int
    
    enum CodingKeys: String, CodingKey {
        case welcomeCredits = "welcome_credits"
        case levelUpBonus = "level_up_bonus"
    }
} 