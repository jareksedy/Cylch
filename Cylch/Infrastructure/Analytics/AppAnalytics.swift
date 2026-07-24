import FirebaseAnalytics

enum AppAnalytics {
    static func logDeviceConnected() {
        Analytics.logEvent("device_connected", parameters: nil)
    }
}
