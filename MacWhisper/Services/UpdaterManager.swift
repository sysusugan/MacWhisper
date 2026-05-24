import Foundation
import Sparkle

/// Manages Sparkle auto-updates for direct (non-App Store) distribution.
/// Checks an appcast XML feed for new versions and handles download + install.
@MainActor
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController?

    @Published var canCheckForUpdates = false

    init() {
        guard Self.hasValidSparkleConfiguration else {
            print("UpdaterManager: Sparkle disabled because update signing is not configured")
            updaterController = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller

        // Observe Sparkle's canCheckForUpdates property
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    /// The appcast URL is set in Info.plist via SUFeedURL.
    /// To configure: add your appcast URL to Info.plist before shipping.
    private static var hasValidSparkleConfiguration: Bool {
        guard let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String else {
            return false
        }

        return !publicKey.isEmpty && publicKey != "SPARKLE_ED25519_PUBLIC_KEY_PLACEHOLDER"
    }
}
