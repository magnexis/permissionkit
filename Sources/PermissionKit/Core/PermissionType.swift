import Foundation

public protocol PermissionType: Sendable {
    associatedtype Details: Sendable
    var id: PermissionID { get }; var name: String { get }; var metadata: PermissionMetadata { get }; var isSupported: Bool { get }
    func status() async -> PermissionStatus
    func request() async -> PermissionResult
    func details() async -> Details
}

public struct AnyPermission: Sendable, Hashable {
    public let id: PermissionID; public let name: String; public let metadata: PermissionMetadata; public let isSupported: Bool
    private let stateOperation: @Sendable () async -> PermissionState
    private let requestOperation: @Sendable () async -> PermissionResult
    private let capabilityOperation: @Sendable () async -> PermissionCapabilityStatus
    public init<P: PermissionType>(_ permission: P) {
        id = permission.id; name = permission.name; metadata = permission.metadata; isSupported = permission.isSupported
        stateOperation = { await permission.state() }; requestOperation = { await permission.request() }; capabilityOperation = { await permission.capability }
    }
    public init(id: PermissionID, name: String, metadata: PermissionMetadata, isSupported: Bool = true, state: @escaping @Sendable () async -> PermissionState, request: @escaping @Sendable () async -> PermissionResult, capability: @escaping @Sendable () async -> PermissionCapabilityStatus = { .available }) {
        self.id = id; self.name = name; self.metadata = metadata; self.isSupported = isSupported; stateOperation = state; requestOperation = request; capabilityOperation = capability
    }
    public func status() async -> PermissionStatus { await stateOperation().status }
    public func state() async -> PermissionState { await stateOperation() }
    public func request() async -> PermissionResult { await PermissionRequestCoordinator.shared.request(self) }
    public var capability: PermissionCapabilityStatus { get async { await capabilityOperation() } }
    public var environmentSupport: PermissionEnvironmentSupport { metadata.requiresPhysicalDevice ? .physicalDeviceRequired : (isSupported ? .supported : .unsupported) }
    func performRequest() async -> PermissionResult { await requestOperation() }
    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public extension PermissionType {
    func state() async -> PermissionState { PermissionState(permission: id, status: await status()) }
    var capability: PermissionCapabilityStatus { get async { isSupported ? .available : .unsupportedPlatform } }
}
