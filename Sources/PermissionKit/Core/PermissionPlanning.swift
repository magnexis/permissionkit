import Foundation

public struct PermissionDependency: Sendable, Hashable {
    public let prerequisite: PermissionID
    public let target: PermissionID
    public let reason: String
    public init(prerequisite: PermissionID, target: PermissionID, reason: String) { self.prerequisite = prerequisite; self.target = target; self.reason = reason }
}

public struct PermissionPlan: Sendable {
    public let orderedPermissions: [PermissionID]
    public let dependencies: [PermissionDependency]
    public let missingPrerequisites: [PermissionDependency]
    public let unsupported: [PermissionID]
    public let requiresUserEducation: Bool
}

public enum PermissionPlanner {
    public static let knownDependencies = [PermissionDependency(prerequisite: .locationWhenInUse, target: .locationAlways, reason: "Always location should be requested only after when-in-use access is granted.")]

    public static func plan(for permissions: [AnyPermission]) async -> PermissionPlan {
        let requested = Set(permissions.map(\.id))
        let dependencies = knownDependencies.filter { requested.contains($0.target) }
        let missing = dependencies.filter { !requested.contains($0.prerequisite) }
        let ordered = topologicalOrder(permissions.map(\.id), dependencies: dependencies)
        let unsupported = permissions.filter { !$0.isSupported }.map(\.id)
        return PermissionPlan(orderedPermissions: ordered, dependencies: dependencies, missingPrerequisites: missing, unsupported: unsupported, requiresUserEducation: !dependencies.isEmpty)
    }

    private static func topologicalOrder(_ ids: [PermissionID], dependencies: [PermissionDependency]) -> [PermissionID] {
        var output: [PermissionID] = []
        func visit(_ id: PermissionID) {
            for dependency in dependencies where dependency.target == id && !output.contains(dependency.prerequisite) { visit(dependency.prerequisite) }
            if !output.contains(id) { output.append(id) }
        }
        ids.forEach(visit)
        return output
    }
}
