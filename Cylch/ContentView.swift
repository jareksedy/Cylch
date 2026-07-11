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

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        Button {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        } label: {
            Label("Settings...", image: "settings")
        }
        .keyboardShortcut(",", modifiers: .command)
        .labelStyle(.titleAndIcon)

        Divider()

        Button {
            if viewModel.connected {
                viewModel.stopStreaming()
            } else {
                viewModel.connect()
            }
        } label: {
            Label(viewModel.connected ? "Disconnect" : "Connect", image: viewModel.connected ? "link_horizontal_off" : "link_horizontal")
        }
        .disabled(!viewModel.connected && viewModel.selectedPort.isEmpty)
        .labelStyle(.titleAndIcon)

        Divider()

        levelMenu(
            "Brightness: \(Int(viewModel.brightness))%",
            image: "brightness",
            value: $viewModel.brightness,
            isEnabled: viewModel.connected
        )

        levelMenu(
            "Speed: \(Int(viewModel.speed))%",
            image: "speed",
            value: $viewModel.speed,
            isEnabled: viewModel.connected && viewModel.selectedEffect != .static
        )

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", image: "exit")
        }
        .keyboardShortcut("q", modifiers: .command)
        .onAppear {
            viewModel.onAppear()
        }
        .labelStyle(.titleAndIcon)
    }

    /// A submenu with the 0–100% levels while enabled. NSMenu ignores
    /// .disabled on items with submenus, so when unavailable the control
    /// renders as a plain disabled item instead.
    @ViewBuilder
    private func levelMenu(_ title: String, image: String, value: Binding<Double>, isEnabled: Bool) -> some View {
        if isEnabled {
            Menu {
                levelPicker(for: value)
            } label: {
                Label(title, image: image)
            }
            .labelStyle(.titleAndIcon)
        } else {
            Button {
            } label: {
                Label(title, image: image)
            }
            .disabled(true)
            .labelStyle(.titleAndIcon)
        }
    }

    /// Menu items for the 0–100% levels in 25% steps; the current level
    /// (exact match only) gets a checkmark.
    @ViewBuilder
    private func levelPicker(for value: Binding<Double>) -> some View {
        ForEach([0.0, 25, 50, 75, 100], id: \.self) { level in
            Toggle("\(Int(level))%", isOn: Binding(
                get: { value.wrappedValue == level },
                set: { _ in value.wrappedValue = level }
            ))
        }
    }
}

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel.shared
    @Namespace private var pickerNamespace
    @State private var showConnectionPopover = false
    @State private var showSchedulePopover = false

    var body: some View {
        VStack(spacing: 28) {
            effectPicker
                .frame(width: 320, height: 36)

            transportRow

            colorPalette
                .frame(width: 320, height: 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32)
        .font(.system(size: 13, design: .monospaced))
        .onAppear {
            viewModel.onAppear()
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showSchedulePopover.toggle()
                } label: {
                    Image("moon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                .help("Night Schedule")
                .popover(isPresented: $showSchedulePopover, arrowEdge: .bottom) {
                    SchedulePopoverView()
                }
            }

            ToolbarItem {
                Button {
                    showConnectionPopover.toggle()
                } label: {
                    Image("link_horizontal")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                .help("Connection")
                .popover(isPresented: $showConnectionPopover, arrowEdge: .bottom) {
                    ConnectionPopoverView()
                }
            }
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
                icon: Image("brightness")
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
                icon: Image("speed")
            )
                .frame(width: 140, height: 140)
                .disabled(viewModel.selectedEffect == .static)
                .help("Speed")
        }
        .disabled(!viewModel.connected)
    }

    private var colorPalette: some View {
        let isInactive = viewModel.selectedEffect == .rainbow || !viewModel.connected

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
        .disabled(!viewModel.connected)
        .opacity(isInactive ? 0.45 : 1)
        .saturation(isInactive ? 0.25 : 1)
    }

}

