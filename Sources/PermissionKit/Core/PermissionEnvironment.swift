import Foundation

/// Dependency-injection container for permission-aware application code and SwiftUI views.
public struct PermissionEnvironment: Sendable {
    public let provider: any PermissionProviding
    public init(provider: any PermissionProviding = PermissionCenter.shared) { self.provider = provider }
    public static let live = PermissionEnvironment()
    public static func mock(_ configure: @Sendable (MockPermissionCenter) async -> Void = { _ in }) async -> PermissionEnvironment {
        let center = MockPermissionCenter(); await configure(center); return PermissionEnvironment(provider: center)
    }
}
