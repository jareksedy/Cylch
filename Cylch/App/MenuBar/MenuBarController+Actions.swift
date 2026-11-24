import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
extension MenuBarController {
    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApplication.shared.currentEvent
        let opensSettings = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if opensSettings {
            showSettings()
        } else {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        }
    }

    @objc func showSettings() {
        guard let button = statusItem.button else { return }

        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            return
        }

        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)

            DispatchQueue.main.async { [weak self, weak button] in
                guard let self, let button else { return }
                button.highlight(true)
                self.loadSettingsContentIfNeeded()
                self.settingsPopover.show(
                    relativeTo: button.bounds,
                    of: button,
                    preferredEdge: .minY
                )
                self.makeSettingsPopoverKey()
            }
        }
    }

    func makeSettingsPopoverKey() {
        guard settingsPopover.isShown,
              let window = settingsPopover.contentViewController?.view.window else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    @objc func applicationDidResignActive(_ notification: Notification) {
        closeSettingsPopoverIfShown()
    }

    func closeSettingsPopoverIfShown() {
        guard settingsPopover.isShown else { return }
        settingsPopover.performClose(nil)
    }

    func startMonitoringSettingsOutsideClicks() {
        guard settingsOutsideClickMonitor == nil else { return }

        settingsOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closeSettingsPopoverIfShown()
            }
        }
    }

    func stopMonitoringSettingsOutsideClicks() {
        guard let settingsOutsideClickMonitor else { return }
        NSEvent.removeMonitor(settingsOutsideClickMonitor)
        self.settingsOutsideClickMonitor = nil
    }

    @objc func refreshPorts() {
        viewModel.refreshPorts()
    }

    @objc func selectPort(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? String else { return }
        viewModel.selectedPort = port
    }

    @objc func decreaseLEDCount() {
        viewModel.ledCount -= 1
    }

    @objc func increaseLEDCount() {
        viewModel.ledCount += 1
    }

    @objc func toggleConnection() {
        if viewModel.connecting || viewModel.disconnecting {
            return
        } else if viewModel.connected {
            viewModel.stopStreaming()
        } else {
            viewModel.connect()
        }
    }

    @objc func setBrightness(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Int else { return }
        viewModel.brightness = Double(level)
    }

    @objc func setSpeed(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Int else { return }
        viewModel.speed = Double(level)
    }

    @objc func toggleTurnOffWithDisplay() {
        viewModel.turnOffWithDisplay.toggle()
    }

    @objc func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp

        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            case .notRegistered, .notFound:
                try service.register()
            @unknown default:
                try service.register()
            }
        } catch {
            NSApplication.shared.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t Update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let credits = NSMutableAttributedString(
            string: "Built for controlling Adalight-compatible LED hardware over USB serial on macOS.\n\nApp Website · GitHub",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        let websiteRange = (credits.string as NSString).range(of: "App Website")
        credits.addAttributes(
            [
                .link: URL(string: "https://cylch.asia/")!,
                .foregroundColor: NSColor.linkColor
            ],
            range: websiteRange
        )
        let githubRange = (credits.string as NSString).range(of: "GitHub")
        credits.addAttributes(
            [
                .link: URL(string: "https://github.com/jareksedy/Cylch")!,
                .foregroundColor: NSColor.linkColor
            ],
            range: githubRange
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Cylch",
            .applicationIcon: NSApplication.shared.applicationIconImage as Any,
            .credits: credits
        ])
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}
