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
    case rainbow = "Rainbow"
    case `static` = "Static"
    case breathe = "Breathe"
    case pulse = "Pulse"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .rainbow: "rainbow"
        case .static: "circle.fill"
        case .breathe: "wind"
        case .pulse: "waveform.path"
        }
    }
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

    var body: some View {
        NavigationSplitView {
            List(LEDEffect.allCases, selection: $viewModel.selectedEffect) { effect in
                Label(effect.rawValue, systemImage: effect.iconName)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 18) {
                    circularSliderCard(
                        title: "Brightness",
                        value: $viewModel.brightness,
                        formattedValue: "\(Int(viewModel.brightness))%"
                    )
                    circularSliderCard(
                        title: "Speed",
                        value: $viewModel.speed,
                        formattedValue: "\(Int(viewModel.speed))",
                        gaugeStyle: .solid(.accentColor)
                    )
                }

                statusLine

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Serial Port")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Refresh") {
                                viewModel.refreshPorts()
                            }
                            .buttonStyle(.link)
                            .font(.caption)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: $viewModel.ledCount, in: 1...300) {
                            Text("\(viewModel.ledCount)")
                                .monospacedDigit()
                                .frame(width: 40, alignment: .leading)
                        }
                        .frame(width: 120)
                    }

                    Spacer(minLength: 0)

                    Button(viewModel.connected ? "Disconnect" : "Connect") {
                        viewModel.toggleConnection()
                    }
                    .controlSize(.regular)
                    .disabled(viewModel.selectedPort.isEmpty)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewModel.onAppear()
        }
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.connected ? .green : .secondary)
                .frame(width: 7, height: 7)

            Text(viewModel.connected ? "Streaming \(viewModel.selectedEffect.rawValue.lowercased())" : "Idle")
            Text("•")
            Text("\(viewModel.ledCount) LEDs")
            Text("•")
            Text("\(Int(viewModel.brightness))% bright")
            Text("•")
            Text("speed \(Int(viewModel.speed))")

            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .regular, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    private func circularSliderCard(title: String, value: Binding<Double>, formattedValue: String, gaugeStyle: CircularKnob.GaugeStyle = .rainbow, disabled: Bool = false) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedValue)
                    .font(.system(.caption, design: .monospaced))
                    .monospacedDigit()
            }

            CircularKnob(value: value, gaugeStyle: gaugeStyle)
                .frame(width: 104, height: 104)
                .disabled(disabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
    @Published var selectedPort: String = ""
    @Published var connected: Bool = false
    @Published var availablePorts: [String] = []
    @Published var errorMessage: String?

    private let controller = AdalightController()

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
        pushConfig()
    }

    func refreshPorts() {
        let ports = Self.discoverSerialPorts()
        availablePorts = ports

        if selectedPort.isEmpty || !ports.contains(selectedPort) {
            selectedPort = ports.first ?? ""
        }
    }

    func toggleConnection() {
        if connected {
            controller.stop()
            return
        }

        guard !selectedPort.isEmpty else {
            errorMessage = "No serial port selected."
            return
        }

        errorMessage = nil
        controller.start(port: selectedPort, initialConfig: currentConfig)
    }

    private func pushConfig() {
        controller.updateConfig(currentConfig)
    }

    private var currentConfig: StreamConfig {
        StreamConfig(brightness: brightness, speed: speed, ledCount: ledCount, effect: selectedEffect)
    }

    private static func discoverSerialPorts() -> [String] {
        guard let deviceEntries = try? FileManager.default.contentsOfDirectory(atPath: "/dev") else {
            return []
        }

        return deviceEntries
            .filter { $0.hasPrefix("cu.") }
            .map { "/dev/\($0)" }
            .sorted()
    }
}

struct StreamConfig: Sendable {
    var brightness: Double
    var speed: Double
    var ledCount: Int
    var effect: LEDEffect = .rainbow
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

        streamTask = Task.detached(priority: .userInitiated) { [weak self] in
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

        defer {
            close(fd)
            Task { @MainActor in
                onConnectedChanged?(false)
            }
        }

        var gradientOffset = 0.0

        while !Task.isCancelled {
            let config = await configStore.get()
            let frame = makeFrame(config: config, gradientOffset: gradientOffset)
            writeAll(frame, to: fd)

            gradientOffset = positiveModulo(
                gradientOffset + rgbCircleStep(for: config.speed),
                Double(max(min(300, config.ledCount), 1))
            )

            let delay = frameDelayNanoseconds(for: config.speed)
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

        let brightnessScale = max(0.0, min(100.0, config.brightness)) / 100.0

        for index in 0 ..< outputLEDCount {
            let (redBase, greenBase, blueBase) = rgbCircleGradientColor(
                physicalIndex: index % physicalLEDCount,
                physicalLEDCount: physicalLEDCount,
                offset: gradientOffset
            )

            let red = clampByte(Double(redBase) * brightnessScale)
            let green = clampByte(Double(greenBase) * brightnessScale)
            let blue = clampByte(Double(blueBase) * brightnessScale)

            frame += [red, green, blue]
        }

        return frame
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
