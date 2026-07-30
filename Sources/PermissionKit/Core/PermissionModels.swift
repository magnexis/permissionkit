import Foundation

/// A stable identifier for a system or application-defined permission.
public struct PermissionID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.init(value) }
}

public extension PermissionID {
    static let camera: Self = "apple.camera"
    static let microphone: Self = "apple.microphone"
    static let photosReadWrite: Self = "apple.photos.read-write"
    static let photosAddOnly: Self = "apple.photos.add-only"
    static let locationWhenInUse: Self = "apple.location.when-in-use"
    static let locationAlways: Self = "apple.location.always"
    static let notifications: Self = "apple.notifications"
    static let contacts: Self = "apple.contacts"
    static let speechRecognition: Self = "apple.speech-recognition"
    static let tracking: Self = "apple.tracking-transparency"
    static let mediaLibrary: Self = "apple.media-library"
}

public enum PermissionStatus: String, Codable, Sendable, CaseIterable {
    case notDetermined, authorized, denied, restricted, limited, provisional, ephemeral, unsupported, unavailable, unknown
}

public enum PermissionRestrictionReason: String, Codable, Sendable {
    case managedPolicy, parentalControls, deviceConfiguration, accountRestriction, unknown
}

public struct PermissionState: Sendable, Equatable {
    public let permission: PermissionID
    public let status: PermissionStatus
    public let rawValueDescription: String?
    public let canRequest: Bool
    public let canOpenSettings: Bool
    public let reason: PermissionRestrictionReason?
    public init(permission: PermissionID, status: PermissionStatus, rawValueDescription: String? = nil, canRequest: Bool? = nil, canOpenSettings: Bool? = nil, reason: PermissionRestrictionReason? = nil) {
        self.permission = permission; self.status = status; self.rawValueDescription = rawValueDescription
        self.canRequest = canRequest ?? (status == .notDetermined)
        self.canOpenSettings = canOpenSettings ?? (status == .denied || status == .restricted || status == .limited)
        self.reason = reason
    }
}

public enum PermissionError: Error, Sendable, Equatable {
    case unsupportedPlatform, unavailableOnDevice, missingUsageDescription(key: String), missingEntitlement(String), invalidRequestOrder, applicationNotActive, requestAlreadyInProgress, frameworkError(String), unknown(String)
}

public struct PermissionResult: Sendable {
    public let permission: PermissionID
    public let previousStatus: PermissionStatus
    public let currentStatus: PermissionStatus
    public let didPresentSystemPrompt: Bool
    public let requestDate: Date
    public let error: PermissionError?
    public init(permission: PermissionID, previousStatus: PermissionStatus, currentStatus: PermissionStatus, didPresentSystemPrompt: Bool, requestDate: Date = .now, error: PermissionError? = nil) {
        self.permission = permission; self.previousStatus = previousStatus; self.currentStatus = currentStatus; self.didPresentSystemPrompt = didPresentSystemPrompt; self.requestDate = requestDate; self.error = error
    }
    public var isGranted: Bool { currentStatus == .authorized || currentStatus == .limited || currentStatus == .provisional || currentStatus == .ephemeral }
    public var isDenied: Bool { currentStatus == .denied || currentStatus == .restricted }
    public var requiresSettings: Bool { currentStatus == .denied || currentStatus == .restricted }
    public var didChange: Bool { previousStatus != currentStatus }
}

public enum ApplePlatform: String, Codable, Sendable, Hashable { case iOS, macOS, watchOS, tvOS, visionOS }
public enum PermissionRequestMechanism: String, Codable, Sendable { case runtimePrompt, systemSettings, entitlement, usageDescription, hardwareCapability, managedPolicy, unsupported }
public enum PermissionSettingsDestination: String, Codable, Sendable { case application }
public enum PermissionCapabilityStatus: Sendable, Equatable { case available, missingHardware, unsupportedPlatform, unavailableInSimulator, entitlementRequired, configurationRequired, managedRestriction, unknown }
public enum PermissionEnvironmentSupport: Sendable, Equatable { case supported, limitedSimulatorBehavior, physicalDeviceRequired, unsupported }

public struct PermissionMetadata: Sendable {
    public let id: PermissionID; public let displayName: String; public let shortDescription: String
    public let requestMechanism: PermissionRequestMechanism; public let requiredUsageDescriptionKeys: [String]; public let requiredEntitlements: [String]
    public let supportedPlatforms: Set<ApplePlatform>; public let requiresPhysicalDevice: Bool; public let settingsDestination: PermissionSettingsDestination?
    public init(id: PermissionID, displayName: String, shortDescription: String, requestMechanism: PermissionRequestMechanism = .runtimePrompt, requiredUsageDescriptionKeys: [String] = [], requiredEntitlements: [String] = [], supportedPlatforms: Set<ApplePlatform>, requiresPhysicalDevice: Bool = false, settingsDestination: PermissionSettingsDestination? = .application) {
        self.id = id; self.displayName = displayName; self.shortDescription = shortDescription; self.requestMechanism = requestMechanism; self.requiredUsageDescriptionKeys = requiredUsageDescriptionKeys; self.requiredEntitlements = requiredEntitlements; self.supportedPlatforms = supportedPlatforms; self.requiresPhysicalDevice = requiresPhysicalDevice; self.settingsDestination = settingsDestination
    }
}
