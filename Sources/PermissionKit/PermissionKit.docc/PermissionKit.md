# ``PermissionKit``

PermissionKit provides a strongly typed, async-first API for Apple privacy permissions.

## Overview

Check a status before requesting access, then treat denial as a valid user decision.

```swift
let result = await Permission.camera.request()
if result.isGranted {
    // Begin camera work.
}
```

## Topics

### Essentials

- ``Permission``
- ``AnyPermission``
- ``PermissionStatus``
- ``PermissionGroup``
- ``PermissionDiagnostics``

### Testing

- ``MockPermissionCenter``
- ``PermissionProviding``
