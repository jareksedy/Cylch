import Combine
import Darwin
import Foundation

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
    @Published private(set) var connecting: Bool = false
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

    func autoConnectOnLaunch() {
        let portToRestore = selectedPort
        refreshPorts()
        startScheduleMonitor()
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
        connecting = true
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
        connecting = false
        connected = isConnected

        if isConnected {
            connectionPreference = true
            AppAnalytics.logDeviceConnected()
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