/// Shared chrome for the toolbar popovers, in the app's own voice: an
/// accent template icon with an expanded-width title (echoing the knob
/// labels), then the content — no window-style divider chrome.
private struct SettingsPopoverPanel<Content: View>: View {
    let title: String
    let imageName: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(imageName)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.system(size: 13, weight: .semibold).width(.expanded))
            }
            .padding(.leading, 2)

            content()
        }
        .padding(16)
        .font(.system(size: 13))
        .frame(width: 320, alignment: .leading)
    }
}

/// The controls live on a "card" tinted and stroked exactly like the effect
/// picker and palette capsules in the main window.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 12).width(.expanded))
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 28)
    }
}

/// Status caption at the bottom of a popover: a small state dot that lights
/// up in the given color while active, plus a quiet monospaced telemetry
/// line matching the main window's type.
private struct StatusFooter: View {
    let isActive: Bool
    let activeColor: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Circle()
                .fill(isActive ? activeColor : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 2)
    }
}

struct ConnectionPopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(title: "Connection", imageName: "link_horizontal") {
            SettingsCard {
                SettingsRow(label: "Port") {
                    HStack(spacing: 6) {
                        Picker("Port", selection: $viewModel.selectedPort) {
                            if viewModel.availablePorts.isEmpty {
                                Text("No Ports").tag("")
                            }

                            ForEach(viewModel.availablePorts, id: \.self) { port in
                                Text(port).tag(port)
                            }
                        }
                        .labelsHidden()
                        .disabled(viewModel.connected)

                        Button {
                            viewModel.refreshPorts()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh Ports")
                    }
                }

                SettingsRow(label: "LEDs") {
                    HStack(spacing: 8) {
                        Text("\(viewModel.ledCount)")
                            .monospacedDigit()
                            .frame(minWidth: 30, alignment: .leading)

                        Stepper("LED Count", value: $viewModel.ledCount, in: 1...300)
                            .labelsHidden()
                    }
                }
            }

            Button {
                if viewModel.connected {
                    viewModel.stopStreaming()
                } else {
                    viewModel.connect()
                }
            } label: {
                Label(viewModel.connected ? "Disconnect" : "Connect", image: viewModel.connected ? "link_horizontal_off" : "link_horizontal")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!viewModel.connected && viewModel.selectedPort.isEmpty)

            StatusFooter(
                isActive: viewModel.connected,
                activeColor: .green,
                text: connectionSummary
            )
        }
        .onAppear {
            viewModel.refreshPorts()
        }
    }

    private var connectionSummary: String {
        if viewModel.connected {
            let portName = viewModel.selectedPort.split(separator: "/").last.map(String.init) ?? viewModel.selectedPort
            return "Streaming to \(portName)"
        }

        return viewModel.selectedPort.isEmpty ? "No serial port selected" : "Ready to connect"
    }
}

struct SchedulePopoverView: View {
    @StateObject private var viewModel = SettingsViewModel.shared

