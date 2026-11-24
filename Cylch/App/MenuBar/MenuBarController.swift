
import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    let viewModel: SettingsViewModel
    let statusItem: NSStatusItem
    let menu = NSMenu()
    let settingsPopover = NSPopover()
    var settingsOutsideClickMonitor: Any?
    var connectionStateObservation: AnyCancellable?
    var brightnessObservation: AnyCancellable?
    var liveConnectionItem: NSMenuItem?
    var livePortItem: NSMenuItem?
    var liveRefreshItem: NSMenuItem?
    var liveLEDCountItem: NSMenuItem?
    var liveConnectItem: NSMenuItem?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        configureStatusItem()
        configurePopover()
        menu.delegate = self
        rebuildMenu()
        observeConnectionState()
        observeBrightness()

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
        stopMonitoringSettingsOutsideClicks()
        statusItem.button?.highlight(false)
        settingsPopover.contentViewController = nil
    }

    func popoverDidShow(_ notification: Notification) {
        startMonitoringSettingsOutsideClicks()
        makeSettingsPopoverKey()
    }

    deinit {
        if let settingsOutsideClickMonitor {
            NSEvent.removeMonitor(settingsOutsideClickMonitor)
        }
    }
}
