//
//  ContentView.swift
//  Cylch
//
//  Created by Ярослав on 09.05.2026.
//

import SwiftUI
import Foundation
import Darwin
import Combine
import os

// NOTE: Xcode previews launch this real app binary and JIT-compile edited
// source files. That JIT corrupts selectors on any Obj-C message send made
// from this app's own sources (NSLock, NSThread, ProcessInfo all abort with
// "unrecognized selector"), so code reachable from previews must stick to
// pure Swift and C APIs (OSAllocatedUnfairLock, DispatchQueue, getenv,
// opendir, ...). Framework-internal Obj-C is unaffected.

enum LEDEffect: String, CaseIterable, Identifiable {
    case `static` = "Static"
    case rainbow = "Rainbow"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .static:
            "static"
        case .rainbow:
            "rainbow"
        }
    }
}

struct LEDColor: Identifiable, Equatable, Sendable {
    let name: String
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var id: String { name }
    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    /// Black on bright colors (white, yellow, green, cyan), white on the
    /// rest. The 0.55 threshold is picked so pure green (luminance 0.587)
    /// gets a dark checkmark — a white one is barely readable on it.
    var contrastingColor: Color {
        let luminance = (0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)) / 255
        return luminance > 0.55 ? .black : .white
    }

    static let palette: [LEDColor] = [
        LEDColor(name: "Red", red: 255, green: 0, blue: 0),
        LEDColor(name: "Orange", red: 255, green: 75, blue: 0),
        LEDColor(name: "Yellow", red: 255, green: 180, blue: 0),
        LEDColor(name: "Green", red: 0, green: 255, blue: 0),
        LEDColor(name: "Cyan", red: 0, green: 255, blue: 255),
        LEDColor(name: "Blue", red: 0, green: 0, blue: 255),
        LEDColor(name: "Purple", red: 255, green: 0, blue: 255),
        LEDColor(name: "White", red: 255, green: 255, blue: 255)
    ]
}

struct SettingsView: View {
    var showsInlineHeader = false

    @StateObject private var viewModel = SettingsViewModel.shared
    @Namespace private var pickerNamespace
    @State private var showConnectionPopover = false
    @State private var showSchedulePopover = false

    @ViewBuilder
    var body: some View {
        if showsInlineHeader {
            VStack(spacing: 0) {
                inlineHeader
                settingsContent
            }
            .onAppear {
                viewModel.onAppear()
            }
        } else {
            settingsContent
                .onAppear {
                    viewModel.onAppear()
                }
                .toolbar {
                    ToolbarItem {
                        scheduleToolbarButton
                    }

                    ToolbarItem {
                        connectionToolbarButton
                    }
                }
        }
    }

