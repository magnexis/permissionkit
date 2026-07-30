<p align="center"><img src="Assets/PermissionKit.svg" alt="PermissionKit" width="560" /></p>

<p align="center">
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&amp;logoColor=white" alt="Swift 6.0+" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-2563EB" alt="MIT License" /></a>
  <img src="https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS%20%7C%20visionOS-334155" alt="Apple platforms" />
  <img src="https://img.shields.io/badge/Dependencies-None-16A34A" alt="No runtime dependencies" />
</p>

<p align="center"><strong>One consistent, async-first API for Apple-platform permissions.</strong></p>

PermissionKit is a privacy-conscious, dependency-free Swift Package for checking, requesting, explaining, observing, and testing Apple platform permissions.

## Why PermissionKit?

- **One vocabulary:** normalize framework-specific authorization enums into `PermissionStatus`.
- **Async by default:** use structured results and concurrency-safe request coordination.
- **Honest capability handling:** distinguish denial from unavailable hardware and platform support.
- **Privacy first:** no private APIs, hidden analytics, remote service, or fabricated authorization.
- **Testable:** inject `PermissionProviding` or use `MockPermissionCenter` without a system prompt.

## Installation

Add the package in Xcode using **File → Add Package Dependencies**, or add it to `Package.swift`:

```swift
.package(url: "https://github.com/magnexis/permissionkit.git", from: "0.2.0")
```

Import `PermissionKitUI` only when using the optional SwiftUI components.

## Quick start

```swift
import PermissionKit

switch await Permission.camera.status() {
case .notDetermined:
    let result = await Permission.camera.request()
    if result.isGranted { /* Start camera work. */ }
case .authorized:
    // Start camera work.
default:
    break
}
```

## Batch requests

```swift
let result = await PermissionGroup([Permission.camera, Permission.microphone])
    .request(strategy: .requestOnlyUndetermined)
```

## Diagnostics

```swift
let report = PermissionDiagnostics.validate(permissions: [Permission.camera, Permission.microphone])
for issue in report.issues { print("[\(issue.severity)] \(issue.message)") }
```

The validator reads the host bundle but never changes `Info.plist` or privacy manifests.

## Observe changes

```swift
for await state in Permission.camera.updates {
    print("Camera is now \(state.status)")
}
```

Streams emit current state immediately, then emit after PermissionKit requests, refreshes, or observes application activation on supported Apple platforms.

## Request history

`PermissionCenter` keeps a bounded, in-memory history of authorization outcomes only—never user content, contacts, locations, or other sensitive data.

```swift
let history = await PermissionCenter.shared.requestHistory()
await PermissionCenter.shared.clearRequestHistory()
```

## Audits, onboarding, and simulations

Create a portable audit report for support diagnostics or local export. It includes only permission identifiers, statuses, metadata, and validation findings—never user content.

```swift
let audit = await PermissionAudit.generate(for: [
    Permission.camera,
    Permission.microphone,
    Permission.locationWhenInUse
])

let json = try audit.encodedJSON()
```

Build a dependency-aware onboarding sequence before you show native prompts:

```swift
let plan = await PermissionOnboarding.plan(for: [
    Permission.locationWhenInUse,
    Permission.locationAlways
])
```

For deterministic tests and previews, apply whole permission scenarios without touching Apple APIs:

```swift
let mock = MockPermissionCenter()
await mock.apply(.mixed([.camera: .authorized, .microphone: .denied]))
```

## SwiftUI

```swift
import PermissionKitUI

PermissionOnboardingFlow(permission: .camera) { explanation in
    VStack {
        Text(explanation.title).font(.title2)
        Text(explanation.message)
    }
}
```

## Supported surface

| Permission | Check | Request | Notes |
| --- | --- | --- | --- |
| Camera | Yes | Yes | Public AVFoundation API where available |
| Microphone | Yes | Yes | Public AVFoundation API where available |
| Photos | Yes | Yes | Read/write and add-only access levels |
| Contacts | Yes | Yes | Public Contacts API where available |
| Notifications | Yes | Yes | Alert, badge, and sound options |
| Location | Yes | Yes | When-in-use and always flows |
| Speech recognition | Yes | Yes | Public Speech framework where available |
| Tracking transparency | Yes | Yes | iOS only; never treated as required access |
| Media library | Yes | Yes | Public MediaPlayer framework where available |

Unsupported permissions return `.unsupported`; unavailable device conditions return `.unavailable`. Neither is treated as a grant.

## Testing

```swift
let mock = MockPermissionCenter()
await mock.script(permission: .camera, initial: .notDetermined, afterRequest: .authorized)
XCTAssertTrue((await mock.request(.camera)).isGranted)
```

## Status

PermissionKit is a pre-1.0 package. The core API, diagnostics, request coordination, dependency planner, onboarding and audit utilities, mock scenarios, observation surface, and optional SwiftUI controls are implemented. Full macOS/Xcode and device validation remains in progress; see [CHANGELOG.md](CHANGELOG.md).

## Privacy

PermissionKit never bypasses Apple permission systems, collects user data, performs analytics, or stores permission snapshots remotely. Permission denial is treated as a valid user decision.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md), follow the [Code of Conduct](CODE_OF_CONDUCT.md), and report security concerns through [SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
