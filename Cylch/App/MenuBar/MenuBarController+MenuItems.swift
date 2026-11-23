import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
extension MenuBarController {
    func refreshLiveConnectionItems() {
        let connected = viewModel.connected
        let connecting = viewModel.connecting
        let disconnecting = viewModel.disconnecting

        statusItem.button?.image = menuBarIcon(
            brightness: viewModel.brightness,
            isConnected: connected && !disconnecting
        )

        liveConnectionItem?.image = assetImage(
            connected && !disconnecting ? "connect_on" : "connect_off"
        )
        liveRefreshItem?.isEnabled = !connected && !connecting && !disconnecting

        if let livePortItem {
            updateMenuItem(livePortItem, from: portItem())
        }
        if let liveLEDCountItem {
            updateMenuItem(liveLEDCountItem, from: ledCountItem())
        }

        liveConnectItem?.title = connecting
            ? "Connecting…"
            : disconnecting ? "Fading Out…" : connected ? "Disconnect" : "Connect"
        liveConnectItem?.image = assetImage(
            connected || disconnecting ? "connect_off" : "connect_on"
        )
        liveConnectItem?.isEnabled = !connecting
            && !disconnecting
            && (connected || !viewModel.selectedPort.isEmpty)
    }

    func updateMenuItem(_ item: NSMenuItem, from replacement: NSMenuItem) {
        item.title = replacement.title
        item.isEnabled = replacement.isEnabled
        item.submenu = replacement.submenu
        if let submenu = item.submenu {
            showImages(in: submenu)
        }
    }

    /// macOS 27 hides menu item images by default, but these menus rely on them.
    func showImages(in menu: NSMenu) {
        guard #available(macOS 27.0, *) else { return }

        for item in menu.items {
            item.preferredImageVisibility = .visible
            if let submenu = item.submenu {
                showImages(in: submenu)
            }
        }
    }

    func portItem() -> NSMenuItem {
        if viewModel.connected || viewModel.connecting {
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

    func ledCountItem() -> NSMenuItem {
        let title = "LED count: \(viewModel.ledCount)"
        guard !viewModel.connected, !viewModel.connecting else { return disabledItem(title) }

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

    func levelItem(
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

    func makeMenu(title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        return menu
    }

    func actionItem(
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

    func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func assetImage(_ name: String, size: CGFloat = 16) -> NSImage? {
        guard let source = NSImage(named: name),
              let image = source.copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        return image
    }

    func symbolImage(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        return image
    }

    func shortPortName(_ port: String) -> String {
        port.split(separator: "/").last.map(String.init) ?? port
    }

}