    private var settingsContent: some View {
        VStack(spacing: 28) {
            effectPicker
                .frame(width: 320, height: 36)

            transportRow

            colorPalette
                .frame(width: 320, height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, showsInlineHeader ? 36 : 32)
        .font(.system(size: 13, design: .monospaced))
    }

    private var inlineHeader: some View {
        HStack(spacing: 12) {
            Text("Settings")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            HStack(spacing: 0) {
                scheduleToolbarButton
                connectionToolbarButton
            }
            .padding(4)
            .background {
                Capsule()
                    .fill(Color.primary.opacity(0.04))
                    .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var scheduleToolbarButton: some View {
        Button {
            showSchedulePopover.toggle()
        } label: {
            Image("moon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Night Schedule")
        .popover(isPresented: $showSchedulePopover, arrowEdge: .bottom) {
            SchedulePopoverView()
        }
    }

    private var connectionToolbarButton: some View {
        Button {
            showConnectionPopover.toggle()
        } label: {
            Image("link_horizontal")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Connection")
        .popover(isPresented: $showConnectionPopover, arrowEdge: .bottom) {
            ConnectionPopoverView()
        }
    }

    private var effectPicker: some View {
        HStack(spacing: 0) {
            ForEach(LEDEffect.allCases) { effect in
                let isSelected = viewModel.selectedEffect == effect

                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.selectedEffect = effect
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(effect.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)

                        Text(effect.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    }
                    .offset(x: -3)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "selectedEffect", in: pickerNamespace)
                    }
                }
            }
        }
        .background(Capsule().fill(Color.primary.opacity(0.04)))
    }

    private var transportRow: some View {
        HStack(spacing: 44) {
            CircularKnob(
                value: $viewModel.brightness,
                gaugeStyle: viewModel.selectedEffect == .static ? .solid(viewModel.staticColor.color) : .rainbow,
                icon: Image("brightness"),
                usesPopoverSurface: showsInlineHeader
            )
                .frame(width: 140, height: 140)
                .help("Brightness")

            CircularKnob(
                value: $viewModel.speed,
                gaugeStyle: .gradient([
                    .init(color: .accentColor, location: 0),
                    .init(color: Color.accentColor.mix(with: .white, by: 0.45), location: 0.5),
                    .init(color: .accentColor, location: 1)
                ]),
                icon: Image("speed"),
                usesPopoverSurface: showsInlineHeader
            )
                .frame(width: 140, height: 140)
                .disabled(viewModel.selectedEffect == .static)
                .help("Speed")
        }
        .disabled(!viewModel.connected || viewModel.disconnecting)
    }

    private var colorPalette: some View {
        let isInactive = viewModel.selectedEffect == .rainbow || !viewModel.connected || viewModel.disconnecting

        return HStack(spacing: 0) {
            ForEach(LEDColor.palette) { ledColor in
                let isSelected = viewModel.staticColor == ledColor

                Button {
                    withAnimation(.smooth(duration: 0.25)) {
                        viewModel.staticColor = ledColor
                    }
                } label: {
                    Circle()
                        .fill(ledColor.color)
                        .frame(width: isSelected ? 22 : 18, height: isSelected ? 22 : 18)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? ledColor.color : Color.primary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                        )
                        .overlay {
                            if isSelected {
                                Circle()
                                    .stroke(ledColor.color.opacity(0.28), lineWidth: 5)
                                    .padding(-3)
                            }
                        }
                        .overlay {
                            if isSelected {
                                Image("check")
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                    .foregroundStyle(ledColor.contrastingColor)
                                    .transition(
                                        .scale.combined(with: .opacity)
                                            .animation(.spring(response: 0.35, dampingFraction: 0.55))
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedEffect == .rainbow)
                .help(ledColor.name)
            }
        }
        // Slightly widen the row beyond the capsule so the first and last
        // swatches sit as close to the rounded ends as they do to the top
        // and bottom edges.
        .padding(.horizontal, -2)
        .background(Capsule().fill(Color.primary.opacity(0.04)))
        .disabled(!viewModel.connected || viewModel.disconnecting)
        .opacity(isInactive ? 0.45 : 1)
        .saturation(isInactive ? 0.25 : 1)
    }

}

/// Popover chrome mirrors the main settings window: compact system type, a
/// small accent icon, and enough empty space to keep the controls calm.
private struct SettingsPopoverPanel<Content: View>: View {
    let title: String
    let imageName: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.leading, 2)

            content()
        }
        .padding(16)
        .frame(width: 344, alignment: .leading)
        .font(.system(size: 13))
    }
}

private struct PopoverRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 36)
    }
}

/// The same quiet capsule tint used by the effect picker and color palette.
private extension View {
    func controlCapsule() -> some View {
        background(Capsule().fill(Color.primary.opacity(0.04)))
    }
}

/// Small round icon button used inside capsule controls (refresh, ±),
/// backed by template icons from the asset catalog.
private struct GlyphButton: View {
    let systemName: String
    var symbolSize: CGFloat = 24
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: symbolSize, height: symbolSize)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }
}

/// Custom capsule stepper: minus / expanded value / plus.
private struct CapsuleStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 0) {
            GlyphButton(systemName: "minus.circle.fill", isEnabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text("\(value)")
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
                .frame(minWidth: 52)

            GlyphButton(systemName: "plus.circle.fill", isEnabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .frame(minWidth: 120)
        .controlCapsule()
    }
}

/// Custom time control: minus / HH:mm / plus, stepping by half an hour.
private struct TimeStepper: View {
    @Binding var time: Date
    var isEnabled: Bool = true

