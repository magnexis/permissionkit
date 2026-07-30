import Foundation

/// Serializes duplicate native requests and shares the resulting value among callers.
public actor PermissionRequestCoordinator {
    public static let shared = PermissionRequestCoordinator()
    private var inFlight: [PermissionID: Task<PermissionResult, Never>] = [:]
    public init() {}
    public func request(_ permission: AnyPermission) async -> PermissionResult {
        if let task = inFlight[permission.id] { return await task.value }
        let task = Task { await permission.performRequest() }
        inFlight[permission.id] = task
        await PermissionKitConfiguration.emit(.requestStarted(permission.id))
        let result = await task.value
        inFlight[permission.id] = nil
        await PermissionKitConfiguration.emit(.requestCompleted(result))
        return result
    }
}

public enum PermissionGroupRequestStrategy: Sendable { case sequential, stopOnDenial, requestOnlyUndetermined, custom(@Sendable (PermissionState) -> Bool) }
public struct PermissionGroupResult: Sendable {
    public let results: [PermissionResult]
    public var granted: [PermissionID] { results.filter(\.isGranted).map(\.permission) }
    public var denied: [PermissionID] { results.filter(\.isDenied).map(\.permission) }
    public var restricted: [PermissionID] { results.filter { $0.currentStatus == .restricted }.map(\.permission) }
    public var unsupported: [PermissionID] { results.filter { $0.currentStatus == .unsupported }.map(\.permission) }
    public var allGranted: Bool { !results.isEmpty && results.allSatisfy(\.isGranted) }
}
public struct PermissionGroup: Sendable {
    public let permissions: [AnyPermission]
    public init(_ permissions: [AnyPermission]) { self.permissions = permissions }
    public func request(strategy: PermissionGroupRequestStrategy = .sequential) async -> PermissionGroupResult {
        var results: [PermissionResult] = []
        let uniquePermissions = Dictionary(permissions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let plan = await PermissionPlanner.plan(for: Array(uniquePermissions.values))
        for id in plan.orderedPermissions {
            guard !Task.isCancelled, let permission = uniquePermissions[id] else { break }
            let state = await permission.state()
            let shouldRequest: Bool
            switch strategy { case .requestOnlyUndetermined: shouldRequest = state.status == .notDetermined; case .custom(let predicate): shouldRequest = predicate(state); default: shouldRequest = true }
            guard shouldRequest else { continue }
            let result = await permission.request(); results.append(result)
            if case .stopOnDenial = strategy, result.isDenied { break }
        }
        return PermissionGroupResult(results: results)
    }
}
