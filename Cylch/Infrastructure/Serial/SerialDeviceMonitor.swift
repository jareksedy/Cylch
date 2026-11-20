import Foundation
import IOKit
import IOKit.serial

/// Identifies the physical USB device behind a serial port, so it can be recognized
/// again after re-enumeration even if macOS gives it a different `/dev/cu.*` name.
struct SerialDeviceIdentity: Equatable, Sendable {
    let path: String
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?
    let locationID: Int?

    func matches(_ other: SerialDeviceIdentity) -> Bool {
        guard let vendorID, let productID,
              vendorID == other.vendorID, productID == other.productID else {
            return path == other.path
        }

        if let serialNumber, !serialNumber.isEmpty {
            return serialNumber == other.serialNumber
        }

        // Adapters without a serial number (e.g. CH340) are told apart by USB location.
        if let locationID {
            return locationID == other.locationID
        }

        return path == other.path
    }
}

/// Watches IOKit for serial ports appearing and disappearing.
@MainActor
final class SerialDeviceMonitor {
    var onDevicesChanged: (@MainActor ([SerialDeviceIdentity]) -> Void)?

    private var notificationPort: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []

    func start() {
        guard notificationPort == nil,
              let port = IONotificationPortCreate(kIOMainPortDefault) else {
            return
        }

        notificationPort = port
        IONotificationPortSetDispatchQueue(port, .main)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let monitor = Unmanaged<SerialDeviceMonitor>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.handleNotification(iterator)
            }
        }

        for notificationType in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port,
                notificationType,
                Self.serialServiceMatching(),
                callback,
                refcon,
                &iterator
            )
            guard result == KERN_SUCCESS else { continue }

            iterators.append(iterator)
            Self.drain(iterator)
        }
    }

    func stop() {
        iterators.forEach { IOObjectRelease($0) }
        iterators.removeAll()

        if let notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
    }

    static func currentDevices() -> [SerialDeviceIdentity] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, serialServiceMatching(), &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var devices: [SerialDeviceIdentity] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            if let device = identity(of: service) {
                devices.append(device)
            }
        }

        return devices.sorted { $0.path < $1.path }
    }

    private func handleNotification(_ iterator: io_iterator_t) {
        // The iterator must be drained to re-arm the notification.
        Self.drain(iterator)
        onDevicesChanged?(Self.currentDevices())
    }

    private static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }

    private static func serialServiceMatching() -> CFMutableDictionary {
        let matching = IOServiceMatching(kIOSerialBSDServiceValue) as NSMutableDictionary
        matching[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes
        return matching
    }

    private static func identity(of service: io_object_t) -> SerialDeviceIdentity? {
        guard let path = IORegistryEntryCreateCFProperty(
            service,
            kIOCalloutDeviceKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return SerialDeviceIdentity(
            path: path,
            vendorID: usbProperty("idVendor", of: service) as? Int,
            productID: usbProperty("idProduct", of: service) as? Int,
            serialNumber: usbProperty("USB Serial Number", of: service) as? String,
            locationID: usbProperty("locationID", of: service) as? Int
        )
    }

    private static func usbProperty(_ key: String, of service: io_object_t) -> Any? {
        IORegistryEntrySearchCFProperty(
            service,
            kIOServicePlane,
            key as CFString,
            kCFAllocatorDefault,
            IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        )
    }
}
