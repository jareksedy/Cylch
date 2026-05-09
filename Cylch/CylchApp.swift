//
//  CylchApp.swift
//  Cylch
//
//  Created by Ярослав on 09.05.2026.
//

import SwiftUI

@main
struct CylchApp: App {
    var body: some Scene {
        MenuBarExtra("Cylch", systemImage: "circlebadge.fill") {
            MenuBarView()
        }

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 540, height: 320)
    }
}
