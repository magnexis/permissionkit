import Foundation

enum NativePermissions {
    static func unsupportedRequest() async -> PermissionResult { PermissionResult(permission: .locationWhenInUse, previousStatus: .unavailable, currentStatus: .unavailable, didPresentSystemPrompt: false, error: .unavailableOnDevice) }
    static func cameraStatus() async -> PermissionStatus {
        #if canImport(AVFoundation)
        importAVCameraStatus()
        #else
        return .unsupported
        #endif
    }
    static func microphoneStatus() async -> PermissionStatus {
        #if canImport(AVFoundation)
        return mapAVAudio(AVFoundation.AVAudioSession.sharedInstance().recordPermission)
        #else
        return .unsupported
        #endif
    }
    static func requestCamera() async -> PermissionResult {
        let before = await cameraStatus()
        #if canImport(AVFoundation)
        guard before == .notDetermined else { return PermissionResult(permission: .camera, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let granted = await withCheckedContinuation { continuation in AVCaptureDevice.requestAccess(for: .video) { continuation.resume(returning: $0) } }
        return PermissionResult(permission: .camera, previousStatus: before, currentStatus: granted ? .authorized : .denied, didPresentSystemPrompt: true)
        #else
        return await unavailable(.camera)
        #endif
    }
    static func requestMicrophone() async -> PermissionResult {
        let before = await microphoneStatus()
        #if canImport(AVFoundation)
        guard before == .notDetermined else { return PermissionResult(permission: .microphone, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let granted = await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) } }
        return PermissionResult(permission: .microphone, previousStatus: before, currentStatus: granted ? .authorized : .denied, didPresentSystemPrompt: true)
        #else
        return await unavailable(.microphone)
        #endif
    }
    static func contactsStatus() async -> PermissionStatus {
        #if canImport(Contacts)
        return mapContacts(CNContactStore.authorizationStatus(for: .contacts))
        #else
        return .unsupported
        #endif
    }
    static func requestContacts() async -> PermissionResult {
        let before = await contactsStatus()
        #if canImport(Contacts)
        guard before == .notDetermined else { return PermissionResult(permission: .contacts, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        do { let granted = try await CNContactStore().requestAccess(for: .contacts); return PermissionResult(permission: .contacts, previousStatus: before, currentStatus: granted ? .authorized : .denied, didPresentSystemPrompt: true) }
        catch { return PermissionResult(permission: .contacts, previousStatus: before, currentStatus: await contactsStatus(), didPresentSystemPrompt: true, error: .frameworkError(error.localizedDescription)) }
        #else
        return await unavailable(.contacts)
        #endif
    }
    static func speechStatus() async -> PermissionStatus {
        #if canImport(Speech)
        return mapSpeech(SFSpeechRecognizer.authorizationStatus())
        #else
        return .unsupported
        #endif
    }
    static func requestSpeech() async -> PermissionResult {
        let before = await speechStatus()
        #if canImport(Speech)
        guard before == .notDetermined else { return PermissionResult(permission: .speechRecognition, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let status = await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) } }
        return PermissionResult(permission: .speechRecognition, previousStatus: before, currentStatus: mapSpeech(status), didPresentSystemPrompt: true)
        #else
        return await unavailable(.speechRecognition)
        #endif
    }
    static func trackingStatus() async -> PermissionStatus {
        #if os(iOS) && canImport(AppTrackingTransparency)
        if #available(iOS 14, *) { return mapTracking(ATTrackingManager.trackingAuthorizationStatus) }
        return .unsupported
        #else
        return .unsupported
        #endif
    }
    static func requestTracking() async -> PermissionResult {
        let before = await trackingStatus()
        #if os(iOS) && canImport(AppTrackingTransparency)
        guard #available(iOS 14, *), before == .notDetermined else { return PermissionResult(permission: .tracking, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false, error: before == .unsupported ? .unsupportedPlatform : nil) }
        let status = await withCheckedContinuation { continuation in ATTrackingManager.requestTrackingAuthorization { continuation.resume(returning: $0) } }
        return PermissionResult(permission: .tracking, previousStatus: before, currentStatus: mapTracking(status), didPresentSystemPrompt: true)
        #else
        return await unavailable(.tracking)
        #endif
    }
    static func mediaLibraryStatus() async -> PermissionStatus {
        #if os(iOS) && canImport(MediaPlayer)
        return mapMediaLibrary(MPMediaLibrary.authorizationStatus())
        #else
        return .unsupported
        #endif
    }
    static func requestMediaLibrary() async -> PermissionResult {
        let before = await mediaLibraryStatus()
        #if os(iOS) && canImport(MediaPlayer)
        guard before == .notDetermined else { return PermissionResult(permission: .mediaLibrary, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let status = await withCheckedContinuation { continuation in MPMediaLibrary.requestAuthorization { continuation.resume(returning: $0) } }
        return PermissionResult(permission: .mediaLibrary, previousStatus: before, currentStatus: mapMediaLibrary(status), didPresentSystemPrompt: true)
        #else
        return await unavailable(.mediaLibrary)
        #endif
    }
    static func photosStatus(access: PhotoAccess = .readWrite) async -> PermissionStatus {
        #if canImport(Photos)
        return mapPhotos(PHPhotoLibrary.authorizationStatus(for: access == .addOnly ? .addOnly : .readWrite))
        #else
        return .unsupported
        #endif
    }
    static func requestPhotos(access: PhotoAccess = .readWrite) async -> PermissionResult {
        let id: PermissionID = access == .addOnly ? .photosAddOnly : .photosReadWrite
        let before = await photosStatus(access: access)
        #if canImport(Photos)
        guard before == .notDetermined else { return PermissionResult(permission: id, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let level: PHAccessLevel = access == .addOnly ? .addOnly : .readWrite
        let status = await withCheckedContinuation { continuation in PHPhotoLibrary.requestAuthorization(for: level) { continuation.resume(returning: $0) } }
        return PermissionResult(permission: id, previousStatus: before, currentStatus: mapPhotos(status), didPresentSystemPrompt: true)
        #else
        return await unavailable(.photosReadWrite)
        #endif
    }
    static func locationStatus() async -> PermissionStatus {
        #if canImport(CoreLocation)
        #if os(macOS)
        return mapLocation(CLLocationManager().authorizationStatus)
        #else
        return mapLocation(CLLocationManager.authorizationStatus())
        #endif
        #else
        return .unsupported
        #endif
    }
    static func requestLocation(level: LocationAuthorizationLevel) async -> PermissionResult {
        let id: PermissionID = level == .always ? .locationAlways : .locationWhenInUse
        let before = await locationStatus()
        #if canImport(CoreLocation)
        guard before == .notDetermined || (level == .always && before == .authorized) else { return PermissionResult(permission: id, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        let status = await LocationAuthorizationRequester.request(level: level)
        return PermissionResult(permission: id, previousStatus: before, currentStatus: status, didPresentSystemPrompt: before == .notDetermined)
        #else
        return await unavailable(id)
        #endif
    }
    static func notificationStatus() async -> PermissionStatus {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus { case .notDetermined: return .notDetermined; case .denied: return .denied; case .authorized: return .authorized; case .provisional: return .provisional; case .ephemeral: return .ephemeral; @unknown default: return .unknown }
        #else
        return .unsupported
        #endif
    }
    static func requestNotifications(options requestedOptions: NotificationOptions) async -> PermissionResult {
        let before = await notificationStatus()
        #if canImport(UserNotifications)
        guard before == .notDetermined else { return PermissionResult(permission: .notifications, previousStatus: before, currentStatus: before, didPresentSystemPrompt: false) }
        var options: UNAuthorizationOptions = []
        if requestedOptions.contains(.alert) { options.insert(.alert) }; if requestedOptions.contains(.badge) { options.insert(.badge) }; if requestedOptions.contains(.sound) { options.insert(.sound) }
        do { let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: options); return PermissionResult(permission: .notifications, previousStatus: before, currentStatus: granted ? .authorized : .denied, didPresentSystemPrompt: true) }
        catch { return PermissionResult(permission: .notifications, previousStatus: before, currentStatus: await notificationStatus(), didPresentSystemPrompt: true, error: .frameworkError(error.localizedDescription)) }
        #else
        return await unavailable(.notifications)
        #endif
    }
    private static func unavailable(_ id: PermissionID) async -> PermissionResult { let previous = await status(for: id); return PermissionResult(permission: id, previousStatus: previous, currentStatus: previous, didPresentSystemPrompt: false, error: .unavailableOnDevice) }
    private static func status(for id: PermissionID) async -> PermissionStatus { switch id { case .camera: await cameraStatus(); case .microphone: await microphoneStatus(); case .contacts: await contactsStatus(); case .speechRecognition: await speechStatus(); case .tracking: await trackingStatus(); case .mediaLibrary: await mediaLibraryStatus(); case .photosReadWrite: await photosStatus(); case .photosAddOnly: await photosStatus(access: .addOnly); case .locationWhenInUse, .locationAlways: await locationStatus(); case .notifications: await notificationStatus(); default: .unavailable } }
}

#if canImport(AVFoundation)
import AVFoundation
private func importAVCameraStatus() -> PermissionStatus { switch AVCaptureDevice.authorizationStatus(for: .video) { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
private func mapAVAudio(_ value: AVAudioSession.RecordPermission) -> PermissionStatus { switch value { case .undetermined: .notDetermined; case .granted: .authorized; case .denied: .denied; @unknown default: .unknown } }
#endif
#if canImport(Contacts)
import Contacts
private func mapContacts(_ value: CNAuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
#endif
#if canImport(Speech)
import Speech
private func mapSpeech(_ value: SFSpeechRecognizerAuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
#endif
#if os(iOS) && canImport(AppTrackingTransparency)
import AppTrackingTransparency
@available(iOS 14, *) private func mapTracking(_ value: ATTrackingManager.AuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
#endif
#if os(iOS) && canImport(MediaPlayer)
import MediaPlayer
private func mapMediaLibrary(_ value: MPMediaLibraryAuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
#endif
#if canImport(Photos)
import Photos
private func mapPhotos(_ value: PHAuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorized: .authorized; case .denied: .denied; case .restricted: .restricted; case .limited: .limited; @unknown default: .unknown } }
#endif
#if canImport(CoreLocation)
import CoreLocation
private func mapLocation(_ value: CLAuthorizationStatus) -> PermissionStatus { switch value { case .notDetermined: .notDetermined; case .authorizedAlways, .authorizedWhenInUse: .authorized; case .denied: .denied; case .restricted: .restricted; @unknown default: .unknown } }
@MainActor private final class LocationAuthorizationRequester: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<PermissionStatus, Never>?
    static func request(level: LocationAuthorizationLevel) async -> PermissionStatus { await LocationAuthorizationRequester().request(level: level) }
    private func request(level: LocationAuthorizationLevel) async -> PermissionStatus {
        guard CLLocationManager.locationServicesEnabled() else { return .unavailable }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation; manager.delegate = self
            if level == .always { manager.requestAlwaysAuthorization() } else { manager.requestWhenInUseAuthorization() }
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { continuation?.resume(returning: mapLocation(manager.authorizationStatus)); continuation = nil }
}
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif
