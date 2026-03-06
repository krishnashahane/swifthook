// SwiftHook - SwiftHook.swift
// Created by Krishna

import Foundation

// MARK: - NSObject convenience extensions

extension NSObject {

    /// Hook an `@objc dynamic` method on this object (instance) or class.
    @discardableResult
    public func hook<MethodSig, HookSig>(
        _ selector: Selector,
        methodSignature: MethodSig.Type = MethodSig.self,
        hookSignature: HookSig.Type = HookSig.self,
        _ builder: (SignedPatch<MethodSig, HookSig>) -> HookSig?
    ) throws -> MethodPatch {
        if let cls = self as? AnyClass {
            return try SwiftHook.ClassPatch(class: cls, selector: selector, builder: builder)
                .activate()
        } else {
            return try SwiftHook.InstancePatch(object: self, selector: selector, builder: builder)
                .activate()
        }
    }

    /// Hook an `@objc dynamic` method at the class level.
    @discardableResult
    public class func hook<MethodSig, HookSig>(
        _ selector: Selector,
        methodSignature: MethodSig.Type = MethodSig.self,
        hookSignature: HookSig.Type = HookSig.self,
        _ builder: (SignedPatch<MethodSig, HookSig>) -> HookSig?
    ) throws -> MethodPatch {
        try SwiftHook.ClassPatch(class: self as AnyClass, selector: selector, builder: builder)
            .activate()
    }
}

// MARK: - SwiftHook main class

/// SwiftHook is a modern Swift method hooking library.
///
/// Methods are patched by replacing the implementation directly,
/// instead of exchanging implementations. Supports both class-wide
/// and per-object hooks.
final public class SwiftHook {

    /// The class being hooked.
    public let targetClass: AnyClass

    /// All patches registered through this instance.
    public private(set) var patches: [MethodPatch] = []

    /// If this instance targets a single object, it is stored here.
    public let targetObject: AnyObject?

    // MARK: - Init (class-based)

    /// Create a `SwiftHook` for an entire class.
    /// If `patcher` is provided, patches are applied immediately.
    public init(
        _ targetClass: AnyClass,
        patcher: ((SwiftHook) throws -> Void)? = nil
    ) throws {
        self.targetClass = targetClass
        self.targetObject = nil
        if let patcher { try applyAll(patcher) }
    }

    // MARK: - Init (object-based)

    /// Create a `SwiftHook` for a single NSObject instance.
    public init(
        _ object: NSObject,
        patcher: ((SwiftHook) throws -> Void)? = nil
    ) throws {
        self.targetObject = object
        self.targetClass = type(of: object)

        // Detect isa-swizzling by KVO or other frameworks.
        let perceived: AnyClass = type(of: object)
        let actual: AnyClass = object_getClass(object)!
        if actual != perceived {
            if NSStringFromClass(actual).hasPrefix("NSKVO") {
                throw SwiftHookError.kvoConflict(object)
            } else {
                throw SwiftHookError.isaAlreadySwizzled(object, detectedClass: actual)
            }
        }

        if let patcher { try applyAll(patcher) }
    }

    deinit {
        patches.forEach { $0.teardown() }
    }

    // MARK: - Hook by selector name

    /// Hook a method by its string selector name.
    @discardableResult
    public func hook<MethodSig, HookSig>(
        _ selectorName: String,
        methodSignature: MethodSig.Type = MethodSig.self,
        hookSignature: HookSig.Type = HookSig.self,
        _ builder: (SignedPatch<MethodSig, HookSig>) -> HookSig?
    ) throws -> SignedPatch<MethodSig, HookSig> {
        try hook(NSSelectorFromString(selectorName),
                 methodSignature: methodSignature,
                 hookSignature: hookSignature, builder)
    }

    // MARK: - Hook by Selector

    /// Hook a method and immediately activate it.
    @discardableResult
    public func hook<MethodSig, HookSig>(
        _ selector: Selector,
        methodSignature: MethodSig.Type = MethodSig.self,
        hookSignature: HookSig.Type = HookSig.self,
        _ builder: (SignedPatch<MethodSig, HookSig>) -> HookSig?
    ) throws -> SignedPatch<MethodSig, HookSig> {
        let patch = try preparePatch(selector, methodSignature: methodSignature,
                                     hookSignature: hookSignature, builder)
        try patch.activate()
        return patch
    }

    // MARK: - Prepare without activating

    /// Create a patch without activating it yet.
    @discardableResult
    public func preparePatch<MethodSig, HookSig>(
        _ selector: Selector,
        methodSignature: MethodSig.Type = MethodSig.self,
        hookSignature: HookSig.Type = HookSig.self,
        _ builder: (SignedPatch<MethodSig, HookSig>) -> HookSig?
    ) throws -> SignedPatch<MethodSig, HookSig> {
        let patch: SignedPatch<MethodSig, HookSig>
        if let obj = targetObject {
            patch = try InstancePatch(object: obj, selector: selector, builder: builder)
        } else {
            patch = try ClassPatch(class: targetClass, selector: selector, builder: builder)
        }
        patches.append(patch)
        return patch
    }

    // MARK: - Bulk operations

    /// Apply all registered patches.
    @discardableResult
    public func applyAll(
        _ patcher: ((SwiftHook) throws -> Void)? = nil
    ) throws -> SwiftHook {
        try bulkExecute(patcher, requiredPhase: .idle) { try $0.activate() }
    }

    /// Revert all registered patches.
    @discardableResult
    public func revertAll(
        _ patcher: ((SwiftHook) throws -> Void)? = nil
    ) throws -> SwiftHook {
        try bulkExecute(patcher, requiredPhase: .active) { try $0.deactivate() }
    }

    private func bulkExecute(
        _ setup: ((SwiftHook) throws -> Void)?,
        requiredPhase: MethodPatch.Phase,
        action: (MethodPatch) throws -> Void
    ) throws -> SwiftHook {
        if let setup { try setup(self) }

        // Pre-validate all patches are in the required phase.
        let allValid = patches.allSatisfy {
            (try? $0.ensureMethodExists(expectedPhase: requiredPhase)) != nil
        }
        guard allValid else {
            throw SwiftHookError.lifecycleViolation(expected: requiredPhase)
        }

        try patches.forEach(action)
        return self
    }
}

// MARK: - Logging

extension SwiftHook {

    /// Toggle to enable diagnostic logging via `print`.
    public static var loggingEnabled = false

    class func log(_ message: Any) {
        if loggingEnabled {
            print("[SwiftHook] \(message)")
        }
    }
}
