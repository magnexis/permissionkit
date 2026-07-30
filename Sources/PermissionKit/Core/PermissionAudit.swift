import Foundation

/// A portable, privacy-safe description of a permission configuration and its current state.
public struct PermissionAuditEntry: Codable, Sendable, Equatable {
    public let id: PermissionID
    public let displayName: String
    public let status: PermissionStatus
    public let isSupported: Bool
    public let requiredUsageDescriptionKeys: [String]
    public let requestMechanism: PermissionRequestMechanism
}

/// A report suitable for diagnostics attachment or local export. It contains no user content.
public struct PermissionAuditReport: Codable, Sendable {
    public let generatedAt: Date
    public let entries: [PermissionAuditEntry]
    public let diagnostics: PermissionDiagnosticReport
    public init(generatedAt: Date, entries: [PermissionAuditEntry], diagnostics: PermissionDiagnosticReport) { self.generatedAt = generatedAt; self.entries = entries; self.diagnostics = diagnostics }
    public func encodedJSON(prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(self)
    }
    public init(jsonData: Data) throws {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(Self.self, from: jsonData)
    }
}

public enum PermissionAudit {
    /// Produces an in-memory audit only. This method never writes to disk or sends data over the network.
    public static func generate(for permissions: [AnyPermission], bundle: Bundle = .main) async -> PermissionAuditReport {
        let unique = Dictionary(permissions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values.sorted { $0.id.rawValue < $1.id.rawValue }
        let entries = await withTaskGroup(of: PermissionAuditEntry.self, returning: [PermissionAuditEntry].self) { group in
            for permission in unique { group.addTask { PermissionAuditEntry(id: permission.id, displayName: permission.name, status: await permission.status(), isSupported: permission.isSupported, requiredUsageDescriptionKeys: permission.metadata.requiredUsageDescriptionKeys, requestMechanism: permission.metadata.requestMechanism) } }
            var values: [PermissionAuditEntry] = []; for await entry in group { values.append(entry) }; return values.sorted { $0.id.rawValue < $1.id.rawValue }
        }
        return PermissionAuditReport(generatedAt: .now, entries: entries, diagnostics: PermissionDiagnostics.validate(permissions: Array(unique), bundle: bundle))
    }
}
