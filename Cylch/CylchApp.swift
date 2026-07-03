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
        MainActor.assumeIsolated {
            SettingsViewModel.shared.autoConnectOnLaunch()
        }
    }
}

@main
struct CylchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Cylch", systemImage: "circlebadge.fill") {
            MenuBarView()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 420, height: 330)
    }
}
