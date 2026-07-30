import Foundation

public enum PermissionLoggingLevel: Sendable { case disabled, errors, requests, verbose }
public enum PermissionEvent: Sendable { case requestStarted(PermissionID), requestCompleted(PermissionResult), statusChanged(permission: PermissionID, old: PermissionStatus, new: PermissionStatus), settingsOpened(PermissionID?) }
/// Configuration contains no default analytics or network behavior. Event handling is opt-in.
@MainActor public enum PermissionKitConfiguration {
    private static var storedLogging: PermissionLoggingLevel = .errors
    private static var storedEventHandler: (@Sendable (PermissionEvent) -> Void)?
    public static var logging: PermissionLoggingLevel { get { storedLogging } set { storedLogging = newValue } }
    public static var eventHandler: (@Sendable (PermissionEvent) -> Void)? { get { storedEventHandler } set { storedEventHandler = newValue } }
    static func emit(_ event: PermissionEvent) { eventHandler?(event) }
}
