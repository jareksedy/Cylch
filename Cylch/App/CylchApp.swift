
import SwiftUI
import AppKit
import FirebaseCore

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var waitingForFadeOut = false
    private var fadeOutWatchdog: Task<Void, Never>?

    /// Upper bound on waiting for the fade-out to report back. A serial device that
    /// stopped draining leaves the stream thread blocked in write(2), so the fade-out
    /// completion never arrives and the app would otherwise never quit.
    private static let fadeOutTimeout: Duration = .seconds(2)

    static func main() {
        if getenv("XCODE_RUNNING_FOR_PREVIEWS") != nil {
            CylchPreviewLifecycle.main()
            return
        }

        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseApp.configure()

        let viewModel = SettingsViewModel.shared
        viewModel.autoConnectOnLaunch()
        menuBarController = MenuBarController(viewModel: viewModel)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !waitingForFadeOut else { return .terminateLater }

        let startedFadeOut = SettingsViewModel.shared.fadeOutForTermination { [weak self, weak sender] in
            self?.finishTermination(replyingTo: sender)
        }

        guard startedFadeOut else { return .terminateNow }

        waitingForFadeOut = true
        fadeOutWatchdog = Task { [weak self, weak sender] in
            try? await Task.sleep(for: Self.fadeOutTimeout)
            guard !Task.isCancelled else { return }
            self?.finishTermination(replyingTo: sender)
        }

        return .terminateLater
    }

    private func finishTermination(replyingTo application: NSApplication?) {
        guard waitingForFadeOut else { return }

        waitingForFadeOut = false
        fadeOutWatchdog?.cancel()
        fadeOutWatchdog = nil
        application?.reply(toApplicationShouldTerminate: true)
    }
}

private struct CylchPreviewLifecycle: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
