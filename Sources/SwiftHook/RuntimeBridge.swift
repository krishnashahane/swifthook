// SwiftHook - RuntimeBridge.swift
// Created by Krishna

import Foundation

#if !os(Linux)
import Darwin
#endif

/// Creates and manages a dynamic subclass at runtime so that
/// per-object hooks do not affect the entire class hierarchy.
final class RuntimeBridge {

    private enum Constant {
        static let prefix = "SHK_"
    }

    private enum ObjCSel {
        static let classSelector = Selector((("class")))
    }

    private enum ObjCEncoding {
        static let classMethod: UnsafePointer<CChar> = {
            let s: StaticString = "#@:"
            return UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
        }()
    }

    /// The object whose isa we may change.
    let object: AnyObject

    /// The runtime subclass (either reused or freshly created).
    private(set) var runtimeSubclass: AnyClass

    // MARK: - Init

    init(for object: AnyObject) throws {
        self.object = object
        runtimeSubclass = type(of: object)
        runtimeSubclass = try reuseExisting() ?? buildNew()
    }

    // MARK: - Subclass creation

    private func buildNew() throws -> AnyClass {
        let perceivedClass: AnyClass = type(of: object)
        guard let realClass = object_getClass(object) else {
            throw SwiftHookError.internalFailure("Unable to resolve runtime class for target object")
        }

        let baseName = NSStringFromClass(perceivedClass)
        let tag = ProcessInfo.processInfo.globallyUniqueString
            .replacingOccurrences(of: "-", with: "")
        let subclassName = "\(Constant.prefix)\(baseName)_\(tag)"

        let allocated: AnyClass? = subclassName.withCString { cName in
            if let existing = objc_getClass(cName) {
                return existing as AnyClass
            }
            guard let pair = objc_allocateClassPair(realClass, cName, 0) else {
                return nil
            }
            // Override -class to return the perceived class (hide the subclass).
            spoofClassMethod(in: pair, returning: perceivedClass)
            objc_registerClassPair(pair)
            return pair
        }

        guard let result = allocated else {
            throw SwiftHookError.subclassAllocationFailed(
                ownerClass: perceivedClass, proposedName: subclassName)
        }

        guard object_setClass(object, result) != nil else {
            throw SwiftHookError.internalFailure("Unable to attach runtime subclass to target object")
        }

        guard let parentClass = class_getSuperclass(result) else {
            throw SwiftHookError.internalFailure("Runtime subclass has no superclass")
        }
        let parent = NSStringFromClass(parentClass)
        SwiftHook.log("Created \(NSStringFromClass(result)) (parent: \(parent))")
        return result
    }

    /// If the object already has one of our subclasses, reuse it.
    private func reuseExisting() -> AnyClass? {
        let actual: AnyClass = object_getClass(object)!
        if NSStringFromClass(actual).hasPrefix(Constant.prefix) {
            return actual
        }
        return nil
    }

    // MARK: - Class spoofing

    #if !os(Linux)
    private func spoofClassMethod(in klass: AnyClass, returning spoofed: AnyClass) {
        let block: @convention(block) (AnyObject) -> AnyClass = { _ in spoofed }
        let imp = imp_implementationWithBlock(block as Any)
        class_replaceMethod(klass, ObjCSel.classSelector, imp, ObjCEncoding.classMethod)
        class_replaceMethod(object_getClass(klass), ObjCSel.classSelector, imp, ObjCEncoding.classMethod)
    }
    #else
    private func spoofClassMethod(in klass: AnyClass, returning spoofed: AnyClass) {}
    #endif

    // MARK: - Super trampoline support

    #if !os(Linux)
    static var canBuildSuperTrampolines: Bool {
        NSClassFromString("SuperForwarder")?.value(forKey: "isArchitectureSupported") as? Bool ?? false
    }

    private lazy var addSuperIMP: (@convention(c) (AnyClass, Selector, NSErrorPointer) -> Bool)? = {
        guard let handle = dlopen(nil, RTLD_LAZY) else {
            return nil
        }
        guard let sym = dlsym(handle, "SHKInstallSuperForwarder") else {
            dlclose(handle)
            return nil
        }
        return unsafeBitCast(sym, to: (@convention(c) (AnyClass, Selector, NSErrorPointer) -> Bool).self)
    }()

    func installSuperTrampoline(for selector: Selector) -> Bool {
        guard let addSuperIMP else {
            SwiftHook.log("Super trampoline unavailable: SHKInstallSuperForwarder symbol not found")
            return false
        }

        var err: NSError?
        guard addSuperIMP(runtimeSubclass, selector, &err) else {
            SwiftHook.log("Super trampoline failed for -[\(runtimeSubclass).\(selector)]: \(err?.localizedDescription ?? "unknown error")")
            return false
        }

        guard let imp = class_getMethodImplementation(runtimeSubclass, selector) else {
            SwiftHook.log("Super trampoline installed but IMP lookup failed for -[\(runtimeSubclass).\(selector)]")
            return false
        }
        SwiftHook.log("Super trampoline installed for -[\(runtimeSubclass).\(selector)]: \(imp)")
        return true
    }
    #else
    static var canBuildSuperTrampolines: Bool { false }
    func installSuperTrampoline(for selector: Selector) -> Bool { false }
    #endif
}
