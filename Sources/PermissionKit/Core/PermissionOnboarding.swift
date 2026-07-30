import Foundation

public struct PermissionOnboardingStep: Sendable {
    public let permission: AnyPermission
    public let explanation: PermissionExplanation
    public let prerequisiteIDs: [PermissionID]
}

public struct PermissionOnboardingPlan: Sendable {
    public let steps: [PermissionOnboardingStep]
    public let diagnostics: PermissionDiagnosticReport
    public let dependencies: [PermissionDependency]
}

public struct PermissionOnboardingResult: Sendable {
    public let plan: PermissionOnboardingPlan
    public let groupResult: PermissionGroupResult
}

/// Builds an explicit, dependency-aware onboarding plan. Present each explanation before calling `request`.
public enum PermissionOnboarding {
    public static func plan(for permissions: [AnyPermission], bundle: Bundle = .main) async -> PermissionOnboardingPlan {
        let dependencyPlan = await PermissionPlanner.plan(for: permissions)
        let byID = Dictionary(permissions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let steps = dependencyPlan.orderedPermissions.compactMap { id -> PermissionOnboardingStep? in
            guard let permission = byID[id] else { return nil }
            return PermissionOnboardingStep(permission: permission, explanation: permission.explanation(for: .beforeRequest), prerequisiteIDs: dependencyPlan.dependencies.filter { $0.target == id }.map(\.prerequisite))
        }
        return PermissionOnboardingPlan(steps: steps, diagnostics: PermissionDiagnostics.validate(permissions: permissions, bundle: bundle), dependencies: dependencyPlan.dependencies)
    }

    public static func request(_ plan: PermissionOnboardingPlan, strategy: PermissionGroupRequestStrategy = .requestOnlyUndetermined) async -> PermissionOnboardingResult {
        let result = await PermissionGroup(plan.steps.map(\.permission)).request(strategy: strategy)
        return PermissionOnboardingResult(plan: plan, groupResult: result)
    }
}
