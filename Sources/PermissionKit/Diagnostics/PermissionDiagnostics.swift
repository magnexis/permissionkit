import Foundation

public enum DiagnosticSeverity: String, Codable, Sendable { case info, warning, error }
public struct PermissionDiagnosticIssue: Codable, Sendable { public let severity: DiagnosticSeverity; public let permission: PermissionID?; public let code: String; public let message: String; public let suggestedFix: String? }
public struct PermissionDiagnosticReport: Codable, Sendable { public let issues: [PermissionDiagnosticIssue]; public var isValid: Bool { !issues.contains { $0.severity == .error } } }
/// Inspects the host bundle only; it never modifies Info.plist or a privacy manifest.
public enum PermissionDiagnostics {
    public static func validate(permissions: [AnyPermission], bundle: Bundle = .main) -> PermissionDiagnosticReport {
        var issues: [PermissionDiagnosticIssue] = []
        for permission in permissions {
            for key in permission.metadata.requiredUsageDescriptionKeys {
                let value = bundle.object(forInfoDictionaryKey: key) as? String
                if value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { issues.append(.init(severity: .error, permission: permission.id, code: "missing_usage_description", message: "\(key) is missing or empty.", suggestedFix: "Add a clear non-empty \(key) value to the app Info.plist.")) }
            }
            if !permission.isSupported { issues.append(.init(severity: .warning, permission: permission.id, code: "unsupported_platform", message: "\(permission.name) is unsupported on this platform.", suggestedFix: nil)) }
            if permission.metadata.requiresPhysicalDevice { issues.append(.init(severity: .warning, permission: permission.id, code: "physical_device_required", message: "\(permission.name) may have limited simulator behavior.", suggestedFix: "Validate this permission on a physical device before release.")) }
        }
        let ids = Set(permissions.map(\.id))
        if ids.contains(.locationAlways) && !ids.contains(.locationWhenInUse) { issues.append(.init(severity: .warning, permission: .locationAlways, code: "location_request_order", message: "Always location is requested without when-in-use location in the same plan.", suggestedFix: "Educate the user and request when-in-use access before requesting always access.")) }
        return PermissionDiagnosticReport(issues: issues)
    }

    /// Performs non-prompting runtime checks. No permission request is made.
    public static func validateRuntime(permissions: [AnyPermission]) async -> PermissionDiagnosticReport {
        var issues: [PermissionDiagnosticIssue] = []
        for permission in permissions {
            let capability = await permission.capability
            switch capability {
            case .available: break
            case .missingHardware: issues.append(.init(severity: .warning, permission: permission.id, code: "missing_hardware", message: "\(permission.name) hardware is unavailable.", suggestedFix: "Offer a workflow that does not require this hardware."))
            case .unsupportedPlatform: issues.append(.init(severity: .warning, permission: permission.id, code: "unsupported_platform", message: "\(permission.name) is unsupported on this platform.", suggestedFix: nil))
            case .unavailableInSimulator: issues.append(.init(severity: .warning, permission: permission.id, code: "simulator_limitation", message: "\(permission.name) has limited simulator behavior.", suggestedFix: "Validate on a physical device."))
            case .entitlementRequired: issues.append(.init(severity: .error, permission: permission.id, code: "entitlement_required", message: "\(permission.name) requires an entitlement.", suggestedFix: "Add the entitlement in the host app and provisioning profile."))
            case .configurationRequired: issues.append(.init(severity: .warning, permission: permission.id, code: "configuration_required", message: "\(permission.name) requires additional app configuration.", suggestedFix: "Review the permission metadata and host app configuration."))
            case .managedRestriction: issues.append(.init(severity: .warning, permission: permission.id, code: "managed_restriction", message: "\(permission.name) is restricted by device or account policy.", suggestedFix: "Do not repeatedly prompt; explain the restriction."))
            case .unknown: issues.append(.init(severity: .warning, permission: permission.id, code: "unknown_capability", message: "\(permission.name) capability could not be determined.", suggestedFix: "Handle this state conservatively."))
            }
        }
        return PermissionDiagnosticReport(issues: issues)
    }
}

public struct PermissionDeclaration: Codable, Sendable { public let permission: PermissionID; public let usageDescriptionKeys: [String] }
public enum PrivacyAPICategory: String, Codable, Sendable { case camera, microphone, photoLibrary, location, contacts, notifications, speechRecognition, tracking, mediaLibrary }
public struct PrivacyManifestPlan: Codable, Sendable { public let accessedAPICategories: [PrivacyAPICategory]; public let permissionDeclarations: [PermissionDeclaration]; public let warnings: [String] }
public enum PermissionPrivacyManifest {
    public static func generate(for permissions: [AnyPermission]) -> PrivacyManifestPlan {
        let categories: [PrivacyAPICategory] = permissions.compactMap { switch $0.id { case .camera: .camera; case .microphone: .microphone; case .photosReadWrite, .photosAddOnly: .photoLibrary; case .locationWhenInUse, .locationAlways: .location; case .contacts: .contacts; case .notifications: .notifications; case .speechRecognition: .speechRecognition; case .tracking: .tracking; case .mediaLibrary: .mediaLibrary; default: nil } }
        return PrivacyManifestPlan(accessedAPICategories: categories, permissionDeclarations: permissions.map { .init(permission: $0.id, usageDescriptionKeys: $0.metadata.requiredUsageDescriptionKeys) }, warnings: ["Review Apple’s current privacy-manifest documentation and select reason codes in the host app. PermissionKit does not infer them."])
    }
}
