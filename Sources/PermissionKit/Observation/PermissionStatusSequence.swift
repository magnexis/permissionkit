import Foundation

/// An async sequence of state changes for one permission.
public struct PermissionStatusSequence: AsyncSequence, Sendable {
    public typealias Element = PermissionState
    private let stream: AsyncStream<PermissionState>
    init(permission: AnyPermission, center: PermissionCenter = .shared) {
        stream = AsyncStream { continuation in
            Task {
                let changes = await center.updatesSequence()
                await center.register(permission)
                continuation.yield(await center.state(for: permission.id))
                for await change in changes where change.permission == permission.id { continuation.yield(change.state) }
                continuation.finish()
            }
        }
    }
    public func makeAsyncIterator() -> AsyncStream<PermissionState>.Iterator { stream.makeAsyncIterator() }
}

public extension AnyPermission { var updates: PermissionStatusSequence { PermissionStatusSequence(permission: self) } }