    var body: some View {
        SettingsPopoverPanel(title: "Night Schedule", imageName: "moon") {
            SettingsCard {
                SettingsRow(label: "Enabled") {
                    Toggle("Night schedule", isOn: $viewModel.scheduleEnabled)
                        .labelsHidden()
                }

                SettingsRow(label: "From") {
                    DatePicker("From", selection: $viewModel.scheduleStartTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!viewModel.scheduleEnabled)
                }

                SettingsRow(label: "Until") {
                    DatePicker("Until", selection: $viewModel.scheduleEndTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .disabled(!viewModel.scheduleEnabled)
                }
            }

            StatusFooter(
                isActive: viewModel.scheduleActive,
                activeColor: .indigo,
                text: viewModel.scheduleSummary
            )
        }
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
        didSet { pushConfig() }
    }
    @Published var speed: Double = 25 {
        didSet { pushConfig() }
    }
    @Published var ledCount: Int = 65 {
        didSet {
            let clamped = min(300, max(1, ledCount))
            guard ledCount == clamped else {
                ledCount = clamped
                return
            }
            pushConfig()
        }
    }
    @Published var selectedEffect: LEDEffect = .rainbow {
        didSet { pushConfig() }
    }
    @Published var staticColor: LEDColor = LEDColor.palette[0] {
        didSet { pushConfig() }
    }
    @Published var paused: Bool = false {
        didSet { pushConfig() }
    }
    @Published var selectedPort: String = ""
    @Published var connected: Bool = false
    @Published var availablePorts: [String] = []
    @Published var errorMessage: String?
    @Published var scheduleEnabled: Bool = false {
        didSet { updateScheduleState() }
    }
    @Published var scheduleStartTime: Date = SettingsViewModel.timeToday(hour: 23, minute: 0) {
        didSet { updateScheduleState() }
    }
    @Published var scheduleEndTime: Date = SettingsViewModel.timeToday(hour: 7, minute: 0) {
        didSet { updateScheduleState() }
    }
    @Published private(set) var scheduleActive: Bool = false

    var scheduleSummary: String {
        guard scheduleEnabled else { return "Schedule is off" }
        return scheduleActive ? "LEDs are off until schedule ends" : "LEDs stay on until scheduled off time"
    }

    private let controller = AdalightController()
    private var scheduleTask: Task<Void, Never>?

    init() {
        controller.onConnectedChanged = { [weak self] isConnected in
            Task { @MainActor in
                self?.connected = isConnected
            }
        }

        controller.onError = { [weak self] message in
            Task { @MainActor in
                self?.errorMessage = message
            }
        }
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

    /// Called once at launch: discovers ports and, if a USB serial adapter is
    /// present, selects it and starts streaming automatically.
    func autoConnectOnLaunch() {
        refreshPorts()
        pushConfig()

        guard !connected,
              let usbSerialPort = Self.preferredPort(in: availablePorts) else {
            return
        }

        selectedPort = usbSerialPort
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
        guard !selectedPort.isEmpty else {
            errorMessage = "No serial port selected."
            return
        }

        errorMessage = nil
        paused = false
        controller.start(port: selectedPort, initialConfig: currentConfig)
    }

    func stopStreaming() {
        controller.stop()
        paused = false
    }

    private func pushConfig() {
        controller.updateConfig(currentConfig)
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

    /// Prefers a USB serial adapter (e.g. `/dev/cu.usbserial-XXXX`) when present.
    private static func preferredPort(in ports: [String]) -> String? {
        ports.first { $0.localizedCaseInsensitiveContains("usbserial") }
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

            if name.hasPrefix("cu.") {
                ports.append("/dev/\(name)")
            }
        }

        return ports.sorted()
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
        var config = StreamConfig(brightness: 75, speed: 25, ledCount: 65)
        var generation = 0
    }

    // Swift-native lock rather than NSLock: the Xcode previews JIT
    // crashes on Obj-C message sends to NSLock (unrecognized selector).
    private let state = OSAllocatedUnfairLock(initialState: StreamState())

    // Synchronous and lock-based so UI interactions hand the streaming
    // thread a new config without spawning tasks or hopping executors.
    func updateConfig(_ config: StreamConfig) {
        state.withLock { $0.config = config }
    }

    func start(port: String, initialConfig: StreamConfig) {
        let runGeneration = state.withLock { state in
            state.generation += 1
            state.config = initialConfig
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

    func stop() {
        state.withLock { $0.generation += 1 }

        Task { @MainActor [onConnectedChanged] in
            onConnectedChanged?(false)
        }
    }

    private func isCurrent(_ runGeneration: Int) -> Bool {
        state.withLock { $0.generation == runGeneration }
    }

    private func currentConfig() -> StreamConfig {
        state.withLock { $0.config }
    }

    // Delivers a callback on the main actor, dropping it if this streaming
    // run has been superseded by a newer start()/stop() in the meantime.
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
            let config = currentConfig()
            lastLEDCount = max(1, min(300, config.ledCount))

            let frame = makeFrame(config: config, gradientOffset: gradientOffset)
            writeAll(frame, to: fd)

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
        let segment = position * 3.0
        let red: Double
        let green: Double
        let blue: Double

        if segment < 1.0 {
            red = (1.0 - segment) * 255.0
            green = segment * 255.0
            blue = 0.0
        } else if segment < 2.0 {
            let t = segment - 1.0
            red = 0.0
            green = (1.0 - t) * 255.0
            blue = t * 255.0
        } else {
            let t = segment - 2.0
            red = t * 255.0
            green = 0.0
            blue = (1.0 - t) * 255.0
        }

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
