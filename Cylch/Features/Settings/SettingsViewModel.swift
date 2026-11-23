import Combine
import Darwin
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    static let shared = SettingsViewModel()

    @Published var brightness: Double = 60 {
        didSet {
            persistSettings()
            pushConfig()
        }
    }
    @Published var speed: Double = 40 {
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
    @Published private(set) var connecting: Bool = false
    @Published private(set) var disconnecting: Bool = false
    @Published var availablePorts: [String] = []
    @Published var errorMessage: String?
    @Published var turnOffWithDisplay: Bool = false {
        didSet {
            persistSettings()
            pushConfig()
        }
    }

    private let settingsStore: UserDefaultsSettingsStore
    private var connectionPreference: Bool
    private let controller = AdalightController()
    private let deviceMonitor = SerialDeviceMonitor()
    private let displaySleepMonitor = DisplaySleepMonitor()
    private var serialDevices: [SerialDeviceIdentity] = []
    /// The physical device the stream was started on.
    private var activeDevice: SerialDeviceIdentity?
    /// The device to stream to again once it reappears after dropping off the bus.
    private var reconnectTarget: SerialDeviceIdentity?
    private var reconnectGraceTask: Task<Void, Never>?
    private var reconnectRetryTask: Task<Void, Never>?
    private var reconnectAttemptsLeft = 0
    private var preserveReconnectPreferenceDuringFade = false
    private var disconnectionCompletions: [() -> Void] = []

    private nonisolated static let lightTransitionDuration: TimeInterval = 0.5
    /// How long the stream stays "connected" while waiting for a dropped device to come back.
    private static let reconnectGracePeriod: Duration = .seconds(3)
    private static let reconnectRetryInterval: Duration = .milliseconds(500)
    /// A freshly attached port may not be ready to open yet, so allow a few retries.
    private static let maxReconnectAttempts = 10

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
        turnOffWithDisplay = persisted.turnOffWithDisplay

        controller.onConnectedChanged = { [weak self] isConnected in
            Task { @MainActor in
                self?.connectionStateDidChange(isConnected)
            }
        }

        controller.onConnectionFailed = { [weak self] message in
            Task { @MainActor in
                self?.connectionDidFail(message)
            }
        }

        deviceMonitor.onDevicesChanged = { [weak self] devices in
            self?.serialDevicesDidChange(devices)
        }

        displaySleepMonitor.onDisplaysAsleepChanged = { [weak self] _, animated in
            guard let self, turnOffWithDisplay else { return }
            pushConfig(visualTransitionDuration: animated ? Self.lightTransitionDuration : 0)
        }

        persistSettings()
    }

    func onAppear() {
        deviceMonitor.start()
        displaySleepMonitor.start()
        refreshPorts()
        pushConfig()
    }

    func refreshPorts() {
        updateAvailablePorts(SerialDeviceMonitor.currentDevices())
    }

    private func updateAvailablePorts(_ devices: [SerialDeviceIdentity]) {
        serialDevices = devices.filter {
            Self.isSupportedUSBSerialDeviceName(($0.path as NSString).lastPathComponent)
        }
        let ports = serialDevices.map(\.path)
        availablePorts = ports

        // Keep the port of a device being streamed to or waited for, even while it is gone.
        guard !connected, !connecting, reconnectTarget == nil else { return }

        if selectedPort.isEmpty || !ports.contains(selectedPort) {
            selectedPort = Self.preferredPort(in: ports) ?? ports.first ?? ""
        }
    }

    private func serialDevicesDidChange(_ devices: [SerialDeviceIdentity]) {
        updateAvailablePorts(devices)
        reconnectAttemptsLeft = Self.maxReconnectAttempts
        reconnectIfTargetAvailable()
    }

    func autoConnectOnLaunch() {
        let portToRestore = selectedPort
        deviceMonitor.start()
        displaySleepMonitor.start()
        refreshPorts()
        pushConfig()

        guard connectionPreference,
              !connected,
              !connecting else {
            return
        }

        if !portToRestore.isEmpty {
            guard availablePorts.contains(portToRestore) else {
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
        guard !connecting, !connected, !disconnecting else { return }

        guard !selectedPort.isEmpty else {
            errorMessage = "No serial port selected."
            return
        }

        errorMessage = nil
        cancelReconnect()
        connectionPreference = true
        persistSettings()
        startStream(port: selectedPort)
    }

    private func startStream(port: String) {
        connecting = true
        activeDevice = serialDevices.first { $0.path == port }
        controller.start(
            port: port,
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

        // While waiting for the device to come back there is no live stream to fade out.
        let hasLiveStream = reconnectTarget == nil
        cancelReconnect()
        preserveReconnectPreferenceDuringFade = preservingReconnectPreference
        disconnecting = true
        controller.fadeOutAndStop(duration: hasLiveStream ? Self.lightTransitionDuration : 0)
    }

    private func connectionDidFail(_ message: String) {
        connecting = false

        if disconnecting {
            connectionStateDidChange(false)
            return
        }

        if reconnectTarget == nil, connected, let activeDevice {
            beginReconnect(to: activeDevice)
            return
        }

        if reconnectTarget != nil {
            if reconnectGraceTask != nil || reconnectAttemptsLeft > 0 {
                scheduleReconnectRetry()
            }
            return
        }

        connectionStateDidChange(false)
        errorMessage = message
    }

    /// A broken stream usually means the device briefly dropped off the USB bus, for
    /// example when another device on the same hub is unplugged. Keep the stream
    /// "connected" for a grace period and pick the device up again under whatever
    /// port name it reappears with.
    private func beginReconnect(to device: SerialDeviceIdentity) {
        reconnectTarget = device
        reconnectAttemptsLeft = Self.maxReconnectAttempts
        reconnectGraceTask = Task { [weak self] in
            try? await Task.sleep(for: Self.reconnectGracePeriod)
            guard !Task.isCancelled else { return }
            self?.reconnectGracePeriodDidExpire()
        }
        reconnectIfTargetAvailable()
    }

    private func reconnectGracePeriodDidExpire() {
        reconnectGraceTask = nil
        reconnectRetryTask?.cancel()
        reconnectRetryTask = nil
        guard reconnectTarget != nil, connected else { return }

        // The device is really gone. Show it as disconnected, but keep waiting for it.
        connectionStateDidChange(false)
        errorMessage = "LED device disconnected. It will reconnect when plugged back in."
    }

    private func scheduleReconnectRetry() {
        reconnectRetryTask?.cancel()
        reconnectRetryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.reconnectRetryInterval)
            guard !Task.isCancelled else { return }
            self?.refreshPorts()
            self?.reconnectIfTargetAvailable()
        }
    }

    private func reconnectIfTargetAvailable() {
        guard let reconnectTarget,
              !connecting,
              !disconnecting,
              let device = serialDevices.first(where: { reconnectTarget.matches($0) }) else {
            return
        }

        reconnectAttemptsLeft -= 1
        selectedPort = device.path
        startStream(port: device.path)
    }

    private func cancelReconnect() {
        reconnectTarget = nil
        reconnectGraceTask?.cancel()
        reconnectGraceTask = nil
        reconnectRetryTask?.cancel()
        reconnectRetryTask = nil
    }

    private func connectionStateDidChange(_ isConnected: Bool) {
        let wasConnected = connected
        connecting = false
        connected = isConnected

        if isConnected {
            if reconnectTarget != nil {
                cancelReconnect()
                errorMessage = nil
            }
            connectionPreference = true
            if !wasConnected {
                AppAnalytics.logDeviceConnected()
            }
        } else if !preserveReconnectPreferenceDuringFade, reconnectTarget == nil {
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
        settingsStore.save(PersistedSettings(
            selectedPort: selectedPort,
            ledCount: ledCount,
            shouldReconnect: connectionPreference,
            selectedEffect: selectedEffect.rawValue,
            staticColorName: staticColor.name,
            brightness: brightness,
            speed: speed,
            paused: paused,
            turnOffWithDisplay: turnOffWithDisplay
        ))
    }

    private func pushConfig(visualTransitionDuration: TimeInterval = SettingsViewModel.lightTransitionDuration) {
        controller.updateConfig(
            currentConfig,
            visualTransitionDuration: visualTransitionDuration
        )
    }

    private var currentConfig: StreamConfig {
        let lightsOff = turnOffWithDisplay && displaySleepMonitor.displaysAsleep
        return StreamConfig(effect: selectedEffect, staticColor: staticColor, brightness: brightness, speed: speed, ledCount: ledCount, paused: paused, lightsOff: lightsOff)
    }

    private static func preferredPort(in ports: [String]) -> String? {
        ports.first { $0.lowercased().contains("usbserial") } ?? ports.first
    }

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
