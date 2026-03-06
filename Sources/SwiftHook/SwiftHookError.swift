// SwiftHook - SwiftHookError.swift
// Created by Krishna

import Foundation

/// All possible failures during the hooking lifecycle.
public enum SwiftHookError: LocalizedError {

    /// No Objective-C method matching the selector was found on the target class.
    case selectorNotFound(AnyClass, Selector)

    /// The method exists in metadata but carries no concrete implementation pointer.
    case missingImplementation(AnyClass, Selector)

    /// On revert the current IMP no longer matches the one we installed - another party swizzled after us.
    case implementationMismatch(AnyClass, Selector, IMP?)

    /// Runtime refused to allocate a new class pair for per-object hooking.
    case subclassAllocationFailed(ownerClass: AnyClass, proposedName: String)

    /// `class_addMethod` returned false for the dynamic subclass.
    case methodInjectionFailed(AnyClass, Selector)

    /// The target object already has a KVO-generated isa-swizzled subclass.
    case kvoConflict(AnyObject)

    /// Another runtime (e.g. Aspects) already swapped the isa to a foreign subclass.
    case isaAlreadySwizzled(AnyObject, detectedClass: AnyClass)

    /// The patch is not in the expected lifecycle phase.
    case lifecycleViolation(expected: MethodPatch.Phase)

    /// Revert is not possible without the super-forwarder helper.
    case revertNotSupported(detail: String)

    /// Catch-all for truly unexpected situations.
    case internalFailure(String)
}

// MARK: - Human-readable descriptions

extension SwiftHookError {

    public var errorDescription: String? {
        switch self {
        case .selectorNotFound(let cls, let sel):
            return "No method -[\(cls) \(sel)] exists"
        case .missingImplementation(let cls, let sel):
            return "Missing IMP for -[\(cls) \(sel)]"
        case .implementationMismatch(let cls, let sel, let imp):
            return "IMP mismatch on -[\(cls) \(sel)]: found \(String(describing: imp))"
        case .subclassAllocationFailed(let cls, let name):
            return "Cannot allocate subclass \(name) of \(cls)"
        case .methodInjectionFailed(let cls, let sel):
            return "class_addMethod failed for -[\(cls) \(sel)]"
        case .kvoConflict(let obj):
            return "Object uses KVO, hooking blocked: \(obj)"
        case .isaAlreadySwizzled(let obj, let actual):
            return "isa of \(type(of: obj)) already swizzled to \(NSStringFromClass(actual))"
        case .lifecycleViolation(let expected):
            return "Patch lifecycle violation, expected phase: \(expected)"
        case .revertNotSupported(let detail):
            return "Revert unsupported: \(detail)"
        case .internalFailure(let reason):
            return reason
        }
    }
}

// MARK: - Equatable via description (lightweight)

extension SwiftHookError: Equatable {
    public static func == (lhs: SwiftHookError, rhs: SwiftHookError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}

// MARK: - Internal logging helper

extension SwiftHookError {
    @discardableResult
    func emit() -> SwiftHookError {
        SwiftHook.log(errorDescription ?? "unknown error")
        return self
    }
}
