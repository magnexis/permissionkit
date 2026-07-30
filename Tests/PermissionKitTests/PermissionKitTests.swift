import XCTest
@testable import PermissionKit

final class PermissionKitTests: XCTestCase {
    func testMockTransitionAndResult() async { let mock = MockPermissionCenter(); await mock.script(permission: .camera, initial: .notDetermined, afterRequest: .authorized); let result = await mock.request(.camera); XCTAssertTrue(result.isGranted); XCTAssertTrue(result.didChange) }
    func testPermissionIDCodable() throws { let id: PermissionID = .camera; XCTAssertEqual(try JSONDecoder().decode(PermissionID.self, from: JSONEncoder().encode(id)), id) }
    func testGroupSkipsDeterminedPermissions() async { let mock = MockPermissionCenter(); await mock.set(.authorized, for: .camera); let permission = AnyPermission(id: .camera, name: "Camera", metadata: Permission.camera.metadata, state: { PermissionState(permission: .camera, status: await mock.status(for: .camera)) }, request: { await mock.request(.camera) }); let result = await PermissionGroup([permission]).request(strategy: .requestOnlyUndetermined); XCTAssertTrue(result.results.isEmpty) }
    func testPlannerPlacesLocationPrerequisiteFirst() async {
        let plan = await PermissionPlanner.plan(for: [Permission.locationAlways, Permission.locationWhenInUse])
        XCTAssertEqual(plan.orderedPermissions.prefix(2), [.locationWhenInUse, .locationAlways])
        XCTAssertTrue(plan.requiresUserEducation)
    }
    func testDeniedExplanationOffersSettings() {
        let explanation = Permission.camera.explanation(for: .denied)
        XCTAssertEqual(explanation.actionTitle, "Open Settings")
        XCTAssertTrue(explanation.message.contains("Settings"))
    }
    func testCoordinatorSharesOneRequest() async {
        let counter = Counter()
        let permission = AnyPermission(id: "test.concurrent", name: "Concurrent", metadata: PermissionMetadata(id: "test.concurrent", displayName: "Concurrent", shortDescription: "Test", supportedPlatforms: []), state: { PermissionState(permission: "test.concurrent", status: .notDetermined) }, request: { await counter.increment(); try? await Task.sleep(for: .milliseconds(10)); return PermissionResult(permission: "test.concurrent", previousStatus: .notDetermined, currentStatus: .authorized, didPresentSystemPrompt: true) })
        async let first = permission.request(); async let second = permission.request(); _ = await (first, second)
        let count = await counter.value
        XCTAssertEqual(count, 1)
    }
    func testDiagnosticsIdentifyLocationOrdering() {
        let report = PermissionDiagnostics.validate(permissions: [Permission.locationAlways])
        XCTAssertTrue(report.issues.contains { $0.code == "location_request_order" })
    }
    func testPrivacyManifestDoesNotInventReasonCodes() {
        let plan = PermissionPrivacyManifest.generate(for: [Permission.camera])
        XCTAssertEqual(plan.accessedAPICategories, [.camera])
        XCTAssertEqual(plan.permissionDeclarations.first?.usageDescriptionKeys, ["NSCameraUsageDescription"])
        XCTAssertFalse(plan.warnings.isEmpty)
    }
    func testExpandedPermissionMetadataHasRequiredUsageKeys() {
        XCTAssertEqual(Permission.speechRecognition.metadata.requiredUsageDescriptionKeys, ["NSSpeechRecognitionUsageDescription"])
        XCTAssertEqual(Permission.tracking.metadata.requiredUsageDescriptionKeys, ["NSUserTrackingUsageDescription"])
        XCTAssertEqual(Permission.mediaLibrary.metadata.requiredUsageDescriptionKeys, ["NSAppleMusicUsageDescription"])
    }
    func testRuntimeDiagnosticsReportCapability() async {
        let permission = AnyPermission(id: "test.hardware", name: "Hardware", metadata: PermissionMetadata(id: "test.hardware", displayName: "Hardware", shortDescription: "Test", supportedPlatforms: []), state: { PermissionState(permission: "test.hardware", status: .unavailable) }, request: { PermissionResult(permission: "test.hardware", previousStatus: .unavailable, currentStatus: .unavailable, didPresentSystemPrompt: false) }, capability: { .missingHardware })
        let report = await PermissionDiagnostics.validateRuntime(permissions: [permission])
        XCTAssertTrue(report.issues.contains { $0.code == "missing_hardware" })
    }
    func testStatusSequenceEmitsInitialAndChangedState() async {
        let center = PermissionCenter()
        let state = MutableStatus()
        let permission = AnyPermission(id: "test.observation", name: "Observation", metadata: PermissionMetadata(id: "test.observation", displayName: "Observation", shortDescription: "Test", supportedPlatforms: []), state: { PermissionState(permission: "test.observation", status: await state.current()) }, request: { await state.set(.authorized); return PermissionResult(permission: "test.observation", previousStatus: .notDetermined, currentStatus: .authorized, didPresentSystemPrompt: true) })
        var iterator = PermissionStatusSequence(permission: permission, center: center).makeAsyncIterator()
        let initial = await iterator.next()
        XCTAssertEqual(initial?.status, .notDetermined)
        _ = await center.request(permission.id)
        let changed = await iterator.next()
        XCTAssertEqual(changed?.status, .authorized)
    }
    func testAuditIsCodableAndDeduplicatesPermissions() async throws {
        let report = await PermissionAudit.generate(for: [Permission.camera, Permission.camera])
        XCTAssertEqual(report.entries.count, 1)
        let data = try report.encodedJSON()
        XCTAssertEqual(try PermissionAuditReport(jsonData: data).entries.count, 1)
    }
    func testOnboardingIncludesDependencyOrder() async {
        let plan = await PermissionOnboarding.plan(for: [Permission.locationAlways, Permission.locationWhenInUse])
        XCTAssertEqual(plan.steps.map(\.permission.id), [.locationWhenInUse, .locationAlways])
    }
    func testMockScenarioSetsMultiplePermissions() async {
        let mock = MockPermissionCenter()
        await mock.apply(.mixed([.camera: .authorized, .microphone: .denied]))
        let camera = await mock.status(for: .camera)
        let microphone = await mock.status(for: .microphone)
        XCTAssertEqual(camera, .authorized)
        XCTAssertEqual(microphone, .denied)
    }
    func testGroupOrdersLocationPrerequisiteBeforeAlways() async {
        let recorder = OrderRecorder()
        let whenInUse = testPermission(id: .locationWhenInUse, recorder: recorder)
        let always = testPermission(id: .locationAlways, recorder: recorder)
        _ = await PermissionGroup([always, whenInUse]).request()
        let order = await recorder.snapshot()
        XCTAssertEqual(order, [.locationWhenInUse, .locationAlways])
    }
    func testCenterStoresOnlyNonSensitiveRequestHistory() async {
        let center = PermissionCenter()
        let permission = AnyPermission(id: "test.history", name: "History", metadata: PermissionMetadata(id: "test.history", displayName: "History", shortDescription: "Test", supportedPlatforms: []), state: { PermissionState(permission: "test.history", status: .notDetermined) }, request: { PermissionResult(permission: "test.history", previousStatus: .notDetermined, currentStatus: .authorized, didPresentSystemPrompt: true) })
        await center.register(permission)
        _ = await center.request("test.history")
        let history = await center.requestHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.permission, "test.history")
        XCTAssertEqual(history.first?.currentStatus, .authorized)
    }

    private func testPermission(id: PermissionID, recorder: OrderRecorder) -> AnyPermission {
        AnyPermission(id: id, name: id.rawValue, metadata: PermissionMetadata(id: id, displayName: id.rawValue, shortDescription: "Test", supportedPlatforms: []), state: { PermissionState(permission: id, status: .notDetermined) }, request: { await recorder.append(id); return PermissionResult(permission: id, previousStatus: .notDetermined, currentStatus: .authorized, didPresentSystemPrompt: true) })
    }
}

private actor Counter { private var count = 0; func increment() { count += 1 }; var value: Int { count } }
private actor OrderRecorder { private var values: [PermissionID] = []; func append(_ value: PermissionID) { values.append(value) }; func snapshot() -> [PermissionID] { values } }
private actor MutableStatus { private var status: PermissionStatus = .notDetermined; func current() -> PermissionStatus { status }; func set(_ value: PermissionStatus) { status = value } }
