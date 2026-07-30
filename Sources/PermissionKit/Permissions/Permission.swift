import Foundation

/// Namespace for the built-in Apple privacy permissions.
public enum Permission {
    public static let camera = BuiltInPermission.camera.erased
    public static let microphone = BuiltInPermission.microphone.erased
    public static let photos = photos(access: .readWrite)
    public static let locationWhenInUse = location(level: .whenInUse)
    public static let locationAlways = location(level: .always)
    public static let notifications = notifications(options: [.alert, .badge, .sound])
    public static let contacts = BuiltInPermission.contacts.erased
    public static let speechRecognition = BuiltInPermission.speechRecognition.erased
    public static let tracking = BuiltInPermission.tracking.erased
    public static let mediaLibrary = BuiltInPermission.mediaLibrary.erased
    public static func photos(access: PhotoAccess) -> AnyPermission { BuiltInPermission.photos(access).erased }
    public static func location(level: LocationAuthorizationLevel) -> AnyPermission { BuiltInPermission.location(level).erased }
    public static func notifications(options: NotificationOptions = [.alert, .badge, .sound]) -> AnyPermission { BuiltInPermission.notifications(options).erased }
}

public enum PhotoAccess: Sendable { case readWrite, addOnly }
public enum LocationAuthorizationLevel: Sendable { case whenInUse, always }
public struct NotificationOptions: OptionSet, Sendable { public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let alert = Self(rawValue: 1 << 0); public static let badge = Self(rawValue: 1 << 1); public static let sound = Self(rawValue: 1 << 2)
}

struct BuiltInPermission: PermissionType {
    typealias Details = PermissionState
    let id: PermissionID; let name: String; let metadata: PermissionMetadata
    let read: @Sendable () async -> PermissionStatus
    let prompt: @Sendable () async -> PermissionResult
    var isSupported: Bool { currentPlatform.map(metadata.supportedPlatforms.contains) ?? false }
    func status() async -> PermissionStatus { isSupported ? await read() : .unsupported }
    func request() async -> PermissionResult { isSupported ? await prompt() : PermissionResult(permission: id, previousStatus: .unsupported, currentStatus: .unsupported, didPresentSystemPrompt: false, error: .unsupportedPlatform) }
    func details() async -> PermissionState { await state() }
    var erased: AnyPermission { AnyPermission(self) }
}

extension BuiltInPermission {
    static var camera: Self { make(.camera, "Camera", "Capture photos and video.", ["NSCameraUsageDescription"], platforms: [.iOS, .macOS, .visionOS], read: NativePermissions.cameraStatus, request: NativePermissions.requestCamera) }
    static var microphone: Self { make(.microphone, "Microphone", "Record audio.", ["NSMicrophoneUsageDescription"], platforms: [.iOS, .macOS, .watchOS, .tvOS, .visionOS], read: NativePermissions.microphoneStatus, request: NativePermissions.requestMicrophone) }
    static var contacts: Self { make(.contacts, "Contacts", "Access contacts selected by the user.", ["NSContactsUsageDescription"], platforms: [.iOS, .macOS, .watchOS, .visionOS], read: NativePermissions.contactsStatus, request: NativePermissions.requestContacts) }
    static var speechRecognition: Self { make(.speechRecognition, "Speech Recognition", "Convert speech into text on your behalf.", ["NSSpeechRecognitionUsageDescription"], platforms: [.iOS, .macOS, .watchOS, .visionOS], read: NativePermissions.speechStatus, request: NativePermissions.requestSpeech) }
    static var tracking: Self { make(.tracking, "Tracking", "Allow app and website tracking when you choose.", ["NSUserTrackingUsageDescription"], platforms: [.iOS], read: NativePermissions.trackingStatus, request: NativePermissions.requestTracking) }
    static var mediaLibrary: Self { make(.mediaLibrary, "Media Library", "Access your music and media library.", ["NSAppleMusicUsageDescription"], platforms: [.iOS], read: NativePermissions.mediaLibraryStatus, request: NativePermissions.requestMediaLibrary) }
    static func photos(_ access: PhotoAccess) -> Self { let add = access == .addOnly; return make(add ? .photosAddOnly : .photosReadWrite, add ? "Add Photos" : "Photos", "Access the photo library.", ["NSPhotoLibraryUsageDescription"], platforms: [.iOS, .macOS, .visionOS], read: { await NativePermissions.photosStatus(access: access) }, request: { await NativePermissions.requestPhotos(access: access) }) }
    static func location(_ level: LocationAuthorizationLevel) -> Self { let always = level == .always; return make(always ? .locationAlways : .locationWhenInUse, always ? "Location Always" : "Location While Using", "Access location information.", [always ? "NSLocationAlwaysAndWhenInUseUsageDescription" : "NSLocationWhenInUseUsageDescription"], platforms: [.iOS, .macOS, .watchOS, .visionOS], read: NativePermissions.locationStatus, request: { await NativePermissions.requestLocation(level: level) }) }
    static func notifications(_ options: NotificationOptions) -> Self { make(.notifications, "Notifications", "Send notifications.", [], platforms: [.iOS, .macOS, .watchOS, .tvOS, .visionOS], read: NativePermissions.notificationStatus, request: { await NativePermissions.requestNotifications(options: options) }) }
    private static func make(_ id: PermissionID, _ name: String, _ description: String, _ keys: [String], platforms: Set<ApplePlatform>, read: @escaping @Sendable () async -> PermissionStatus, request: @escaping @Sendable () async -> PermissionResult) -> Self {
        Self(id: id, name: name, metadata: PermissionMetadata(id: id, displayName: name, shortDescription: description, requiredUsageDescriptionKeys: keys, supportedPlatforms: platforms), read: read, prompt: request)
    }
}

private var currentPlatform: ApplePlatform? {
    #if os(iOS)
    return .iOS
    #elseif os(visionOS)
    return .visionOS
    #elseif os(macOS)
    return .macOS
    #elseif os(watchOS)
    return .watchOS
    #elseif os(tvOS)
    return .tvOS
    #else
    return nil
    #endif
}
