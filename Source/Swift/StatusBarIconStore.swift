import Foundation

/// Manages per-hosts-file status bar icon preferences stored in UserDefaults.
@objc final class StatusBarIconStore: NSObject {
    @objc static let iconChangedNotification = NSNotification.Name("StatusBarIconChangedNotification")

    private static let userDefaultsKey = "statusBarIcons"
    private static let iconColorsKey = "statusBarIconColors"

    @objc static func iconName(forHostsPath path: String) -> String? {
        let dict = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String]
        return dict?[path]
    }

    @objc static func setIconName(_ name: String?, forHostsPath path: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String]) ?? [:]
        dict[path] = name
        UserDefaults.standard.set(dict, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: iconChangedNotification, object: nil)
    }

    @objc static func iconNameForActiveHosts() -> String? {
        guard let path = Preferences.activeHostsFile() else { return nil }
        return iconName(forHostsPath: path)
    }

    // MARK: - Color

    static func iconColor(forHostsPath path: String) -> NSColor? {
        let dict = UserDefaults.standard.dictionary(forKey: iconColorsKey) as? [String: String]
        guard let hex = dict?[path] else { return nil }
        return NSColor(hexString: hex)
    }

    static func setIconColor(_ color: NSColor?, forHostsPath path: String) {
        var dict = (UserDefaults.standard.dictionary(forKey: iconColorsKey) as? [String: String]) ?? [:]
        dict[path] = color?.hexString
        UserDefaults.standard.set(dict, forKey: iconColorsKey)
        NotificationCenter.default.post(name: iconChangedNotification, object: nil)
    }

    @objc static func iconColorForActiveHosts() -> NSColor? {
        guard let path = Preferences.activeHostsFile() else { return nil }
        return iconColor(forHostsPath: path)
    }
}

private extension NSColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X",
            Int(c.redComponent * 255),
            Int(c.greenComponent * 255),
            Int(c.blueComponent * 255))
    }
}