    var body: some View {
        ZStack {
            Text(timeString)
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .frame(minWidth: 60)

            HStack(spacing: 0) {
                GlyphButton(systemName: "minus.circle.fill", isEnabled: isEnabled) {
                    adjust(byMinutes: -30)
                }

                Spacer(minLength: 60)

                GlyphButton(systemName: "plus.circle.fill", isEnabled: isEnabled) {
                    adjust(byMinutes: 30)
                }
            }
        }
        .frame(minWidth: 132, maxWidth: .infinity)
        .controlCapsule()
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var timeString: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        return String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private func adjust(byMinutes minutes: Int) {
        time = Calendar.current.date(byAdding: .minute, value: minutes, to: time) ?? time
    }
}

/// Full-width capsule action button: accent-filled when prominent, quietly
/// tinted otherwise.
private struct ActionCapsuleButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.primary.opacity(0.8)))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(Capsule())
            .background {
                if prominent {
                    Capsule().fill(Color.accentColor)
                } else {
                    Capsule().fill(Color.primary.opacity(0.06))
                }
            }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct ConnectionPopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(title: "Connection", imageName: "link_horizontal") {
            VStack(spacing: 12) {
                PopoverRow(label: "Port") {
                    HStack(spacing: 8) {
                        portMenu

                        GlyphButton(
                            systemName: "arrow.trianglehead.2.clockwise.rotate.90",
                            symbolSize: 18,
                            isEnabled: !viewModel.connected
                        ) {
                            viewModel.refreshPorts()
                        }
                        .controlCapsule()
                        .help("Refresh Ports")
                    }
                }

                PopoverRow(label: "LED count") {
                    CapsuleStepper(value: $viewModel.ledCount, range: 1...300)
                        .disabled(viewModel.connected)
                        .opacity(viewModel.connected ? 0.45 : 1)
                }

                Button {
                    if viewModel.disconnecting {
                        return
                    } else if viewModel.connected {
                        viewModel.stopStreaming()
                    } else {
                        viewModel.connect()
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(viewModel.connected || viewModel.disconnecting ? "link_horizontal_off" : "link_horizontal")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 13, height: 13)

                        Text(viewModel.disconnecting ? "Fading Out…" : viewModel.connected ? "Disconnect" : "Connect")
                    }
                }
                .buttonStyle(ActionCapsuleButtonStyle(prominent: !viewModel.connected))
                .disabled(viewModel.disconnecting || (!viewModel.connected && viewModel.selectedPort.isEmpty))
                .opacity(viewModel.disconnecting || (!viewModel.connected && viewModel.selectedPort.isEmpty) ? 0.45 : 1)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
            }
        }
        .onAppear {
            viewModel.refreshPorts()
        }
    }

    /// Custom capsule menu instead of the native pop-up button: shows the
    /// short port name, opens a checkmarked menu of discovered ports.
    private var portMenu: some View {
        Menu {
            if viewModel.availablePorts.isEmpty {
                Button("No USB Serial Ports") {}
                    .disabled(true)
            }

            ForEach(viewModel.availablePorts, id: \.self) { port in
                Toggle(isOn: Binding(
                    get: { viewModel.selectedPort == port },
                    set: { _ in viewModel.selectedPort = port }
                )) {
                    Text(Self.shortPortName(port))
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(viewModel.selectedPort.isEmpty ? "No USB Port" : Self.shortPortName(viewModel.selectedPort))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 4)

                Image("unfold_more")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .controlCapsule()
        .disabled(viewModel.connected)
        .opacity(viewModel.connected ? 0.5 : 1)
    }

    private static func shortPortName(_ port: String) -> String {
        port.split(separator: "/").last.map(String.init) ?? port
    }
}

struct SchedulePopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(title: "Night Schedule", imageName: "moon") {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Text("Enabled")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: $viewModel.scheduleEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.accentColor)
                        .fixedSize()
                }
                .padding(.leading, 12)
                // A standard macOS switch is about 24 points high inside the
                // 36-point capsule: six points above and below. Match that on
                // its exposed trailing edge as well.
                .padding(.trailing, 6)
                .frame(height: 36)
                .controlCapsule()

                HStack(alignment: .top, spacing: 16) {
                    scheduleTimeField(
                        caption: "From",
                        imageName: "moon",
                        time: $viewModel.scheduleStartTime
                    )

                    scheduleTimeField(
                        caption: "Until",
                        imageName: "sun",
                        time: $viewModel.scheduleEndTime
                    )
                }
            }
        }
    }

    private func scheduleTimeField(
        caption: String,
        imageName: String,
        time: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(Color.accentColor)

                Text(caption)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            TimeStepper(time: time, isEnabled: viewModel.scheduleEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SettingsView()
        .frame(width: 420, height: 330)
}

#Preview("Connection Popover") {
    ConnectionPopoverView()
}

