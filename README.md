# SwiftHook

SwiftHook is a lightweight runtime method-hooking library for Swift on Apple platforms. It supports class-wide hooks, per-instance hooks, hook lifecycle management, and deferred hooks for classes loaded later.

## What it does

- Intercepts Objective-C-compatible `@objc dynamic` instance methods.
- Applies hooks before, after, or instead of the original implementation by composing replacement blocks.
- Supports class-level and per-object patching.
- Preserves access to the original implementation through typed function signatures.
- Provides explicit activate/deactivate and bulk apply/revert lifecycle operations.
- Includes runtime subclassing and super-forwarding support for instance hooks.
- Includes deferred class-load monitoring.

## Platform support

| Platform | Minimum |
| --- | --- |
| iOS | 11.0 |
| macOS | 10.13 |
| tvOS | 11.0 |
| watchOS | 5.0 |

SwiftHook depends on the Objective-C runtime, so the full hooking implementation is intended for Apple platforms. The repository includes limited compatibility shims for non-Apple documentation/build tooling.

## Requirements

- Swift 5.7+
- Xcode/Swift toolchain capable of the deployment targets above

## Installation

### Swift Package Manager

Add the repository as a package dependency in Xcode or `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/krishnashahane/swifthook.git", from: "1.0.0")
]
```

Then add `SwiftHook` as a target dependency.

### Build from a clone

```bash
git clone https://github.com/krishnashahane/swifthook.git
cd swifthook
swift build
swift test
```

## Basic example

Hooks require an Objective-C-compatible method, such as an `@objc dynamic` declaration:

```swift
import Foundation
import SwiftHook

final class Greeter: NSObject {
    @objc dynamic func greet() -> String {
        "Hello"
    }
}

let hook = try SwiftHook(Greeter.self)

try hook.hook(
    #selector(Greeter.greet),
    methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
    hookSignature: (@convention(block) (AnyObject) -> String).self
) { patch in
    { object in
        patch.original(object, patch.selector) + " World"
    }
}

print(Greeter().greet()) // Hello World

try hook.revertAll()
```

## Instance-level hooks

An instance hook changes only the selected object's runtime subclass:

```swift
let first = Greeter()
let second = Greeter()

let patch = try SwiftHook.InstancePatch<
    (@convention(c) (AnyObject, Selector) -> String),
    (@convention(block) (AnyObject) -> String)
>(
    object: first,
    selector: #selector(Greeter.greet)
) { _ in
    { _ in "Patched" }
}

try patch.activate()

print(first.greet())  // Patched
print(second.greet()) // Hello

try patch.deactivate()
```

## Lifecycle

Every patch has a lifecycle:

```text
idle -> active -> idle
        |
        v
      failed
```

Use `preparePatch` to create a patch without activating it, `activate()`/`deactivate()` for individual control, or `applyAll()`/`revertAll()` for bulk lifecycle management.

SwiftHook refuses to silently overwrite an implementation changed by another runtime. It reports an implementation mismatch instead.

## Deferred class hooks

To apply a hook when a class is loaded later:

```swift
try SwiftHook.onClassLoad("MyFramework.MyClass") { hook in
    try hook.hook(/* selector + signatures + builder */)
}
```

The class-load monitor runs on Apple platforms and retries the pending hook when dyld reports a newly loaded image.

## Important constraints

- Methods must be visible to the Objective-C runtime (`@objc dynamic` is the normal pattern).
- Hook signatures must exactly match the Objective-C method ABI. An incorrect signature can corrupt registers/stack state and crash the process.
- Runtime hooking is process-global for class hooks and intentionally invasive; use it only where you control the runtime environment.
- Per-object hooks modify an object's `isa` and may conflict with KVO or another runtime that already performs `isa`-swizzling.
- The super-forwarder uses architecture-specific Objective-C runtime trampolines and is supported on arm64 and x86_64 Apple targets.

## Security and reliability

SwiftHook does not require network access, credentials, or external services.

Runtime-sensitive failures are surfaced as `SwiftHookError` values rather than intentionally terminating the host process. Dynamic-loader lookup is checked before use, and unsupported/missing super-forwarding facilities fall back safely.

Diagnostic logging is disabled by default and contains implementation pointers/class names rather than application secrets.

## Development

Run formatting checks and the test suite locally:

```bash
swift-format format --in-place --recursive Sources SwiftHookTests
swift build
swift test
```

## License

MIT

## Author

Krishna Shahane

GitHub: https://github.com/krishnashahane
