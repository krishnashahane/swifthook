// SwiftHook - PatchRegistry.swift
// Created by Krishna

import Foundation

/// Manages weak back-references from IMP blocks to their owning patches,
/// enabling hook-chain traversal for correct revert ordering.
enum PatchRegistry {

    // MARK: - Associated object key

    private static var backRefKey: UInt8 = 0

    // MARK: - Weak wrapper

    private class WeakRef<T: AnyObject>: NSObject {
        private(set) weak var value: T?
        init(_ value: T) { self.value = value }
    }

    // MARK: - Store / Retrieve

    /// Attach a weak reference from `block` back to `patch`.
    static func attach<P: MethodPatch>(patch: P, to block: AnyObject) {
        objc_setAssociatedObject(
            block,
            &backRefKey,
            WeakRef(patch),
            .OBJC_ASSOCIATION_RETAIN
        )
    }

    /// Retrieve the patch that owns the given IMP.
    static func patch<P: MethodPatch>(for imp: IMP) -> P? {
        guard let block = imp_getBlock(imp) else { return nil }
        let ref = objc_getAssociatedObject(block, &backRefKey) as? WeakRef<P>
        return ref?.value
    }

    /// Walk the patch chain starting at `topmostIMP` and return the patch
    /// whose `savedIMP` points to `target`'s `installedIMP` (i.e. one level above).
    static func findUpstream<P: MethodPatch>(of target: P, startingFrom topmostIMP: IMP) -> P? {
        var currentIMP: IMP? = topmostIMP
        var previous: P?

        while let imp = currentIMP {
            let current: P? = patch(for: imp)
            if current === target {
                return previous
            }
            previous = current
            currentIMP = current?.savedIMP
        }
        return nil
    }
}
