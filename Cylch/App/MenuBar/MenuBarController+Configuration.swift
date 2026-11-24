import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
extension MenuBarController {
    func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = menuBarIcon(
            brightness: viewModel.brightness,
            isConnected: viewModel.connected && !viewModel.disconnecting
        )
        button.toolTip = "Cylch"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func configurePopover() {
        settingsPopover.behavior = .transient
        settingsPopover.animates = true
        settingsPopover.delegate = self
        settingsPopover.contentSize = NSSize(width: 396, height: 382)
    }

    /// The settings view is built on demand and released on close, so the SwiftUI
    /// hierarchy and its layers don't stay in memory while the app sits in the menu bar.
    func loadSettingsContentIfNeeded() {
        guard settingsPopover.contentViewController == nil else { return }
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(showsInlineHeader: true)
                .frame(width: 396, height: 382)
        )
    }

    func rebuildMenu() {
        menu.removeAllItems()
        menu.autoenablesItems = false

        let aboutItem = actionItem(
            "About Cylch",
            image: assetImage("info"),
            action: #selector(showAbout)
        )
        menu.addItem(aboutItem)

        let settingsItem = actionItem(
            "Settings…",
            image: assetImage("settings"),
            action: #selector(showSettings)
        )
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = .command
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(connectionItem())
        menu.addItem(.separator())
        menu.addItem(levelItem(
            title: "Brightness: \(Int(viewModel.brightness))%",
            imageName: "brightness",
            value: viewModel.brightness,
            isEnabled: viewModel.connected && !viewModel.disconnecting,
            action: #selector(setBrightness)
        ))
        menu.addItem(levelItem(
            title: "Speed: \(Int(viewModel.speed))%",
            imageName: "speed",
            value: viewModel.speed,
            isEnabled: viewModel.connected && !viewModel.disconnecting && viewModel.selectedEffect != .static,
            action: #selector(setSpeed)
        ))
        menu.addItem(.separator())

        let launchAtLoginStatus = SMAppService.mainApp.status
        let launchAtLoginImageName: String

        switch launchAtLoginStatus {
        case .enabled:
            launchAtLoginImageName = "switcher_on"
        case .requiresApproval, .notRegistered, .notFound:
            launchAtLoginImageName = "switcher_off"
        @unknown default:
            launchAtLoginImageName = "switcher_off"
        }

        let launchAtLoginItem = actionItem(
            "Launch at Login",
            image: assetImage(launchAtLoginImageName),
            action: #selector(toggleLaunchAtLogin)
        )
        if launchAtLoginStatus == .requiresApproval {
            launchAtLoginItem.toolTip = "Approval required in System Settings"
        }
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quitItem = actionItem(
            "Quit",
            image: assetImage("exit"),
            action: #selector(quit)
        )
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        showImages(in: menu)
    }

    func connectionItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Connection", action: nil, keyEquivalent: "")
        item.image = assetImage(viewModel.connected && !viewModel.disconnecting ? "connect_on" : "connect_off")
        liveConnectionItem = item

        let submenu = makeMenu(title: "Connection")
        let portItem = portItem()
        livePortItem = portItem
        submenu.addItem(portItem)

        let refreshItem = actionItem("Refresh Ports", action: #selector(refreshPorts))
        refreshItem.isEnabled = !viewModel.connected && !viewModel.connecting && !viewModel.disconnecting
        liveRefreshItem = refreshItem
        submenu.addItem(refreshItem)

        submenu.addItem(.separator())
        let ledCountItem = ledCountItem()
        liveLEDCountItem = ledCountItem
        submenu.addItem(ledCountItem)
        submenu.addItem(.separator())

        let connectItem = actionItem(
            viewModel.connecting
                ? "Connecting…"
                : viewModel.disconnecting
                    ? "Fading Out…"
                    : viewModel.connected ? "Disconnect" : "Connect",
            image: assetImage(viewModel.connected || viewModel.disconnecting ? "connect_off" : "connect_on"),
            action: #selector(toggleConnection)
        )
        connectItem.isEnabled = !viewModel.connecting
            && !viewModel.disconnecting
            && (viewModel.connected || !viewModel.selectedPort.isEmpty)
        liveConnectItem = connectItem
        submenu.addItem(connectItem)

        submenu.addItem(.separator())
        submenu.addItem(actionItem(
            "Turn Off with Display",
            image: assetImage(viewModel.turnOffWithDisplay ? "switcher_on" : "switcher_off"),
            action: #selector(toggleTurnOffWithDisplay)
        ))

        item.submenu = submenu
        return item
    }

    func observeConnectionState() {
        connectionStateObservation = Publishers.CombineLatest3(
            viewModel.$connected,
            viewModel.$connecting,
            viewModel.$disconnecting
        )
        .removeDuplicates { previous, current in
            previous.0 == current.0
                && previous.1 == current.1
                && previous.2 == current.2
        }
        .sink { [weak self] _, _, _ in
            DispatchQueue.main.async { [weak self] in
                self?.refreshLiveConnectionItems()
            }
        }
    }

    func observeBrightness() {
        brightnessObservation = viewModel.$brightness
            .removeDuplicates()
            .sink { [weak self] brightness in
                guard let self else { return }
                self.statusItem.button?.image = self.menuBarIcon(
                    brightness: brightness,
                    isConnected: self.viewModel.connected && !self.viewModel.disconnecting
                )
            }
    }

}
