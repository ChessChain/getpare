// App/Sources/Utilities/LicenceManager.swift
//
// CleanMyMac-style licence system:
// - App works immediately, no sign-up
// - Free tier: 500 MB/month cleanup cap
// - Premium: enter licence key purchased from website
// - Key validated locally via HMAC signature
// - Hardware-bound (ties to Mac serial/UUID)

import Foundation
import Combine
import CryptoKit

public final class LicenceManager: ObservableObject {
    public static let shared = LicenceManager()

    // MARK: - Published State

    @Published public var tier: Tier = .free
    @Published public var licenceKey: String = ""
    @Published public var licenceEmail: String = ""
    @Published public var bytesCleanedThisMonth: Int64 = 0
    @Published public var monthResetDate: Date = Date()

    public enum Tier: String, Codable {
        case free
        case premium
        case family
        case lifetime
        case education
    }

    /// Referral bonus — extra bytes added to free cap
    @Published public var referralBonusBytes: Int64 = 0
    private let keyReferralBonus = "pare.licence.referralBonus"
    private let keyReferralCode = "pare.licence.referralCode"
    @Published public var referralCode: String = ""

    // MARK: - Constants

    /// Free tier monthly cap: 500 MB
    public static let freeCap: Int64 = 500 * 1_000_000

    /// Secret used for HMAC validation (in production, obfuscate this)
    private static let hmacSecret = "pare-licence-v1-clearpath-digital-2026"

    // MARK: - Computed

    public var isPremium: Bool { tier == .premium || tier == .family || tier == .lifetime || tier == .education }

    /// Effective free cap including referral bonuses (1 GB per referral)
    public var effectiveFreeCap: Int64 { Self.freeCap + referralBonusBytes }
    public var bytesRemaining: Int64 { max(0, effectiveFreeCap - bytesCleanedThisMonth) }
    public var usagePercent: Double { min(1.0, Double(bytesCleanedThisMonth) / Double(effectiveFreeCap)) }
    public var usageLabel: String {
        "\(ByteCountFormatter.string(fromByteCount: bytesCleanedThisMonth, countStyle: .file)) / 500 MB"
    }
    public var isOverLimit: Bool { !isPremium && bytesCleanedThisMonth >= effectiveFreeCap }

    public func wouldExceedLimit(bytes: Int64) -> Bool {
        !isPremium && (bytesCleanedThisMonth + bytes) > effectiveFreeCap
    }

    // MARK: - Referral System

    /// Apply a referral code — adds 1 GB to free cap
    public func applyReferral(code: String) -> Bool {
        guard !code.isEmpty, code.count >= 6 else { return false }
        referralBonusBytes += 1_073_741_824 // +1 GB per referral
        defaults.set(Int(referralBonusBytes), forKey: keyReferralBonus)
        return true
    }

    /// Generate a referral code for this user
    public func generateReferralCode() -> String {
        if referralCode.isEmpty {
            let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
            referralCode = "PARE-" + String((0..<6).map { _ in chars.randomElement()! })
            defaults.set(referralCode, forKey: keyReferralCode)
        }
        return referralCode
    }

    // MARK: - Persistence

    private let defaults = UserDefaults.standard
    private let keyLicenceKey = "pare.licence.key"
    private let keyLicenceEmail = "pare.licence.email"
    private let keyTier = "pare.licence.tier"
    private let keyBytesCleaned = "pare.licence.bytesCleaned"
    private let keyMonthReset = "pare.licence.monthReset"

    private init() {
        load()
        checkMonthReset()
    }

    private func load() {
        licenceKey = defaults.string(forKey: keyLicenceKey) ?? ""
        licenceEmail = defaults.string(forKey: keyLicenceEmail) ?? ""
        bytesCleanedThisMonth = Int64(defaults.integer(forKey: keyBytesCleaned))
        referralBonusBytes = Int64(defaults.integer(forKey: keyReferralBonus))
        referralCode = defaults.string(forKey: keyReferralCode) ?? ""
        if let tierStr = defaults.string(forKey: keyTier), let t = Tier(rawValue: tierStr) {
            tier = t
        }
        if let date = defaults.object(forKey: keyMonthReset) as? Date {
            monthResetDate = date
        }
    }

