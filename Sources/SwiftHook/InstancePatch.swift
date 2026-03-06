// SwiftHook - InstancePatch.swift
// Created by Krishna

import Foundation

extension SwiftHook {

    /// Patches a method on a single object by creating a runtime subclass.
    final public class InstancePatch<MethodSig, HookSig>: SignedPatch<MethodSig, HookSig> {

        /// The individual object being patched.
        public let target: AnyObject

        /// Manages the runtime subclass lifecycle.
        var bridge: RuntimeBridge?

        /// Whether the SuperForwarder trampoline is available.
        let hasSuperForwarder = RuntimeBridge.canBuildSuperTrampolines

        /// Create an instance-level patch.
        public init(
            object: AnyObject,
            selector: Selector,
            builder: (InstancePatch<MethodSig, HookSig>) -> HookSig?
        ) throws {
            self.target = object
            try super.init(targetClass: type(of: object), selector: selector)

            let block = builder(self) as AnyObject
            installedIMP = imp_implementationWithBlock(block)
            guard installedIMP != nil else {
                throw SwiftHookError.internalFailure(
                    "imp_implementationWithBlock returned nil for \(block)")
            }
            // Attach a weak back-reference from the block to this patch.
            PatchRegistry.attach(patch: self, to: block)
        }

        // MARK: - Original accessor

        /// Returns the original IMP. If we stored one at activation, use it;
        /// otherwise walk the class hierarchy to find it dynamically.
        public override var original: MethodSig {
            if let stored = savedIMP {
                return unsafeBitCast(stored, to: MethodSig.self)
            }
            guard let resolved = resolveOriginalIMP else {
                SwiftHookError.missingImplementation(targetClass, selector).emit()
                preconditionFailure("Cannot resolve original IMP for -[\(targetClass).\(selector)]")
            }
            return resolved
        }

        /// Walk the superclass chain to find the nearest implementation.
        private var resolveOriginalIMP: MethodSig? {
            var cursor: AnyClass? = targetClass
            while let current = cursor {
                if let method = class_getInstanceMethod(current, selector) {
                    let imp = method_getImplementation(method)
                    return unsafeBitCast(imp, to: MethodSig.self)
                }
                cursor = class_getSuperclass(current)
            }
            return nil
        }

        /// Check whether `klass` itself (not superclasses) declares `sel`.
        private func classDirectlyDeclaresSelector(_ klass: AnyClass, _ sel: Selector) -> Bool {
            var count: UInt32 = 0
            guard let methods = class_copyMethodList(klass, &count) else { return false }
            defer { free(methods) }
            for i in 0..<Int(count) {
                if method_getName(methods[i]) == sel { return true }
            }
            return false
        }

        /// The runtime subclass we operate on.
        private var runtimeClass: AnyClass {
            bridge!.runtimeSubclass
        }

        // MARK: - Activation

        override func performActivation() throws {
            let method = try ensureMethodExists()

            // Obtain or create the dynamic subclass for this object.
            bridge = try RuntimeBridge(for: target)

            // Verify the original is reachable.
            guard resolveOriginalIMP != nil else {
                throw SwiftHookError.missingImplementation(targetClass, selector).emit()
            }

            let alreadyOverridden = classDirectlyDeclaresSelector(runtimeClass, selector)
            let encoding = method_getTypeEncoding(method)

            if hasSuperForwarder {
                // Install a super-trampoline first if the subclass doesn't override yet.
                if !alreadyOverridden {
                    bridge!.installSuperTrampoline(for: selector)
                }
                // Now replace — the trampoline guarantees an existing method entry.
                savedIMP = class_replaceMethod(runtimeClass, selector, installedIMP, encoding)
                guard savedIMP != nil else {
                    throw SwiftHookError.missingImplementation(runtimeClass, selector)
                }
                SwiftHook.log("Patched -[\(targetClass).\(selector)] \(savedIMP!) -> \(installedIMP!)")
            } else {
                if alreadyOverridden {
                    savedIMP = class_replaceMethod(runtimeClass, selector, installedIMP, encoding)
                    guard savedIMP != nil else {
                        throw SwiftHookError.methodInjectionFailed(targetClass, selector)
                    }
                    SwiftHook.log("Replaced -[\(targetClass).\(selector)] IMP: \(installedIMP!)")
                } else {
                    let added = class_addMethod(runtimeClass, selector, installedIMP, encoding)
                    guard added else {
                        throw SwiftHookError.methodInjectionFailed(targetClass, selector)
                    }
                    SwiftHook.log("Injected -[\(targetClass).\(selector)] IMP: \(installedIMP!)")
                }
            }
        }

        // MARK: - Deactivation

        override func performDeactivation() throws {
            let method = try ensureMethodExists(expectedPhase: .active)

            guard savedIMP != nil else {
                SwiftHook.log("Cannot revert -[\(targetClass).\(selector)]: no saved IMP")
                throw SwiftHookError.revertNotSupported(
                    detail: "No saved IMP. SuperForwarder may be missing.")
            }

            guard let liveIMP = class_getMethodImplementation(runtimeClass, selector) else {
                throw SwiftHookError.internalFailure("No live IMP found")
            }

            if liveIMP == installedIMP {
                // We are still the topmost patch — simple replacement.
                let encoding = method_getTypeEncoding(method)
                let removed = class_replaceMethod(runtimeClass, selector, savedIMP!, encoding)
                guard removed == installedIMP else {
                    throw SwiftHookError.implementationMismatch(runtimeClass, selector, removed)
                }
                SwiftHook.log("Restored -[\(targetClass).\(selector)] IMP: \(savedIMP!)")
            } else {
                // Another patch was layered on top — fix the chain.
                let upstream = PatchRegistry.findUpstream(
                    of: self, startingFrom: liveIMP)
                upstream?.savedIMP = self.savedIMP
            }
        }
    }
}

#if DEBUG
extension SwiftHook.InstancePatch: CustomDebugStringConvertible {
    public var debugDescription: String {
        "\(selector) on \(target) -> \(String(describing: original))"
    }
}
#endif
