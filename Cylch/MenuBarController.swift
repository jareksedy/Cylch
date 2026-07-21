//
//  MenuBarController.swift
//  Cylch
//

import AppKit
import Combine
import ServiceManagement
import SwiftUI

/// AppKit owns the status item so Settings can be presented by a real
/// NSPopover anchored precisely to the app's menu-bar button. The menu stays
/// native rather than becoming a custom SwiftUI panel.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private let viewModel: SettingsViewModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let settingsPopover = NSPopover()
    private var connectionStateObservation: AnyCancellable?
    private var liveConnectionItem: NSMenuItem?
    private var livePortItem: NSMenuItem?
    private var liveRefreshItem: NSMenuItem?
    private var liveLEDCountItem: NSMenuItem?
    private var liveConnectItem: NSMenuItem?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configurePopover()
        menu.delegate = self
        rebuildMenu()
        observeConnectionState()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidResignActive(_:)),
            name: NSApplication.didResignActiveNotification,
            object: NSApplication.shared
        )
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        closeSettingsPopoverIfShown()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    func popoverDidShow(_ notification: Notification) {
        makeSettingsPopoverKey()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = assetImage("cylch-16x16", size: 16)
        button.image?.isTemplate = true
        button.toolTip = "Cylch"
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        settingsPopover.behavior = .transient
        settingsPopover.animates = true
        settingsPopover.delegate = self
        settingsPopover.contentSize = NSSize(width: 396, height: 382)
        settingsPopover.contentViewController = NSHostingController(
            rootView: SettingsView(showsInlineHeader: true)
                .frame(width: 396, height: 382)
        )
    }

    private func rebuildMenu() {
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
        menu.addItem(scheduleItem())
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
            launchAtLoginImageName = "laptop_check"
        case .requiresApproval, .notRegistered, .notFound:
            launchAtLoginImageName = "laptop_x"
        @unknown default:
            launchAtLoginImageName = "laptop_x"
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

        let quitItem = actionItem(
            "Quit",
            image: assetImage("exit"),
            action: #selector(quit)
        )
        quitItem.keyEquivalent = "q"
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)
    }

    private func connectionItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Connection", action: nil, keyEquivalent: "")
        item.image = assetImage(viewModel.connected && !viewModel.disconnecting ? "link_horizontal" : "link_horizontal_off")
        liveConnectionItem = item

        let submenu = makeMenu(title: "Connection")
        let portItem = portItem()
        livePortItem = portItem
        submenu.addItem(portItem)

        let refreshItem = actionItem("Refresh Ports", action: #selector(refreshPorts))
        refreshItem.isEnabled = !viewModel.connected && !viewModel.disconnecting
        liveRefreshItem = refreshItem
        submenu.addItem(refreshItem)

        submenu.addItem(.separator())
        let ledCountItem = ledCountItem()
        liveLEDCountItem = ledCountItem
        submenu.addItem(ledCountItem)
        submenu.addItem(.separator())

        let connectItem = actionItem(
            viewModel.disconnecting ? "Fading Out…" : viewModel.connected ? "Disconnect" : "Connect",
            image: assetImage(viewModel.connected || viewModel.disconnecting ? "link_horizontal_off" : "link_horizontal"),
            action: #selector(toggleConnection)
        )
        connectItem.isEnabled = !viewModel.disconnecting && (viewModel.connected || !viewModel.selectedPort.isEmpty)
        liveConnectItem = connectItem
        submenu.addItem(connectItem)

        item.submenu = submenu
        return item
    }

    private func observeConnectionState() {
        connectionStateObservation = Publishers.CombineLatest(
            viewModel.$connected,
            viewModel.$disconnecting
        )
        .removeDuplicates { previous, current in
            previous.0 == current.0 && previous.1 == current.1
        }
        .sink { [weak self] _, _ in
            // @Published emits before the stored property finishes changing.
            // Coalesce connected + disconnecting into the next main-loop turn
            // so the menu reads one final, internally consistent state.
            DispatchQueue.main.async { [weak self] in
                self?.refreshLiveConnectionItems()
            }
        }
    }

    private func refreshLiveConnectionItems() {
        let connected = viewModel.connected
        let disconnecting = viewModel.disconnecting

        liveConnectionItem?.image = assetImage(
            connected && !disconnecting ? "link_horizontal" : "link_horizontal_off"
        )
        liveRefreshItem?.isEnabled = !connected && !disconnecting

        if let livePortItem {
            updateMenuItem(livePortItem, from: portItem())
        }
        if let liveLEDCountItem {
            updateMenuItem(liveLEDCountItem, from: ledCountItem())
        }

        liveConnectItem?.title = disconnecting ? "Fading Out…" : connected ? "Disconnect" : "Connect"
        liveConnectItem?.image = assetImage(
            connected || disconnecting ? "link_horizontal_off" : "link_horizontal"
        )
        liveConnectItem?.isEnabled = !disconnecting && (connected || !viewModel.selectedPort.isEmpty)
    }

    private func updateMenuItem(_ item: NSMenuItem, from replacement: NSMenuItem) {
        item.title = replacement.title
        item.isEnabled = replacement.isEnabled
        item.submenu = replacement.submenu
    }

    private func portItem() -> NSMenuItem {
        if viewModel.connected {
            return disabledItem("Port: \(shortPortName(viewModel.selectedPort))")
        }

        guard !viewModel.availablePorts.isEmpty else {
            return disabledItem("No USB Serial Ports")
        }

        let item = NSMenuItem(
            title: "Port: \(shortPortName(viewModel.selectedPort))",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = makeMenu(title: "Port")

        for port in viewModel.availablePorts {
            let portItem = actionItem(shortPortName(port), action: #selector(selectPort))
            portItem.representedObject = port
            portItem.state = viewModel.selectedPort == port ? .on : .off
            submenu.addItem(portItem)
        }

        item.submenu = submenu
        return item
    }

    private func ledCountItem() -> NSMenuItem {
        let title = "LED count: \(viewModel.ledCount)"
        guard !viewModel.connected else { return disabledItem(title) }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = makeMenu(title: "LED count")

        let decreaseItem = actionItem(
            "Decrease",
            image: symbolImage("minus.circle.fill"),
            action: #selector(decreaseLEDCount)
        )
        decreaseItem.isEnabled = viewModel.ledCount > 1
        submenu.addItem(decreaseItem)

        let increaseItem = actionItem(
            "Increase",
            image: symbolImage("plus.circle.fill"),
            action: #selector(increaseLEDCount)
        )
        increaseItem.isEnabled = viewModel.ledCount < 300
        submenu.addItem(increaseItem)

        item.submenu = submenu
        return item
    }

    private func scheduleItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Night Schedule", action: nil, keyEquivalent: "")
        item.image = assetImage("moon_small")

        let submenu = makeMenu(title: "Night Schedule")
        let enabledItem = actionItem("Enabled", action: #selector(toggleSchedule))
        enabledItem.state = viewModel.scheduleEnabled ? .on : .off
        submenu.addItem(enabledItem)
        submenu.addItem(.separator())
        submenu.addItem(scheduleTimeItem(
            title: "From: \(timeString(viewModel.scheduleStartTime))",
            earlierAction: #selector(moveScheduleStartEarlier),
            laterAction: #selector(moveScheduleStartLater)
        ))
        submenu.addItem(scheduleTimeItem(
            title: "Until: \(timeString(viewModel.scheduleEndTime))",
            earlierAction: #selector(moveScheduleEndEarlier),
            laterAction: #selector(moveScheduleEndLater)
        ))

        item.submenu = submenu
        return item
    }

    private func scheduleTimeItem(
        title: String,
        earlierAction: Selector,
        laterAction: Selector
    ) -> NSMenuItem {
        guard viewModel.scheduleEnabled else { return disabledItem(title) }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = makeMenu(title: title)
        submenu.addItem(actionItem(
            "30 Minutes Earlier",
            image: symbolImage("minus.circle.fill"),
            action: earlierAction
        ))
        submenu.addItem(actionItem(
            "30 Minutes Later",
            image: symbolImage("plus.circle.fill"),
            action: laterAction
        ))
        item.submenu = submenu
        return item
    }

    private func levelItem(
        title: String,
        imageName: String,
        value: Double,
        isEnabled: Bool,
        action: Selector
    ) -> NSMenuItem {
        guard isEnabled else {
            let item = disabledItem(title)
            item.image = assetImage(imageName)
            return item
        }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.image = assetImage(imageName)
        let submenu = makeMenu(title: title)

        for level in stride(from: 0, through: 100, by: 25) {
            let levelItem = actionItem("\(level)%", action: action)
            levelItem.representedObject = level
            levelItem.state = value == Double(level) ? .on : .off
            submenu.addItem(levelItem)
        }

        item.submenu = submenu
        return item
    }

    private func makeMenu(title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        return menu
    }

    private func actionItem(
        _ title: String,
        image: NSImage? = nil,
        action: Selector
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.image = image
        item.isEnabled = true
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func assetImage(_ name: String, size: CGFloat = 16) -> NSImage? {
        guard let source = NSImage(named: name),
              let image = source.copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        return image
    }

    private func symbolImage(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    private func shortPortName(_ port: String) -> String {
        port.split(separator: "/").last.map(String.init) ?? port
    }

    private func timeString(_ time: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func adjust(_ time: Date, byMinutes minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: time) ?? time
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApplication.shared.currentEvent
        let opensSettings = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if opensSettings {
            showSettings()
        } else {
            // Temporarily assigning the native menu lets NSStatusItem retain
            // its standard placement, tracking and highlight behavior. Once
            // tracking ends, right clicks return to the direct popover action.
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        }
    }

    @objc private func showSettings() {
        guard let button = statusItem.button else { return }

        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            return
        }

        // Let NSMenu finish dismissing, then give app activation one more run
        // loop turn before creating the popover. Showing it in the same turn
        // as activate() can leave its system material in the lighter inactive
        // state until the user clicks the window.
        DispatchQueue.main.async { [weak self, weak button] in
            guard let self, let button else { return }
            NSApplication.shared.activate(ignoringOtherApps: true)

            DispatchQueue.main.async { [weak self, weak button] in
                guard let self, let button else { return }
                button.highlight(true)
                self.settingsPopover.show(
                    relativeTo: button.bounds,
                    of: button,
                    preferredEdge: .minY
                )
                self.makeSettingsPopoverKey()
            }
        }
    }

    private func makeSettingsPopoverKey() {
        guard settingsPopover.isShown,
              let window = settingsPopover.contentViewController?.view.window else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    @objc private func applicationDidResignActive(_ notification: Notification) {
        closeSettingsPopoverIfShown()
    }

    private func closeSettingsPopoverIfShown() {
        guard settingsPopover.isShown else { return }
        settingsPopover.performClose(nil)
    }

    @objc private func refreshPorts() {
        viewModel.refreshPorts()
    }

    @objc private func selectPort(_ sender: NSMenuItem) {
        guard let port = sender.representedObject as? String else { return }
        viewModel.selectedPort = port
    }

    @objc private func decreaseLEDCount() {
        viewModel.ledCount -= 1
    }

    @objc private func increaseLEDCount() {
        viewModel.ledCount += 1
    }

    @objc private func toggleConnection() {
        if viewModel.disconnecting {
            return
        } else if viewModel.connected {
            viewModel.stopStreaming()
        } else {
            viewModel.connect()
        }
    }

    @objc private func toggleSchedule() {
        viewModel.scheduleEnabled.toggle()
    }

    @objc private func moveScheduleStartEarlier() {
        viewModel.scheduleStartTime = adjust(viewModel.scheduleStartTime, byMinutes: -30)
    }

    @objc private func moveScheduleStartLater() {
        viewModel.scheduleStartTime = adjust(viewModel.scheduleStartTime, byMinutes: 30)
    }

    @objc private func moveScheduleEndEarlier() {
        viewModel.scheduleEndTime = adjust(viewModel.scheduleEndTime, byMinutes: -30)
    }

    @objc private func moveScheduleEndLater() {
        viewModel.scheduleEndTime = adjust(viewModel.scheduleEndTime, byMinutes: 30)
    }

    @objc private func setBrightness(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Int else { return }
        viewModel.brightness = Double(level)
    }

    @objc private func setSpeed(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Int else { return }
        viewModel.speed = Double(level)
    }

    @objc private func toggleLaunchAtLogin() {
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

    @objc private func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let credits = NSAttributedString(
            string: "A lightweight menu bar app for controlling addressable LED lighting.",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "Cylch",
            .applicationIcon: NSApplication.shared.applicationIconImage as Any,
            .credits: credits
        ])
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
