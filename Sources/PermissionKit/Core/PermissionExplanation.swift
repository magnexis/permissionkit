import Foundation

public enum PermissionExplanationContext: Sendable { case beforeRequest, denied, restricted, limited, settingsRequired, unsupported }
public struct PermissionExplanation: Sendable { public let title: String; public let message: String; public let actionTitle: String; public let secondaryActionTitle: String?
    public init(title: String, message: String, actionTitle: String, secondaryActionTitle: String? = nil) { self.title = title; self.message = message; self.actionTitle = actionTitle; self.secondaryActionTitle = secondaryActionTitle }
}
public extension AnyPermission {
    func explanation(for context: PermissionExplanationContext) -> PermissionExplanation {
        switch context {
        case .beforeRequest: return .init(title: "Allow \(name)?", message: metadata.shortDescription, actionTitle: "Continue", secondaryActionTitle: "Not now")
        case .denied, .settingsRequired: return .init(title: "\(name) is off", message: "You can enable \(name.lowercased()) in Settings when you want to use this feature.", actionTitle: "Open Settings", secondaryActionTitle: "Not now")
        case .restricted: return .init(title: "\(name) is restricted", message: "This access is controlled by a device, account, or parental policy.", actionTitle: "OK")
        case .limited: return .init(title: "Limited \(name) access", message: "The app can continue with the access you selected.", actionTitle: "Continue")
        case .unsupported: return .init(title: "\(name) is unavailable", message: "This device or platform does not support this capability.", actionTitle: "OK")
        }
    }
}
