//
//  ContentView.swift
//  Cylch
//
//  Created by Ярослав on 09.05.2026.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings...") {
            openWindow(id: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Hello, World!")
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
