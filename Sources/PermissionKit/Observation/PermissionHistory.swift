import Foundation

/// A privacy-safe record of a request. It contains authorization state only.
public struct PermissionRequestRecord: Codable, Sendable, Equatable {
    public let permission: PermissionID
    public let previousStatus: PermissionStatus
    public let currentStatus: PermissionStatus
    public let requestedAt: Date
    public let didPresentSystemPrompt: Bool
    public init(result: PermissionResult) {
        permission = result.permission; previousStatus = result.previousStatus; currentStatus = result.currentStatus
        requestedAt = result.requestDate; didPresentSystemPrompt = result.didPresentSystemPrompt
    }
}

public actor PermissionRequestHistory {
    private var records: [PermissionRequestRecord] = []
    private let capacity: Int
    public init(capacity: Int = 100) { self.capacity = max(1, capacity) }
    public func append(_ result: PermissionResult) {
        records.append(PermissionRequestRecord(result: result))
        if records.count > capacity { records.removeFirst(records.count - capacity) }
    }
    public func snapshot() -> [PermissionRequestRecord] { records }
    public func removeAll() { records.removeAll(keepingCapacity: false) }
}
