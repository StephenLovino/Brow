import Foundation
import Sparkle

/// Wraps Sparkle. Only runs inside the packaged Brow.app: a bare `swift run` binary has no
/// bundle, feed URL or public key, so update checks there would just fail.
final class Updater {
    private let controller: SPUStandardUpdaterController?

    init() {
        guard Bundle.main.bundleIdentifier != nil,
              Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else {
            controller = nil
            return
        }
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var isAvailable: Bool { controller != nil }

    var canCheckForUpdates: Bool { controller?.updater.canCheckForUpdates ?? false }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyInstalls: Bool {
        get { controller?.updater.automaticallyDownloadsUpdates ?? false }
        set { controller?.updater.automaticallyDownloadsUpdates = newValue }
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
