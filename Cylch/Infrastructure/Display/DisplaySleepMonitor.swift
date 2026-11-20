import AppKit

/// Reports when the displays go dark, either on their own or because the Mac is going to sleep.
@MainActor
final class DisplaySleepMonitor {
    /// `animated` is false when the Mac is about to sleep and there is no time for a fade.
    var onDisplaysAsleepChanged: (@MainActor (_ asleep: Bool, _ animated: Bool) -> Void)?

    private var screensAsleep = false
    private var systemAsleep = false
    private var observers: [NSObjectProtocol] = []

    var displaysAsleep: Bool {
        screensAsleep || systemAsleep
    }

    func start() {
        guard observers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        let handlers: [(Notification.Name, (DisplaySleepMonitor) -> Void)] = [
            (NSWorkspace.screensDidSleepNotification, { $0.update(screensAsleep: true) }),
            (NSWorkspace.screensDidWakeNotification, { $0.update(screensAsleep: false) }),
            (NSWorkspace.willSleepNotification, { $0.update(systemAsleep: true, animated: false) }),
            // The displays light up on a full wake; don't wait for a screens-wake that may never come.
            (NSWorkspace.didWakeNotification, { $0.update(screensAsleep: false, systemAsleep: false) })
        ]

        observers = handlers.map { name, handler in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handler(self)
                }
            }
        }
    }

    private func update(screensAsleep: Bool? = nil, systemAsleep: Bool? = nil, animated: Bool = true) {
        let wasAsleep = displaysAsleep
        if let screensAsleep { self.screensAsleep = screensAsleep }
        if let systemAsleep { self.systemAsleep = systemAsleep }

        guard displaysAsleep != wasAsleep else { return }
        onDisplaysAsleepChanged?(displaysAsleep, animated)
    }
}
