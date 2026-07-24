
import SwiftUI
import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var waitingForFadeOut = false

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
        let viewModel = SettingsViewModel.shared
        viewModel.autoConnectOnLaunch()
        menuBarController = MenuBarController(viewModel: viewModel)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !waitingForFadeOut else { return .terminateLater }

        let startedFadeOut = SettingsViewModel.shared.fadeOutForTermination { [weak self, weak sender] in
            self?.waitingForFadeOut = false
            sender?.reply(toApplicationShouldTerminate: true)
        }

        guard startedFadeOut else { return .terminateNow }
        waitingForFadeOut = true
        return .terminateLater
    }
}

private struct CylchPreviewLifecycle: App {
    var body: some Scene {
        WindowGroup {
            Color.clear
        }
    }
}
