#if canImport(SwiftUI)
import SwiftUI
import PermissionKit

private struct PermissionEnvironmentKey: EnvironmentKey { static let defaultValue = PermissionEnvironment.live }
public extension EnvironmentValues { var permissionEnvironment: PermissionEnvironment { get { self[PermissionEnvironmentKey.self] } set { self[PermissionEnvironmentKey.self] = newValue } } }
public extension View { func permissionEnvironment(_ environment: PermissionEnvironment) -> some View { environment(\.permissionEnvironment, environment) } }

@MainActor @propertyWrapper public struct PermissionState: DynamicProperty {
    @State private var value: PermissionKit.PermissionState
    private let permission: AnyPermission
    public init(wrappedValue: PermissionKit.PermissionState? = nil, _ permission: AnyPermission) { self.permission = permission; _value = State(initialValue: wrappedValue ?? PermissionKit.PermissionState(permission: permission.id, status: .notDetermined)) }
    public var wrappedValue: PermissionKit.PermissionState { value }
    public var projectedValue: Self { self }
    public mutating func update() { Task { value = await permission.state() } }
    public func request() async { value = await permission.state(); _ = await permission.request(); value = await permission.state() }
}

public struct PermissionRequestButton: View {
    private let permission: AnyPermission; public init(permission: AnyPermission) { self.permission = permission }
    public var body: some View { Button("Enable \(permission.name)") { Task { _ = await permission.request() } }.accessibilityHint("Requests \(permission.name) access") }
}
public struct PermissionStatusLabel: View { public let state: PermissionKit.PermissionState; public init(state: PermissionKit.PermissionState) { self.state = state }; public var body: some View { Text(state.status.rawValue).accessibilityLabel("Permission status: \(state.status.rawValue)") } }
public struct PermissionSettingsButton: View { public let permission: AnyPermission; public init(permission: AnyPermission) { self.permission = permission }; public var body: some View { Button("Open Settings") { Task { await permission.openSettings() } } } }

public struct PermissionDeniedView: View {
    public let permission: AnyPermission
    public init(permission: AnyPermission) { self.permission = permission }
    public var body: some View { let explanation = permission.explanation(for: .denied); VStack(spacing: 12) { Image(systemName: "hand.raised").font(.largeTitle); Text(explanation.title).font(.headline); Text(explanation.message).multilineTextAlignment(.center); PermissionSettingsButton(permission: permission) }.accessibilityElement(children: .combine) }
}

public struct PermissionRestrictedView: View {
    public let permission: AnyPermission
    public init(permission: AnyPermission) { self.permission = permission }
    public var body: some View { let explanation = permission.explanation(for: .restricted); VStack(spacing: 12) { Image(systemName: "lock").font(.largeTitle); Text(explanation.title).font(.headline); Text(explanation.message).multilineTextAlignment(.center) }.accessibilityElement(children: .combine) }
}

public struct PermissionGroupView: View {
    public let permissions: [AnyPermission]
    public init(permissions: [AnyPermission]) { self.permissions = permissions }
    public var body: some View { List(permissions, id: \.id) { permission in HStack { Text(permission.name); Spacer(); PermissionRequestButton(permission: permission) } } }
}

public struct PermissionDashboard: View {
    public let permissions: [AnyPermission]
    @State private var states: [PermissionID: PermissionKit.PermissionState] = [:]
    public init(permissions: [AnyPermission] = [Permission.camera, Permission.microphone, Permission.photos, Permission.locationWhenInUse, Permission.notifications]) { self.permissions = permissions }
    public var body: some View {
        List(permissions, id: \.id) { permission in
            HStack {
                VStack(alignment: .leading) { Text(permission.name); Text(permission.metadata.shortDescription).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                PermissionStatusLabel(state: states[permission.id] ?? PermissionKit.PermissionState(permission: permission.id, status: .unknown))
                PermissionRequestButton(permission: permission)
            }
        }
        .navigationTitle("Permissions")
        .task { await refresh() }
        .refreshable { await refresh() }
    }
    private func refresh() async { states = Dictionary(uniqueKeysWithValues: await permissions.asyncMap { permission in (permission.id, await permission.state()) }) }
}

public struct PermissionOnboardingFlow<Content: View>: View {
    public let permission: AnyPermission; private let content: (PermissionExplanation) -> Content
    public init(permission: AnyPermission, @ViewBuilder content: @escaping (PermissionExplanation) -> Content) { self.permission = permission; self.content = content }
    public var body: some View { VStack { content(permission.explanation(for: .beforeRequest)); PermissionRequestButton(permission: permission) } }
}

private extension Array where Element == AnyPermission {
    func asyncMap<T: Sendable>(_ transform: @escaping @Sendable (AnyPermission) async -> T) async -> [T] {
        await withTaskGroup(of: T.self, returning: [T].self) { group in
            for element in self { group.addTask { await transform(element) } }
            var values: [T] = []; for await value in group { values.append(value) }; return values
        }
    }
}
#endif