#Preview("Schedule Popover") {
    SchedulePopoverView()
}

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()

    @Published var brightness: Double = 75 {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var speed: Double = 25 {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var ledCount: Int = 65 {
        didSet {
            let clamped = min(300, max(1, ledCount))
            guard ledCount == clamped else {
                ledCount = clamped
                return
            }
            persistSettings()
            pushConfig()
        }
    }
    @Published var selectedEffect: LEDEffect = .rainbow {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var staticColor: LEDColor = LEDColor.palette[0] {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var paused: Bool = false {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var selectedPort: String = "" {
        didSet { persistSettings() }
    }
    @Published var connected: Bool = false
    @Published private(set) var disconnecting: Bool = false
    @Published var availablePorts: [String] = []
    @Published var errorMessage: String?
    @Published var scheduleEnabled: Bool = false {
        didSet {
            persistSettings()
            updateScheduleState()
        }
    }
    @Published var scheduleStartTime: Date = SettingsViewModel.timeToday(hour: 23, minute: 0) {
        didSet {
            persistSettings()
            updateScheduleState()
        }
    }
    @Published var scheduleEndTime: Date = SettingsViewModel.timeToday(hour: 7, minute: 0) {
        didSet {
            persistSettings()
            updateScheduleState()
        }
    }
    @Published private(set) var scheduleActive: Bool = false

    var scheduleSummary: String {
        guard scheduleEnabled else { return "Schedule is off" }
        return scheduleActive ? "LEDs are off until schedule ends" : "LEDs stay on until scheduled off time"
    }

    private let settingsStore: UserDefaultsSettingsStore
    private var connectionPreference: Bool
    private let controller = AdalightController()
    private var scheduleTask: Task<Void, Never>?
    private var preserveReconnectPreferenceDuringFade = false
    private var disconnectionCompletions: [() -> Void] = []

    private static let lightTransitionDuration: TimeInterval = 0.5

    convenience init() {
        self.init(settingsStore: .shared)
    }

    init(settingsStore: UserDefaultsSettingsStore) {
        let persisted = settingsStore.load()
        self.settingsStore = settingsStore
        connectionPreference = persisted.shouldReconnect

        brightness = min(100, max(0, persisted.brightness))
        speed = min(100, max(0, persisted.speed))
        ledCount = min(300, max(1, persisted.ledCount))
        selectedEffect = LEDEffect(rawValue: persisted.selectedEffect) ?? .rainbow
        staticColor = LEDColor.palette.first {
            $0.name == persisted.staticColorName
        } ?? LEDColor.palette[0]
        paused = persisted.paused
        selectedPort = persisted.selectedPort
        scheduleEnabled = persisted.scheduleEnabled
        scheduleStartTime = Self.timeToday(
            minuteOfDay: min(1_439, max(0, persisted.scheduleStartMinute))
        )
        scheduleEndTime = Self.timeToday(
            minuteOfDay: min(1_439, max(0, persisted.scheduleEndMinute))
        )

        controller.onConnectedChanged = { [weak self] isConnected in
            Task { @MainActor in
                self?.connectionStateDidChange(isConnected)
            }
        }

        controller.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = message
            }
        }

        // Writes defaults on first launch and normalizes any stale or invalid
        // values from an older build immediately after loading them.
        persistSettings()
    }

    func onAppear() {
        refreshPorts()
        startScheduleMonitor()
        pushConfig()
    }

    func refreshPorts() {
        let ports = Self.discoverSerialPorts()
        availablePorts = ports

        if selectedPort.isEmpty || !ports.contains(selectedPort) {
            selectedPort = Self.preferredPort(in: ports) ?? ports.first ?? ""
        }
    }

    /// Called once at launch. A first install keeps the app's historical
    /// auto-connect behavior; after that, the last explicit connected or
    /// disconnected state decides whether streaming should be restored.
    func autoConnectOnLaunch() {
        let portToRestore = selectedPort
        refreshPorts()
        startScheduleMonitor()
        pushConfig()

        guard connectionPreference,
              !connected else {
            return
        }

        if !portToRestore.isEmpty {
            guard availablePorts.contains(portToRestore) else {
                // Never silently reconnect to a different adapter merely
                // because the previously connected one is unavailable.
                connectionPreference = false
                persistSettings()
                return
            }
            selectedPort = portToRestore
        }

        guard !selectedPort.isEmpty else { return }

        connect()
    }

    func playPause() {
        if connected {
            paused.toggle()
            return
        }

        connect()
    }

    func connect() {
        guard !disconnecting else { return }

        guard !selectedPort.isEmpty else {
            errorMessage = "No serial port selected."
            return
        }

        errorMessage = nil
        connectionPreference = true
        persistSettings()
        controller.start(
            port: selectedPort,
            initialConfig: currentConfig,
            fadeInDuration: Self.lightTransitionDuration
        )
    }

    func stopStreaming() {
        guard connected else { return }

        connectionPreference = false
        persistSettings()
        beginFadeOut(preservingReconnectPreference: false)
    }

    /// Starts the same graceful shutdown used by Disconnect, but retains the
    /// connected preference so a strip that was active before Quit can be
    /// restored on the next launch.
    @discardableResult
    func fadeOutForTermination(completion: @escaping () -> Void) -> Bool {
        guard connected || disconnecting else { return false }

        disconnectionCompletions.append(completion)
        if !disconnecting {
            beginFadeOut(preservingReconnectPreference: true)
        }
        return true
    }

    private func beginFadeOut(preservingReconnectPreference: Bool) {
        guard connected, !disconnecting else { return }

        preserveReconnectPreferenceDuringFade = preservingReconnectPreference
        disconnecting = true
        controller.fadeOutAndStop(duration: Self.lightTransitionDuration)
    }

    private func connectionStateDidChange(_ isConnected: Bool) {
        connected = isConnected

        if isConnected {
            connectionPreference = true
        } else if !preserveReconnectPreferenceDuringFade {
            connectionPreference = false
        }

        guard !isConnected else {
            persistSettings()
            return
        }

        disconnecting = false
        preserveReconnectPreferenceDuringFade = false
        if paused {
            paused = false
        }
        persistSettings()

        let completions = disconnectionCompletions
        disconnectionCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func persistSettings() {
        let calendar = Calendar.current
        settingsStore.save(PersistedSettings(
            selectedPort: selectedPort,
            ledCount: ledCount,
            shouldReconnect: connectionPreference,
            selectedEffect: selectedEffect.rawValue,
            staticColorName: staticColor.name,
            brightness: brightness,
            speed: speed,
            paused: paused,
            scheduleEnabled: scheduleEnabled,
            scheduleStartMinute: Self.minuteOfDay(from: scheduleStartTime, calendar: calendar),
            scheduleEndMinute: Self.minuteOfDay(from: scheduleEndTime, calendar: calendar)
        ))
    }

    private func pushConfig() {
        controller.updateConfig(
            currentConfig,
            visualTransitionDuration: Self.lightTransitionDuration
        )
    }

    private var currentConfig: StreamConfig {
        StreamConfig(effect: selectedEffect, staticColor: staticColor, brightness: brightness, speed: speed, ledCount: ledCount, paused: paused, lightsOff: scheduleActive)
    }

    private func startScheduleMonitor() {
        guard scheduleTask == nil else { return }
        updateScheduleState()

        scheduleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                self?.updateScheduleState()
            }
        }
    }

    private func updateScheduleState(now: Date = Date()) {
        let isActive = scheduleEnabled && Self.isTime(now, inQuietHoursFrom: scheduleStartTime, until: scheduleEndTime)
        guard scheduleActive != isActive else { return }
        scheduleActive = isActive
        pushConfig()
    }

    private static func isTime(_ date: Date, inQuietHoursFrom startDate: Date, until endDate: Date) -> Bool {
        let calendar = Calendar.current
        let currentMinute = minuteOfDay(from: date, calendar: calendar)
        let startMinute = minuteOfDay(from: startDate, calendar: calendar)
        let endMinute = minuteOfDay(from: endDate, calendar: calendar)

        guard startMinute != endMinute else { return false }
        if startMinute < endMinute {
            return currentMinute >= startMinute && currentMinute < endMinute
        }

        return currentMinute >= startMinute || currentMinute < endMinute
    }

    private static func minuteOfDay(from date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func timeToday(hour: Int, minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    private static func timeToday(minuteOfDay: Int) -> Date {
        timeToday(hour: minuteOfDay / 60, minute: minuteOfDay % 60)
    }

    /// Prefers a USB serial adapter (e.g. `/dev/cu.usbserial-XXXX`) when present.
    private static func preferredPort(in ports: [String]) -> String? {
        ports.first { $0.lowercased().contains("usbserial") } ?? ports.first
    }

    private static func discoverSerialPorts() -> [String] {
        guard let directory = opendir("/dev") else {
            return []
        }
        defer { closedir(directory) }

        var ports: [String] = []
        while let entry = readdir(directory) {
            let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN)) {
                    String(cString: $0)
                }
            }

            if isSupportedUSBSerialDeviceName(name) {
                ports.append("/dev/\(name)")
            }
        }

        return ports.sorted()
    }

    /// `/dev/cu.*` also contains virtual Bluetooth and system console
    /// endpoints. Keep the established names used by USB CDC devices and the
    /// common FTDI, WCH/CH34x, Silicon Labs/CP210x adapter drivers so an
    /// obviously incompatible endpoint can never be selected by mistake.
    private static func isSupportedUSBSerialDeviceName(_ name: String) -> Bool {
        let normalizedName = name.lowercased()
        guard normalizedName.hasPrefix("cu.") else { return false }

        if normalizedName.contains("usbserial") { return true }
        if normalizedName.contains("usbmodem") { return true }
        if normalizedName.contains("usb-to-serial") { return true }
        if normalizedName.contains("usb_to_uart") { return true }
        if normalizedName.contains("usbtouart") { return true }
        if normalizedName.contains("wchusbserial") { return true }
        if normalizedName.contains("slab_usbtouart") { return true }
        if normalizedName.contains("cp210") { return true }
        if normalizedName.contains("ch340") { return true }
        if normalizedName.contains("ch341") { return true }
        return normalizedName.contains("ftdi")
    }
}

