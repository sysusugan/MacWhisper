import Foundation
import Combine
import CryptoKit

/// Manages license validation, trial period, and activation state.
/// Designed to work with Paddle, LemonSqueezy, or a custom license server.
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    // MARK: - Published State

    @Published private(set) var licenseState: LicenseState = .checking
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var licenseEmail: String = ""

    // MARK: - Configuration

    /// How many days the free trial lasts
    static let trialDurationDays = 14

    /// License validation endpoint (set this to your Paddle/Lemon Squeezy/custom server URL)
    /// Example for LemonSqueezy: "https://api.lemonsqueezy.com/v1/licenses/validate"
    static let validationURL = "VALIDATION_URL_PLACEHOLDER"

    // MARK: - Storage Keys

    private enum Keys {
        static let licenseKey = "psst_license_key"
        static let licenseEmail = "psst_license_email"
        static let licenseValid = "psst_license_valid"
        static let trialStartDate = "psst_trial_start"
        static let activationDate = "psst_activation_date"
    }

    // MARK: - Init

    init() {
        checkLicenseStatus()
    }

    // MARK: - Public API

    /// Check current license/trial status on launch
    func checkLicenseStatus() {
        // Check for existing valid license
        if let key = storedLicenseKey, isLocallyValid(key) {
            licenseState = .licensed
            licenseEmail = UserDefaults.standard.string(forKey: Keys.licenseEmail) ?? ""
            // Periodic online revalidation (non-blocking)
            Task { await revalidateOnline(key: key) }
            return
        }

        // Check trial status
        let trialStart = getOrCreateTrialStart()
        let elapsed = Calendar.current.dateComponents([.day], from: trialStart, to: Date()).day ?? 0
        let remaining = max(0, Self.trialDurationDays - elapsed)
        trialDaysRemaining = remaining

        if remaining > 0 {
            licenseState = .trial
        } else {
            licenseState = .expired
        }
    }

    /// Activate a license key (called from UI)
    func activate(key: String, email: String) async -> ActivationResult {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            return .failure("Please enter a license key.")
        }

        // Online validation
        let result = await validateOnline(key: trimmedKey, email: trimmedEmail)

        switch result {
        case .success:
            // Store locally
            UserDefaults.standard.set(trimmedKey, forKey: Keys.licenseKey)
            UserDefaults.standard.set(trimmedEmail, forKey: Keys.licenseEmail)
            UserDefaults.standard.set(true, forKey: Keys.licenseValid)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.activationDate)

            licenseState = .licensed
            licenseEmail = trimmedEmail
            return .success("License activated successfully!")

        case .failure(let message):
            return .failure(message)
        }
    }

    /// Deactivate the current license
    func deactivate() {
        UserDefaults.standard.removeObject(forKey: Keys.licenseKey)
        UserDefaults.standard.removeObject(forKey: Keys.licenseEmail)
        UserDefaults.standard.removeObject(forKey: Keys.licenseValid)
        UserDefaults.standard.removeObject(forKey: Keys.activationDate)

        licenseState = .expired
        licenseEmail = ""
        checkLicenseStatus()
    }

    /// Whether the app should allow full functionality
    var isUnlocked: Bool {
        switch licenseState {
        case .licensed, .trial:
            return true
        case .expired, .checking:
            return false
        }
    }

    // MARK: - Private

    private var storedLicenseKey: String? {
        UserDefaults.standard.string(forKey: Keys.licenseKey)
    }

    /// Basic local check — key exists and was previously validated
    private func isLocallyValid(_ key: String) -> Bool {
        return UserDefaults.standard.bool(forKey: Keys.licenseValid) && !key.isEmpty
    }

    /// Get the trial start date, creating one if this is first launch
    private func getOrCreateTrialStart() -> Date {
        let defaults = UserDefaults.standard
        if let timestamp = defaults.object(forKey: Keys.trialStartDate) as? Double {
            return Date(timeIntervalSince1970: timestamp)
        }
        let now = Date()
        defaults.set(now.timeIntervalSince1970, forKey: Keys.trialStartDate)
        return now
    }

    /// Non-blocking revalidation for existing licenses
    private func revalidateOnline(key: String) async {
        // Skip if validation URL not configured yet
        guard Self.validationURL != "VALIDATION_URL_PLACEHOLDER" else { return }

        let result = await validateOnline(key: key, email: licenseEmail)
        if case .failure = result {
            // Grace period: don't immediately invalidate if server is unreachable
            // Only invalidate after multiple consecutive failures
            let failCount = UserDefaults.standard.integer(forKey: "psst_validation_fail_count")
            if failCount >= 3 {
                licenseState = .expired
                UserDefaults.standard.set(false, forKey: Keys.licenseValid)
            } else {
                UserDefaults.standard.set(failCount + 1, forKey: "psst_validation_fail_count")
            }
        } else {
            UserDefaults.standard.set(0, forKey: "psst_validation_fail_count")
        }
    }

    /// Online license validation (adapt this for your payment provider)
    private func validateOnline(key: String, email: String) async -> ActivationResult {
        guard Self.validationURL != "VALIDATION_URL_PLACEHOLDER",
              let url = URL(string: Self.validationURL) else {
            // No validation server configured — accept key locally for development
            return .success("License accepted (offline mode).")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Adapt this payload to your payment provider's API:
        //
        // LemonSqueezy: { "license_key": "...", "instance_name": "..." }
        // Paddle:       { "license_code": "...", "product_id": "..." }
        // Custom:       { "key": "...", "email": "...", "machine_id": "..." }
        let payload: [String: String] = [
            "license_key": key,
            "instance_name": machineIdentifier
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid server response.")
            }

            if httpResponse.statusCode == 200 {
                // Parse response — adapt to your provider's format
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let valid = json["valid"] as? Bool, valid {
                    return .success("License validated.")
                }
                // LemonSqueezy format
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let activated = json["activated"] as? Bool, activated {
                    return .success("License activated.")
                }
                return .failure("License key is not valid.")
            } else if httpResponse.statusCode == 404 {
                return .failure("License key not found.")
            } else {
                return .failure("Validation failed (status \(httpResponse.statusCode)).")
            }
        } catch {
            return .failure("Could not reach license server. Check your connection.")
        }
    }

    /// Stable machine identifier for license binding
    private var machineIdentifier: String {
        let platformExpert = IOServiceGetMatchingService(
            kIOMasterPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        defer { IOObjectRelease(platformExpert) }

        if let serialData = IORegistryEntryCreateCFProperty(
            platformExpert,
            "IOPlatformSerialNumber" as CFString,
            kCFAllocatorDefault, 0
        )?.takeRetainedValue() as? String {
            // Hash it so we don't send raw serial numbers
            let hash = SHA256.hash(data: Data(serialData.utf8))
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        return UUID().uuidString
    }
}

// MARK: - Types

enum LicenseState: Equatable {
    case checking
    case trial
    case licensed
    case expired
}

enum ActivationResult {
    case success(String)
    case failure(String)
}
