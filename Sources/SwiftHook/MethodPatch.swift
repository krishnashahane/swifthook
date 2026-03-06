// SwiftHook - MethodPatch.swift
// Created by Krishna

import Foundation

/// Abstract base representing a single method patch.
/// Concrete work is done by `ClassPatch` and `InstancePatch`.
public class MethodPatch {

    /// The target class that owns the method.
    public let targetClass: AnyClass

    /// The Objective-C selector being patched.
    public let selector: Selector

    /// Current lifecycle phase of this patch.
    public internal(set) var phase: Phase = .idle

    /// The replacement IMP we installed (set by subclasses before `activate`).
    var installedIMP: IMP!

    /// The original IMP that was in place before we patched (populated at activation time).
    var savedIMP: IMP?

    /// Lifecycle phases a patch moves through.
    public enum Phase: Equatable {
        /// Created but not yet applied.
        case idle
        /// Successfully patched into the runtime.
        case active
        /// Something went wrong.
        indirect case failed(SwiftHookError)
    }

    // MARK: - Initialisation

    init(targetClass: AnyClass, selector: Selector) throws {
        self.targetClass = targetClass
        self.selector = selector
        // Eagerly verify the selector resolves
        try ensureMethodExists()
    }

    // MARK: - Template methods (overridden by subclasses)

    func performActivation() throws {
        preconditionFailure("Subclass must override performActivation")
    }

    func performDeactivation() throws {
        preconditionFailure("Subclass must override performDeactivation")
    }

    // MARK: - Public API

    /// Activate (apply) this patch.
    @discardableResult
    public func activate() throws -> MethodPatch {
        try transition(to: .active) { try performActivation() }
        return self
    }

    /// Deactivate (revert) this patch.
    @discardableResult
    public func deactivate() throws -> MethodPatch {
        try transition(to: .idle) { try performDeactivation() }
        return self
    }

    /// Verify the selector exists and that we are in the expected phase.
    @discardableResult
    func ensureMethodExists(expectedPhase: Phase = .idle) throws -> Method {
        guard let method = class_getInstanceMethod(targetClass, selector) else {
            throw SwiftHookError.selectorNotFound(targetClass, selector)
        }
        guard phase == expectedPhase else {
            throw SwiftHookError.lifecycleViolation(expected: expectedPhase)
        }
        return method
    }

    /// Release the block-backed IMP when possible.
    public func teardown() {
        switch phase {
        case .idle:
            SwiftHook.log("Releasing -[\(targetClass).\(selector)] IMP: \(installedIMP!)")
            imp_removeBlock(installedIMP)
        case .active:
            SwiftHook.log("Keeping -[\(targetClass).\(selector)] IMP: \(installedIMP!)")
        case let .failed(err):
            SwiftHook.log("Leaking -[\(targetClass).\(selector)] IMP: \(installedIMP!) error: \(err)")
        }
    }

    // MARK: - Private

    private func transition(to target: Phase, work: () throws -> Void) throws {
        do {
            try work()
            phase = target
        } catch let error as SwiftHookError {
            phase = .failed(error)
            throw error
        }
    }
}

// MARK: - SignedPatch

/// Adds generic method/hook signature information on top of `MethodPatch`.
public class SignedPatch<MethodSig, HookSig>: MethodPatch {

    /// Access the original implementation. Subclasses must provide this.
    public var original: MethodSig {
        preconditionFailure("Subclass must provide original")
    }
}
