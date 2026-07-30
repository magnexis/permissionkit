import Foundation
#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct PermissionSnapshot: Codable, Sendable { public let generatedAt: Date; public let states: [PermissionID: PermissionStatus] }
public struct PermissionChange: Sendable { public let permission: PermissionID; public let state: PermissionState }
public actor PermissionCenter: PermissionProviding {
    public static let shared = PermissionCenter()
    private var permissions: [PermissionID: AnyPermission] = [:]
    private var lastStates: [PermissionID: PermissionStatus] = [:]
    private let history = PermissionRequestHistory()
    private var continuations: [UUID: AsyncStream<PermissionChange>.Continuation] = [:]
    public init() {
        for permission in [Permission.camera, Permission.microphone, Permission.photos, Permission.locationWhenInUse, Permission.locationAlways, Permission.notifications, Permission.contacts, Permission.speechRecognition, Permission.tracking, Permission.mediaLibrary] { permissions[permission.id] = permission }
        Task { await self.startLifecycleObservation() }
    }
    public func register(_ permission: AnyPermission) { permissions[permission.id] = permission }
    public func state(for permission: PermissionID) async -> PermissionState {
        guard let permission = permissions[permission] else { return PermissionState(permission: permission, status: .unsupported) }
        return await permission.state()
    }
    public func status(for permission: PermissionID) async -> PermissionStatus { await state(for: permission).status }
    public func request(_ permission: PermissionID) async -> PermissionResult {
        guard let value = permissions[permission] else { return PermissionResult(permission: permission, previousStatus: .unsupported, currentStatus: .unsupported, didPresentSystemPrompt: false, error: .unsupportedPlatform) }
        let result = await value.request(); await history.append(result); await publishIfChanged(permission: permission, force: true); return result
    }
    public func refresh() async { for id in permissions.keys { await publishIfChanged(permission: id) } }
    public func snapshot() async -> PermissionSnapshot { var states: [PermissionID: PermissionStatus] = [:]; for (id, permission) in permissions { states[id] = await permission.status() }; return PermissionSnapshot(generatedAt: .now, states: states) }
    public func requestHistory() async -> [PermissionRequestRecord] { await history.snapshot() }
    public func clearRequestHistory() async { await history.removeAll() }
    public nonisolated var updates: AsyncStream<PermissionChange> { AsyncStream { continuation in Task { await self.add(continuation) } } }
    /// Creates a change stream whose subscription is registered before this method returns.
    public func updatesSequence() -> AsyncStream<PermissionChange> { AsyncStream { continuation in add(continuation) } }
    private func add(_ continuation: AsyncStream<PermissionChange>.Continuation) { let id = UUID(); continuations[id] = continuation; continuation.onTermination = { _ in Task { await self.remove(id) } } }
    private func remove(_ id: UUID) { continuations[id] = nil }
    private func publishIfChanged(permission: PermissionID, force: Bool = false) async {
        let state = await state(for: permission); let previous = lastStates[permission]; lastStates[permission] = state.status
        guard force || previous != state.status else { return }
        if let previous, previous != state.status { await PermissionKitConfiguration.emit(.statusChanged(permission: permission, old: previous, new: state.status)) }
        continuations.values.forEach { $0.yield(PermissionChange(permission: permission, state: state)) }
    }

    private func startLifecycleObservation() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        observeActivation(UIApplication.didBecomeActiveNotification)
        #elseif os(macOS)
        observeActivation(NSApplication.didBecomeActiveNotification)
        #endif
    }

    #if os(iOS) || os(tvOS) || os(visionOS) || os(macOS)
    private func observeActivation(_ notification: Notification.Name) {
        NotificationCenter.default.addObserver(forName: notification, object: nil, queue: nil) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }
    #endif
}
public protocol PermissionProviding: Sendable { func status(for permission: PermissionID) async -> PermissionStatus; func request(_ permission: PermissionID) async -> PermissionResult }
/// A deterministic actor-backed provider for unit tests, previews, and demos.
public actor MockPermissionCenter: PermissionProviding {
    private var states: [PermissionID: PermissionStatus] = [:]; private var responses: [PermissionID: PermissionStatus] = [:]
    public init() {}
    public func set(_ status: PermissionStatus, for permission: PermissionID) { states[permission] = status }
    public func script(permission: PermissionID, initial: PermissionStatus, afterRequest: PermissionStatus) { states[permission] = initial; responses[permission] = afterRequest }
    public func status(for permission: PermissionID) async -> PermissionStatus { states[permission] ?? .notDetermined }
    public func request(_ permission: PermissionID) async -> PermissionResult { let before = states[permission] ?? .notDetermined; let after = responses[permission] ?? before; states[permission] = after; return PermissionResult(permission: permission, previousStatus: before, currentStatus: after, didPresentSystemPrompt: before == .notDetermined) }
    /// Applies deterministic states for multi-permission tests and SwiftUI previews.
    public func apply(_ scenario: PermissionScenario) { for (permission, status) in scenario.states { states[permission] = status } }
}

public struct PermissionScenario: Sendable {
    public let states: [PermissionID: PermissionStatus]
    public init(states: [PermissionID: PermissionStatus]) { self.states = states }
    public static func authorized(_ permissions: [PermissionID]) -> Self { Self(states: Dictionary(uniqueKeysWithValues: permissions.map { ($0, .authorized) })) }
    public static func denied(_ permissions: [PermissionID]) -> Self { Self(states: Dictionary(uniqueKeysWithValues: permissions.map { ($0, .denied) })) }
    public static func mixed(_ states: [PermissionID: PermissionStatus]) -> Self { Self(states: states) }
}