struct StreamConfig: Sendable {
    var effect: LEDEffect = .rainbow
    var staticColor: LEDColor = LEDColor.palette[0]
    var brightness: Double
    var speed: Double
    var ledCount: Int
    var paused: Bool = false
    var lightsOff: Bool = false
}

final class AdalightController {
    var onConnectedChanged: (@MainActor (Bool) -> Void)?
    var onError: (@MainActor (String) -> Void)?

    private struct StreamState {
        struct FadeIn {
            let runGeneration: Int
            let startedAtNanoseconds: UInt64
            let durationNanoseconds: UInt64
        }

        struct FadeOut {
            let runGeneration: Int
            let startedAtNanoseconds: UInt64
            let durationNanoseconds: UInt64
            let initialConfig: StreamConfig
            let initialFrame: [UInt8]?
        }

        struct VisualTransition {
            let runGeneration: Int
            let startedAtNanoseconds: UInt64
            let durationNanoseconds: UInt64
            let fromFrame: [UInt8]
        }

        var config = StreamConfig(brightness: 75, speed: 25, ledCount: 65)
        var generation = 0
        var lastFrame: [UInt8]?
        var fadeIn: FadeIn?
        var fadeOut: FadeOut?
        var visualTransition: VisualTransition?
    }

    // Swift-native lock rather than NSLock: the Xcode previews JIT
    // crashes on Obj-C message sends to NSLock (unrecognized selector).
    private let state = OSAllocatedUnfairLock(initialState: StreamState())

    // Synchronous and lock-based so UI interactions hand the streaming
    // thread a new config without spawning tasks or hopping executors.
    func updateConfig(_ config: StreamConfig, visualTransitionDuration: TimeInterval = 0) {
        let durationNanoseconds = UInt64(max(0, visualTransitionDuration) * 1_000_000_000)

        state.withLock { state in
            let effectChanged = state.config.effect != config.effect
            let staticColorChanged = state.config.staticColor.name != config.staticColor.name
                && (state.config.effect == .static || config.effect == .static)
            let lightsOffChanged = state.config.lightsOff != config.lightsOff

            if effectChanged || staticColorChanged || lightsOffChanged {
                if durationNanoseconds > 0,
                   state.fadeOut == nil,
                   let lastFrame = state.lastFrame {
                    state.visualTransition = StreamState.VisualTransition(
                        runGeneration: state.generation,
                        startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
                        durationNanoseconds: durationNanoseconds,
                        fromFrame: lastFrame
                    )
                } else {
                    state.visualTransition = nil
                }
            }

            state.config = config
        }
    }

    func start(port: String, initialConfig: StreamConfig, fadeInDuration: TimeInterval = 0) {
        let fadeInNanoseconds = UInt64(max(0, fadeInDuration) * 1_000_000_000)
        let runGeneration = state.withLock { state in
            state.generation += 1
            state.config = initialConfig
            state.lastFrame = nil
            state.fadeIn = fadeInNanoseconds > 0 && !initialConfig.lightsOff && initialConfig.brightness > 0
                ? StreamState.FadeIn(
                    runGeneration: state.generation,
                    startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
                    durationNanoseconds: fadeInNanoseconds
                )
                : nil
            state.fadeOut = nil
            state.visualTransition = nil
            return state.generation
        }

        // Serial I/O blocks (open, write, tcdrain), so it runs on its own
        // dispatch queue instead of the Swift concurrency cooperative pool —
        // blocking a pool thread stalls unrelated tasks and makes the UI
        // stutter. A dedicated queue (not NSThread) keeps this file free of
        // Obj-C calls, which crash under the previews JIT.
        DispatchQueue(label: "AdalightSerialStream", qos: .utility).async { [weak self] in
            self?.runLoop(port: port, runGeneration: runGeneration)
        }
    }

    func fadeOutAndStop(duration: TimeInterval) {
        let durationNanoseconds = UInt64(max(0, duration) * 1_000_000_000)
        let shouldStopImmediately = state.withLock { state -> Bool in
            guard state.fadeOut == nil else { return false }

            if durationNanoseconds == 0 || state.config.lightsOff || state.config.brightness <= 0 {
                return true
            }

            var initialConfig = state.config
            if let fadeIn = state.fadeIn,
               fadeIn.runGeneration == state.generation {
                let elapsed = DispatchTime.now().uptimeNanoseconds - fadeIn.startedAtNanoseconds
                let progress = min(1, Double(elapsed) / Double(fadeIn.durationNanoseconds))
                initialConfig.brightness *= Self.smoothStep(progress)
            }

            state.fadeIn = nil
            state.fadeOut = StreamState.FadeOut(
                runGeneration: state.generation,
                startedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
                durationNanoseconds: durationNanoseconds,
                initialConfig: initialConfig,
                initialFrame: state.lastFrame
            )
            state.visualTransition = nil
            return false
        }

        if shouldStopImmediately {
            stopImmediately()
        }
    }

    private func stopImmediately() {
        state.withLock { state in
            state.generation += 1
            state.lastFrame = nil
            state.fadeIn = nil
            state.fadeOut = nil
            state.visualTransition = nil
        }

        Task { @MainActor [onConnectedChanged] in
            onConnectedChanged?(false)
        }
    }

    private func isCurrent(_ runGeneration: Int) -> Bool {
        state.withLock { $0.generation == runGeneration }
    }

    private func streamSnapshot() -> (
        config: StreamConfig,
        fadeIn: StreamState.FadeIn?,
        fadeOut: StreamState.FadeOut?,
        visualTransition: StreamState.VisualTransition?
    ) {
        state.withLock { ($0.config, $0.fadeIn, $0.fadeOut, $0.visualTransition) }
    }

    private func recordLastFrame(_ frame: [UInt8], for runGeneration: Int) {
        state.withLock { state in
            guard state.generation == runGeneration else { return }
            state.lastFrame = frame
        }
    }

