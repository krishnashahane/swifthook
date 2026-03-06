// SwiftHook - ClassPatch.swift
// Created by Krishna

import Foundation

extension SwiftHook {

    /// Patches a method at the class level - every instance is affected.
    final public class ClassPatch<MethodSig, HookSig>: SignedPatch<MethodSig, HookSig> {

        /// Create a class-level patch. The `builder` closure receives this patch
        /// so it can access `original` inside the replacement block.
        public init(
            `class`: AnyClass,
            selector: Selector,
            builder: (ClassPatch<MethodSig, HookSig>) -> HookSig?
        ) throws {
            try super.init(targetClass: `class`, selector: selector)
            let block = builder(self) as Any
            installedIMP = imp_implementationWithBlock(block)
        }

        // MARK: - Activation

        override func performActivation() throws {
            let method = try ensureMethodExists()
            let encoding = method_getTypeEncoding(method)
            savedIMP = class_replaceMethod(targetClass, selector, installedIMP, encoding)
            guard savedIMP != nil else {
                throw SwiftHookError.missingImplementation(targetClass, selector)
            }
            SwiftHook.log("Patched -[\(targetClass).\(selector)] \(savedIMP!) -> \(installedIMP!)")
        }

        // MARK: - Deactivation

        override func performDeactivation() throws {
            let method = try ensureMethodExists(expectedPhase: .active)
            precondition(savedIMP != nil)
            let encoding = method_getTypeEncoding(method)
            let removedIMP = class_replaceMethod(targetClass, selector, savedIMP!, encoding)
            guard removedIMP == installedIMP else {
                throw SwiftHookError.implementationMismatch(targetClass, selector, removedIMP)
            }
            SwiftHook.log("Restored -[\(targetClass).\(selector)] IMP: \(savedIMP!)")
        }

        // MARK: - Original accessor

        /// Returns the original IMP cast to the caller-specified method signature.
        /// Captured at activation time.
        public override var original: MethodSig {
            unsafeBitCast(savedIMP, to: MethodSig.self)
        }
    }
}

#if DEBUG
extension SwiftHook.ClassPatch: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(selector) -> \(String(describing: savedIMP))"
    }
}
#endif
