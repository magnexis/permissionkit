import Foundation

public enum SettingsOpenResult: Sendable { case opened, unavailable, failed }
public enum PermissionSettings {
    @MainActor public static func openAppSettings() async -> SettingsOpenResult {
        #if canImport(UIKit)
        importUIKitSettings()
        #elseif canImport(AppKit)
        return .unavailable
        #else
        return .unavailable
        #endif
    }
}
public extension AnyPermission { @MainActor func openSettings() async -> SettingsOpenResult { await PermissionSettings.openAppSettings() } }
#if canImport(UIKit)
import UIKit
private func importUIKitSettings() -> SettingsOpenResult { guard let url = URL(string: UIApplication.openSettingsURLString) else { return .unavailable }; guard UIApplication.shared.canOpenURL(url) else { return .unavailable }; UIApplication.shared.open(url); return .opened }
#endif