    nonisolated private static func smoothStep(_ progress: Double) -> Double {
        let clamped = min(1, max(0, progress))
        return clamped * clamped * (3 - 2 * clamped)
    }

    // Delivers a callback on the main actor, dropping it if this streaming
    // run has been superseded by a newer start()/fadeOutAndStop() meanwhile.
    private func deliver(ifCurrent runGeneration: Int, _ action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            guard self.isCurrent(runGeneration) else { return }
            action()
        }
    }

    private func runLoop(port: String, runGeneration: Int) {
        let fd = open(port, O_RDWR | O_NOCTTY)
        guard fd != -1 else {
            deliver(ifCurrent: runGeneration) { [self] in
                onConnectedChanged?(false)
                onError?("Cannot open port: \(port)")
            }
            return
        }

        guard configureSerialPort(fd) else {
            close(fd)
            deliver(ifCurrent: runGeneration) { [self] in
                onConnectedChanged?(false)
                onError?("Failed to configure serial port: \(port)")
            }
            return
        }

        tcflush(fd, TCIOFLUSH)
        usleep(100_000)

        deliver(ifCurrent: runGeneration) { [self] in
            onConnectedChanged?(true)
        }

        var lastLEDCount = 65

        defer {
            let blankConfig = StreamConfig(brightness: 0, speed: 0, ledCount: lastLEDCount)
            writeAll(makeFrame(config: blankConfig, gradientOffset: 0), to: fd)
            close(fd)
            deliver(ifCurrent: runGeneration) { [self] in
                onConnectedChanged?(false)
            }
        }

        var gradientOffset = 0.0

        while isCurrent(runGeneration) {
            let snapshot = streamSnapshot()
            var config = snapshot.config
            var frame: [UInt8]

            if let fadeOut = snapshot.fadeOut,
               fadeOut.runGeneration == runGeneration {
                let elapsed = DispatchTime.now().uptimeNanoseconds - fadeOut.startedAtNanoseconds
                if elapsed >= fadeOut.durationNanoseconds {
                    break
                }

                let progress = Double(elapsed) / Double(fadeOut.durationNanoseconds)
                let smoothProgress = Self.smoothStep(progress)

                if let initialFrame = fadeOut.initialFrame {
                    let blankConfig = StreamConfig(
                        brightness: 0,
                        speed: 0,
                        ledCount: fadeOut.initialConfig.ledCount
                    )
                    frame = blendFrames(
                        from: initialFrame,
                        to: makeFrame(config: blankConfig, gradientOffset: 0),
                        progress: smoothProgress
                    )
                    config = fadeOut.initialConfig
                } else {
                    config = fadeOut.initialConfig
                    config.brightness *= 1 - smoothProgress
                    frame = makeFrame(config: config, gradientOffset: gradientOffset)
                }
            } else if let fadeIn = snapshot.fadeIn,
                      fadeIn.runGeneration == runGeneration {
                let elapsed = DispatchTime.now().uptimeNanoseconds - fadeIn.startedAtNanoseconds
                if elapsed < fadeIn.durationNanoseconds {
                    let progress = Double(elapsed) / Double(fadeIn.durationNanoseconds)
                    config.brightness *= Self.smoothStep(progress)
                }
                frame = makeFrame(config: config, gradientOffset: gradientOffset)
            } else {
                frame = makeFrame(config: config, gradientOffset: gradientOffset)
            }

            if snapshot.fadeOut == nil,
               let transition = snapshot.visualTransition,
               transition.runGeneration == runGeneration {
                let elapsed = DispatchTime.now().uptimeNanoseconds - transition.startedAtNanoseconds
                if elapsed < transition.durationNanoseconds {
                    let progress = Double(elapsed) / Double(transition.durationNanoseconds)
                    frame = blendFrames(
                        from: transition.fromFrame,
                        to: frame,
                        progress: Self.smoothStep(progress)
                    )
                }
            }

            lastLEDCount = max(1, min(300, config.ledCount))

            writeAll(frame, to: fd)
            recordLastFrame(frame, for: runGeneration)

            if !config.paused && config.effect == .rainbow {
                gradientOffset = positiveModulo(
                    gradientOffset + rgbCircleStep(for: config.speed),
                    Double(max(min(300, config.ledCount), 1))
                )
            }

            let delay = config.paused ? 25_000_000 : frameDelayNanoseconds(for: config.speed)
            if delay > 0 {
                usleep(useconds_t(delay / 1_000))
            }
        }
    }

    private func configureSerialPort(_ fd: Int32) -> Bool {
        var options = termios()
        guard tcgetattr(fd, &options) == 0 else {
            return false
        }

        cfmakeraw(&options)
        cfsetspeed(&options, speed_t(B115200))
        options.c_cflag |= tcflag_t(CLOCAL | CREAD)
        options.c_cflag &= ~tcflag_t(PARENB | CSTOPB | CSIZE)
        options.c_cflag |= tcflag_t(CS8)
#if os(macOS)
        options.c_cflag &= ~tcflag_t(CRTSCTS)
#endif

        return tcsetattr(fd, TCSANOW, &options) == 0
    }

    private func makeFrame(config: StreamConfig, gradientOffset: Double) -> [UInt8] {
        let physicalLEDCount = max(1, min(300, config.ledCount))
        let outputLEDCount = physicalLEDCount * 3
        let countMinusOne = UInt16(outputLEDCount - 1)
        let hi = UInt8((countMinusOne & 0xFF00) >> 8)
        let lo = UInt8(countMinusOne & 0x00FF)
        let checksum = hi ^ lo ^ 0x55
        let header = [UInt8]("Ada".utf8) + [hi, lo, checksum]

        var frame = header
        frame.reserveCapacity(header.count + outputLEDCount * 3)

        let brightnessScale = config.lightsOff ? 0.0 : max(0.0, min(100.0, config.brightness)) / 100.0

        for index in 0 ..< outputLEDCount {
            let color = colorForPixel(index: index, physicalLEDCount: physicalLEDCount, config: config, gradientOffset: gradientOffset)
            let red = clampByte(Double(color.red) * brightnessScale)
            let green = clampByte(Double(color.green) * brightnessScale)
            let blue = clampByte(Double(color.blue) * brightnessScale)

            frame += [red, green, blue]
        }

        return frame
    }

    private func blendFrames(from: [UInt8], to: [UInt8], progress: Double) -> [UInt8] {
        guard from.count == to.count, to.count > 6 else { return to }

        let clampedProgress = min(1, max(0, progress))
        let inverseProgress = 1 - clampedProgress
        var blended = to

        for index in 6 ..< to.count {
            let value = Double(from[index]) * inverseProgress + Double(to[index]) * clampedProgress
            blended[index] = UInt8(max(0, min(255, Int(value.rounded()))))
        }

        return blended
    }

    private func colorForPixel(index: Int, physicalLEDCount: Int, config: StreamConfig, gradientOffset: Double) -> LEDColor {
        switch config.effect {
        case .static:
            return config.staticColor
        case .rainbow:
            let (red, green, blue) = rgbCircleGradientColor(
                physicalIndex: index % physicalLEDCount,
                physicalLEDCount: physicalLEDCount,
                offset: gradientOffset
            )
            return LEDColor(name: "Rainbow", red: red, green: green, blue: blue)
        }
    }

    private func frameDelayNanoseconds(for speed: Double) -> UInt64 {
        let speedFactor = max(0.0, min(100.0, speed)) / 100.0
        if speedFactor >= 1.0 {
            return 0
        }

        // 0% -> ~25ms delay, 100% -> 0ms delay.
        return UInt64((1.0 - speedFactor) * 25_000_000.0)
    }

    private func rgbCircleStep(for speed: Double) -> Double {
        let speedFactor = max(0.0, min(100.0, speed)) / 100.0
        // 0% -> no movement, 100% -> fastest movement.
        return speedFactor * 0.65
    }

    private func rgbCircleGradientColor(physicalIndex: Int, physicalLEDCount: Int, offset: Double) -> (UInt8, UInt8, UInt8) {
        let shiftedPosition = positiveModulo(Double(physicalIndex) - offset, Double(physicalLEDCount))
        let position = shiftedPosition / Double(physicalLEDCount)

        // Three phase-shifted cosine waves form a seamless color wheel. The
        // gentle shaping keeps the colors rich without the hard derivatives
        // and brightness dips of direct red -> green -> blue interpolation.
        let fullTurn = 2 * Double.pi
        let shapingExponent = 1.35
        let channel: (Double) -> Double = { phase in
            let wave = 0.5 + 0.5 * cos(fullTurn * (position - phase))
            return pow(max(0, wave), shapingExponent) * 255
        }

        let red = channel(0)
        let green = channel(1.0 / 3.0)
        let blue = channel(2.0 / 3.0)

        return (clampByte(red), clampByte(green), clampByte(blue))
    }

    private func clampByte(_ value: Double) -> UInt8 {
        UInt8(max(0, min(255, Int(value.rounded()))))
    }

    private func positiveModulo(_ value: Double, _ modulus: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: modulus)
        return result >= 0 ? result : result + modulus
    }

    private func writeAll(_ bytes: [UInt8], to fd: Int32) {
        bytes.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            var bytesWritten = 0
            while bytesWritten < bytes.count {
                let result = write(fd, baseAddress.advanced(by: bytesWritten), bytes.count - bytesWritten)

                if result > 0 {
                    bytesWritten += result
                } else if result == -1 && errno == EINTR {
                    continue
                } else {
                    break
                }
            }
        }

        tcdrain(fd)
    }
}
