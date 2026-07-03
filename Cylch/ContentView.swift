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

enum LEDEffect: String, CaseIterable, Identifiable {
    case `static` = "Static"
    case rainbow = "Rainbow"

    var id: String { rawValue }
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

    static let palette: [LEDColor] = [
        LEDColor(name: "Red", red: 255, green: 0, blue: 0),
        LEDColor(name: "Orange", red: 255, green: 96, blue: 0),
        LEDColor(name: "Yellow", red: 255, green: 210, blue: 0),
        LEDColor(name: "Green", red: 0, green: 255, blue: 80),
        LEDColor(name: "Cyan", red: 0, green: 220, blue: 255),
        LEDColor(name: "Blue", red: 0, green: 90, blue: 255),
        LEDColor(name: "Purple", red: 170, green: 70, blue: 255),
        LEDColor(name: "White", red: 255, green: 255, blue: 255)
    ]
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Settings...") {
            NSApplication.shared.activate(ignoringOtherApps: true)
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
    @StateObject private var viewModel = SettingsViewModel.shared
    @Namespace private var pickerNamespace
    @State private var showSettingsPopover = false

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
                    showSettingsPopover.toggle()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                    settingsPopover
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
                    Text(effect.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .medium : .regular))
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
            CircularKnob(value: $viewModel.brightness)
                .frame(width: 140, height: 140)
                .help("Brightness")

            CircularKnob(value: $viewModel.speed, gaugeStyle: .solid(.accentColor))
                .frame(width: 140, height: 140)
                .disabled(viewModel.selectedEffect == .static)
                .help("Speed")
        }
    }

    private var colorPalette: some View {
        HStack(spacing: 0) {
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedEffect == .rainbow)
                .help(ledColor.name)
            }
        }
        .background(Capsule().fill(Color.primary.opacity(0.04)))
        .opacity(viewModel.selectedEffect == .rainbow ? 0.45 : 1)
        .saturation(viewModel.selectedEffect == .rainbow ? 0.25 : 1)
    }

    private var settingsPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsSection("Connection") {
                connectionSettings
            }

            Divider()

            settingsSection("Schedule") {
                scheduleSettings
            }
        }
        .font(.system(size: 13, design: .monospaced))
        .padding(16)
        .frame(width: 300, alignment: .leading)
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private var scheduleSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Night schedule", isOn: $viewModel.scheduleEnabled)

            DatePicker("From", selection: $viewModel.scheduleStartTime, displayedComponents: .hourAndMinute)
                .disabled(!viewModel.scheduleEnabled)

            DatePicker("Until", selection: $viewModel.scheduleEndTime, displayedComponents: .hourAndMinute)
                .disabled(!viewModel.scheduleEnabled)

            Text(viewModel.scheduleSummary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Serial Port")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button("Refresh") {
                        viewModel.refreshPorts()
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11, design: .monospaced))
                }

                Picker("Serial Port", selection: $viewModel.selectedPort) {
                    ForEach(viewModel.availablePorts, id: \.self) { port in
                        Text(port).tag(port)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
                .disabled(viewModel.connected)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("LEDs")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Stepper(value: $viewModel.ledCount, in: 1...300) {
                    Text("\(viewModel.ledCount)")
                        .font(.system(size: 13, design: .monospaced))
                        .frame(width: 40, alignment: .leading)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .frame(width: 420, height: 330)
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

    private func connect() {
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

actor StreamConfigStore {
    private var config: StreamConfig

    init(initial: StreamConfig) {
        config = initial
    }

    func set(_ newConfig: StreamConfig) {
        config = newConfig
    }

    func get() -> StreamConfig {
        config
    }
}

final class AdalightController {
    var onConnectedChanged: (@MainActor (Bool) -> Void)?
    var onError: (@MainActor (String) -> Void)?

    private var streamTask: Task<Void, Never>?
    private let configStore = StreamConfigStore(initial: StreamConfig(brightness: 75, speed: 25, ledCount: 65))

    func updateConfig(_ config: StreamConfig) {
        Task {
            await configStore.set(config)
        }
    }

    func start(port: String, initialConfig: StreamConfig) {
        stop()

        Task {
            await configStore.set(initialConfig)
        }

        streamTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            await self.runLoop(port: port)
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        onConnectedChanged?(false)
    }

    private func runLoop(port: String) async {
        let fd = open(port, O_RDWR | O_NOCTTY)
        guard fd != -1 else {
            await MainActor.run {
                onConnectedChanged?(false)
                onError?("Cannot open port: \(port)")
            }
            return
        }

        guard configureSerialPort(fd) else {
            close(fd)
            await MainActor.run {
                onConnectedChanged?(false)
                onError?("Failed to configure serial port: \(port)")
            }
            return
        }

        tcflush(fd, TCIOFLUSH)
        usleep(100_000)

        await MainActor.run {
            onConnectedChanged?(true)
        }

        var lastLEDCount = 65

        defer {
            let blankConfig = StreamConfig(brightness: 0, speed: 0, ledCount: lastLEDCount)
            writeAll(makeFrame(config: blankConfig, gradientOffset: 0), to: fd)
            close(fd)
            Task { @MainActor in
                onConnectedChanged?(false)
            }
        }

        var gradientOffset = 0.0

        while !Task.isCancelled {
            let config = await configStore.get()
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
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    break
                }
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
