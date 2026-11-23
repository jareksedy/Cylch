
import Foundation
import Darwin

struct PersistedSettings: Sendable, Equatable {
    var selectedPort = ""
    var ledCount = 65
    var shouldReconnect = true
    var selectedEffect = LEDEffect.rainbow.rawValue
    var staticColorName = LEDColor.palette[0].name
    var brightness = 60.0
    var speed = 40.0
    var paused = false
    var turnOffWithDisplay = false
}

@MainActor
final class UserDefaultsSettingsStore {
    static let shared = UserDefaultsSettingsStore(
        defaults: getenv("XCODE_RUNNING_FOR_PREVIEWS") == nil ? .standard : nil
    )

    private enum Key {
        static let selectedPort = "settings.connection.port"
        static let ledCount = "settings.connection.ledCount"
        static let shouldReconnect = "settings.connection.shouldReconnect"
        static let selectedEffect = "settings.effect.selected"
        static let staticColorName = "settings.effect.staticColor"
        static let brightness = "settings.brightness"
        static let speed = "settings.speed"
        static let paused = "settings.paused"
        static let turnOffWithDisplay = "settings.display.turnOffWithDisplay"
    }

    private let defaults: UserDefaults?

    init(defaults: UserDefaults?) {
        self.defaults = defaults
    }

    func load() -> PersistedSettings {
        guard let defaults else { return PersistedSettings() }

        var settings = PersistedSettings()

        if let value = defaults.string(forKey: Key.selectedPort) {
            settings.selectedPort = value
        }
        if defaults.object(forKey: Key.ledCount) != nil {
            settings.ledCount = defaults.integer(forKey: Key.ledCount)
        }
        if defaults.object(forKey: Key.shouldReconnect) != nil {
            settings.shouldReconnect = defaults.bool(forKey: Key.shouldReconnect)
        }
        if let value = defaults.string(forKey: Key.selectedEffect) {
            settings.selectedEffect = value
        }
        if let value = defaults.string(forKey: Key.staticColorName) {
            settings.staticColorName = value
        }
        if defaults.object(forKey: Key.brightness) != nil {
            settings.brightness = defaults.double(forKey: Key.brightness)
        }
        if defaults.object(forKey: Key.speed) != nil {
            settings.speed = defaults.double(forKey: Key.speed)
        }
        if defaults.object(forKey: Key.paused) != nil {
            settings.paused = defaults.bool(forKey: Key.paused)
        }
        if defaults.object(forKey: Key.turnOffWithDisplay) != nil {
            settings.turnOffWithDisplay = defaults.bool(forKey: Key.turnOffWithDisplay)
        }

        return settings
    }

    func save(_ settings: PersistedSettings) {
        guard let defaults else { return }

        defaults.set(settings.selectedPort, forKey: Key.selectedPort)
        defaults.set(settings.ledCount, forKey: Key.ledCount)
        defaults.set(settings.shouldReconnect, forKey: Key.shouldReconnect)
        defaults.set(settings.selectedEffect, forKey: Key.selectedEffect)
        defaults.set(settings.staticColorName, forKey: Key.staticColorName)
        defaults.set(settings.brightness, forKey: Key.brightness)
        defaults.set(settings.speed, forKey: Key.speed)
        defaults.set(settings.paused, forKey: Key.paused)
        defaults.set(settings.turnOffWithDisplay, forKey: Key.turnOffWithDisplay)

        // Drop values left behind by the removed night schedule.
        Self.legacyKeys.forEach(defaults.removeObject(forKey:))
    }

    private static let legacyKeys = [
        "settings.schedule.enabled",
        "settings.schedule.startMinute",
        "settings.schedule.endMinute"
    ]
}
