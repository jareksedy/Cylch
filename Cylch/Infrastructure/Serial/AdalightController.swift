import Darwin
import Foundation
import os

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
    /// Reports `true` once the port is open and `false` after an intentional stop.
    var onConnectedChanged: (@MainActor (Bool) -> Void)?
    /// Reports a port that failed to open or a stream that broke unexpectedly.
    var onConnectionFailed: (@MainActor (String) -> Void)?

    private struct SerialFailure {
        let operation: String
        let code: Int32

        var message: String {
            "\(operation) failed: \(String(cString: strerror(code)))"
        }
    }

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

        var config = StreamConfig(brightness: 60, speed: 40, ledCount: 65)
        var generation = 0
        var lastFrame: [UInt8]?
        var fadeIn: FadeIn?
        var fadeOut: FadeOut?
        var visualTransition: VisualTransition?
    }

    private let state = OSAllocatedUnfairLock(initialState: StreamState())
    /// Wakes an idle stream as soon as there is something new to show.
    private let wakeSignal = DispatchSemaphore(value: 0)
    private static let idleCheckInterval: DispatchTimeInterval = .seconds(1)

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
        wakeSignal.signal()
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
        wakeSignal.signal()

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
        wakeSignal.signal()

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
        wakeSignal.signal()

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
                onConnectionFailed?("Cannot open port: \(port)")
            }
            return
        }

        guard configureSerialPort(fd) else {
            close(fd)
            deliver(ifCurrent: runGeneration) { [self] in
                onConnectionFailed?("Failed to configure serial port: \(port)")
            }
            return
        }

        tcflush(fd, TCIOFLUSH)
        usleep(100_000)

        deliver(ifCurrent: runGeneration) { [self] in
            onConnectedChanged?(true)
        }

        var lastLEDCount = 65
        var streamFailure: SerialFailure?
        var stoppedIntentionally = false

        defer {
            let runIsCurrent = isCurrent(runGeneration)
            if runIsCurrent, streamFailure == nil {
                let blankConfig = StreamConfig(brightness: 0, speed: 0, ledCount: lastLEDCount)
                writeAll(makeFrame(config: blankConfig, gradientOffset: 0), to: fd)
            }

            close(fd)

            if runIsCurrent {
                let failureToReport = stoppedIntentionally ? nil : streamFailure
                deliver(ifCurrent: runGeneration) { [self] in
                    if let failureToReport {
                        onConnectionFailed?("Connection lost: \(failureToReport.message)")
                    } else {
                        onConnectedChanged?(false)
                    }
                }
            }
        }

        var gradientOffset = 0.0
        var lastSentFrame: [UInt8]?

        while isCurrent(runGeneration) {
            let snapshot = streamSnapshot()
            var config = snapshot.config
            var frame: [UInt8]

            if let fadeOut = snapshot.fadeOut,
               fadeOut.runGeneration == runGeneration {
                let elapsed = DispatchTime.now().uptimeNanoseconds - fadeOut.startedAtNanoseconds
                if elapsed >= fadeOut.durationNanoseconds {
                    stoppedIntentionally = true
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

            // Once the strip is dark and stays dark, stop streaming until something changes.
            if frame == lastSentFrame, frame.dropFirst(6).allSatisfy({ $0 == 0 }) {
                _ = wakeSignal.wait(timeout: .now() + Self.idleCheckInterval)
                continue
            }

            if let failure = writeAll(frame, to: fd) {
                streamFailure = failure
                break
            }
            lastSentFrame = frame
            recordLastFrame(frame, for: runGeneration)
            // Changes signaled up to now are picked up by the next snapshot anyway.
            while wakeSignal.wait(timeout: .now()) == .success {}

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

        return UInt64((1.0 - speedFactor) * 25_000_000.0)
    }

    private func rgbCircleStep(for speed: Double) -> Double {
        let speedFactor = max(0.0, min(100.0, speed)) / 100.0
        return speedFactor * 0.65
    }

    private func rgbCircleGradientColor(physicalIndex: Int, physicalLEDCount: Int, offset: Double) -> (UInt8, UInt8, UInt8) {
        let shiftedPosition = positiveModulo(Double(physicalIndex) - offset, Double(physicalLEDCount))
        let position = shiftedPosition / Double(physicalLEDCount)

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

    @discardableResult
    private func writeAll(_ bytes: [UInt8], to fd: Int32) -> SerialFailure? {
        var failure: SerialFailure?

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
                    failure = SerialFailure(
                        operation: "Serial write",
                        code: result == 0 ? EIO : errno
                    )
                    return
                }
            }
        }

        if let failure {
            return failure
        }

        while tcdrain(fd) == -1 {
            let code = errno
            if code == EINTR {
                continue
            }
            return SerialFailure(operation: "Serial drain", code: code)
        }

        return nil
    }
}
