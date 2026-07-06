//
//  CylchApp.swift
//  Cylch
//
//  Created by Ярослав on 09.05.2026.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Runs for the real app and for Xcode preview agents alike (previews
        // launch this binary), so everything reachable from here must avoid
        // Obj-C message sends — the previews JIT crashes on them.
        MainActor.assumeIsolated {
            SettingsViewModel.shared.autoConnectOnLaunch()
        }
    }
}

@main
struct CylchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Cylch", image: "cylch-16x16") {
            MenuBarView()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 420, height: 330)
    }
}
