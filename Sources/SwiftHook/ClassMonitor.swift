// SwiftHook - ClassMonitor.swift
// Created by Krishna

import Foundation

#if !os(Linux)
import MachO.dyld
#endif

// MARK: - Deferred hooking

extension SwiftHook {

    // Convenience: no completion
    @discardableResult
    public class func onClassLoad(
        _ parts: [String],
        patcher: @escaping (SwiftHook) throws -> Void
    ) throws -> PendingPatch {
        try onClassLoad(parts.joined(), patcher: patcher, completion: nil)
    }

    // Convenience: string array + completion
    @discardableResult
    public class func onClassLoad(
        _ parts: [String],
        patcher: @escaping (SwiftHook) throws -> Void,
        completion: (() -> Void)? = nil
    ) throws -> PendingPatch {
        try onClassLoad(parts.joined(), patcher: patcher, completion: completion)
    }

    // Convenience: string, no completion
    @discardableResult
    public class func onClassLoad(
        _ className: String,
        patcher: @escaping (SwiftHook) throws -> Void
    ) throws -> PendingPatch {
        try onClassLoad(className, patcher: patcher, completion: nil)
    }

    /// Register a deferred hook that fires as soon as `className` is loaded.
    @discardableResult
    public class func onClassLoad(
        _ className: String,
        patcher: @escaping (SwiftHook) throws -> Void,
        completion: (() -> Void)? = nil
    ) throws -> PendingPatch {
        try PendingPatch(className: className, patcher: patcher, completion: completion)
    }

    /// Represents a hook that is waiting for its target class to appear.
    public struct PendingPatch {
        fileprivate let className: String
        private let patcher: ((SwiftHook) throws -> Void)?
        private let completion: (() -> Void)?

        @discardableResult
        init(
            className: String,
            patcher: @escaping (SwiftHook) throws -> Void,
            completion: (() -> Void)?
        ) throws {
            self.className = className
            self.patcher = patcher
            self.completion = completion

            // Try immediately; if the class is already loaded, we're done.
            if try attemptExecution() == false {
                DylibObserver.enqueue(pending: self)
            }
        }

        func attemptExecution() throws -> Bool {
            guard let cls = NSClassFromString(className),
                  let patcher = self.patcher else { return false }
            try SwiftHook(cls).applyAll(patcher)
            completion?()
            return true
        }
    }
}

// MARK: - Dylib load observer (static, no class context for C callback)

private enum DylibObserver {

    private static let queue = DispatchQueue(label: "dev.krishna.swifthook.classmonitor")

    private static var pending: [SwiftHook.PendingPatch] = {
        // Defer registration to avoid deadlock with Swift global init.
        DispatchQueue.main.async { registerImageCallback() }
        return []
    }()

    static func enqueue(pending patch: SwiftHook.PendingPatch) {
        queue.sync { pending.append(patch) }
    }

    private static func registerImageCallback() {
        _dyld_register_func_for_add_image { _, _ in
            DylibObserver.queue.sync {
                DylibObserver.pending = DylibObserver.pending.filter { entry in
                    do {
                        if try entry.attemptExecution() {
                            SwiftHook.log("Deferred patch applied: \(entry.className)")
                            return false
                        }
                        return true // class not loaded yet, keep waiting
                    } catch {
                        SwiftHook.log("Deferred patch error: \(error)")
                        #if DEBUG
                        fatalError("SwiftHook deferred patch error: \(error)")
                        #endif
                        return false
                    }
                }
            }
        }
    }
}
