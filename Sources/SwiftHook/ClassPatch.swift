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
            guard let block = builder(self) else {
                throw SwiftHookError.internalFailure("Hook builder returned nil")
            }
            installedIMP = imp_implementationWithBlock(block)
        }

        // MARK: - Activation

        override func performActivation() throws {
            let method = try ensureMethodExists()
            let encoding = method_getTypeEncoding(method)
            let inheritedIMP = method_getImplementation(method)

            if classDeclaresSelector(targetClass, selector) {
                savedIMP = class_replaceMethod(targetClass, selector, installedIMP, encoding)
            } else {
                savedIMP = inheritedIMP
                guard class_addMethod(targetClass, selector, installedIMP, encoding) else {
                    throw SwiftHookError.methodInjectionFailed(targetClass, selector)
                }
            }

            guard savedIMP != nil else {
                throw SwiftHookError.missingImplementation(targetClass, selector)
            }
            SwiftHook.log("Patched -[\(targetClass).\(selector)] \(savedIMP!) -> \(installedIMP!)")
        }

        private func classDeclaresSelector(_ klass: AnyClass, _ sel: Selector) -> Bool {
            var count: UInt32 = 0
            guard let methods = class_copyMethodList(klass, &count) else { return false }
            defer { free(methods) }
            for index in 0..<Int(count) {
                if method_getName(methods[index]) == sel { return true }
            }
            return false
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