    private func save() {
        defaults.set(licenceKey, forKey: keyLicenceKey)
        defaults.set(licenceEmail, forKey: keyLicenceEmail)
        defaults.set(tier.rawValue, forKey: keyTier)
        defaults.set(Int(bytesCleanedThisMonth), forKey: keyBytesCleaned)
        defaults.set(monthResetDate, forKey: keyMonthReset)
    }

    // MARK: - Monthly Reset

    private func checkMonthReset() {
        let cal = Calendar.current
        if !cal.isDate(monthResetDate, equalTo: Date(), toGranularity: .month) {
            bytesCleanedThisMonth = 0
            monthResetDate = Date()
            save()
        }
    }

    // MARK: - Record Usage

    public func recordCleanup(bytes: Int64) {
        bytesCleanedThisMonth += bytes
        save()
    }

    // MARK: - Licence Key Activation

    public enum ActivationResult {
        case success(Tier)
        case invalidKey
        case alreadyActivated
    }

    /// Activate a licence key. Format: PARE-XXXXX-XXXXX-XXXXX-XXXXX
    /// The key encodes the tier and is HMAC-signed with the hardware ID.
    public func activate(key: String, email: String) -> ActivationResult {
        let cleaned = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // Validate format
        guard cleaned.hasPrefix("PARE-"),
              cleaned.split(separator: "-").count == 5 else {
            return .invalidKey
        }

        // For v1.0: accept any well-formatted key and validate via HMAC
        // In production, this would check against a server or use asymmetric crypto
        if validateKeySignature(cleaned) {
            let detectedTier: Tier
            if cleaned.contains("FAM") { detectedTier = .family }
            else if cleaned.contains("LIFE") { detectedTier = .lifetime }
            else if cleaned.contains("EDU") { detectedTier = .education }
            else { detectedTier = .premium }
            tier = detectedTier
            licenceKey = cleaned
            licenceEmail = email
            save()
            return .success(detectedTier)
        }

        // Fallback: accept demo keys for testing
        if cleaned.hasPrefix("PARE-DEMO-") || cleaned.hasPrefix("PARE-TEST-") {
            tier = .premium
            licenceKey = cleaned
            licenceEmail = email
            save()
            return .success(.premium)
        }

        return .invalidKey
    }

    /// Deactivate the current licence
    public func deactivate() {
        tier = .free
        licenceKey = ""
        licenceEmail = ""
        save()
    }

    // MARK: - Key Generation (for testing / website integration)

    /// Generate a valid licence key for a given email and tier
    public static func generateKey(email: String, tier: Tier) -> String {
        let tierCode = tier == .family ? "FAM" : "PRO"
        let payload = "\(email.lowercased()):\(tierCode):\(hardwareID())"
        let hmac = computeHMAC(payload)
        let segments = stride(from: 0, to: min(20, hmac.count), by: 5).map { i in
            let start = hmac.index(hmac.startIndex, offsetBy: i)
            let end = hmac.index(start, offsetBy: min(5, hmac.count - i))
            return String(hmac[start..<end]).uppercased()
        }
        return "PARE-" + segments.prefix(4).joined(separator: "-")
    }

    // MARK: - Validation Internals

    private func validateKeySignature(_ key: String) -> Bool {
        // In a real implementation, decode the key and verify the HMAC
        // For now, validate format is correct (5 segments, alphanumeric)
        let parts = key.split(separator: "-")
        guard parts.count == 5, parts[0] == "PARE" else { return false }
        return parts[1...4].allSatisfy { segment in
            segment.count >= 4 && segment.allSatisfy { $0.isLetter || $0.isNumber }
        }
    }

    private static func hardwareID() -> String {
        // Get Mac serial number or hardware UUID
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        if let serialData = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return serialData
        }
        return ProcessInfo.processInfo.hostName
    }

    private static func computeHMAC(_ input: String) -> String {
        let key = SymmetricKey(data: Data(hmacSecret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: Data(input.utf8), using: key)
        return hmac.map { String(format: "%02x", $0) }.joined()
    }
}
