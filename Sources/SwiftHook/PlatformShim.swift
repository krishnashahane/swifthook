// SwiftHook - PlatformShim.swift
// Created by Krishna
//
// Stub declarations so the library compiles on Linux (for documentation generation).

import Foundation

#if os(Linux)

public struct Selector: Equatable {
    var name: String?
    init(_ name: String) { self.name = name }
}

public struct IMP: Equatable {}
public struct Method {}

func NSSelectorFromString(_ name: String) -> Selector { Selector("") }
func class_getInstanceMethod(_ cls: AnyClass?, _ sel: Selector) -> Method? { nil }
func class_getMethodImplementation(_ cls: AnyClass?, _ sel: Selector) -> IMP? { nil }
func class_replaceMethod(_ cls: AnyClass?, _ sel: Selector,
                         _ imp: IMP, _ enc: UnsafePointer<Int8>?) -> IMP? { IMP() }
func class_addMethod(_ cls: AnyClass?, _ sel: Selector,
                     _ imp: IMP, _ enc: UnsafePointer<Int8>?) -> Bool { false }
func class_copyMethodList(_ cls: AnyClass?,
                          _ count: UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<Method>? { nil }
func object_getClass(_ obj: Any?) -> AnyClass? { nil }
@discardableResult func object_setClass(_ obj: Any?, _ cls: AnyClass) -> AnyClass? { nil }
func method_getName(_ m: Method) -> Selector { Selector("") }
func class_getSuperclass(_ cls: AnyClass?) -> AnyClass? { nil }
func method_getTypeEncoding(_ m: Method) -> UnsafePointer<Int8>? { nil }
func method_getImplementation(_ m: Method) -> IMP { IMP() }
func _dyld_register_func_for_add_image(
    _ callback: (@convention(c) (UnsafePointer<Int8>?, Int) -> Void)!) {}
func objc_allocateClassPair(_ sup: AnyClass?, _ name: UnsafePointer<Int8>,
                            _ extra: Int) -> AnyClass? { nil }
func objc_registerClassPair(_ cls: AnyClass) {}
func objc_getClass(_ name: UnsafePointer<Int8>!) -> Any! { nil }
func imp_implementationWithBlock(_ block: Any) -> IMP { IMP() }
func imp_getBlock(_ imp: IMP) -> Any? { nil }
@discardableResult func imp_removeBlock(_ imp: IMP) -> Bool { false }

@objc class NSError: NSObject {}
typealias NSErrorPointer = UnsafeMutablePointer<NSError?>?

extension NSObject {
    open func value(forKey key: String) -> Any? { nil }
}

enum objc_AssociationPolicy: UInt {
    case OBJC_ASSOCIATION_ASSIGN = 0
    case OBJC_ASSOCIATION_RETAIN_NONATOMIC = 1
    case OBJC_ASSOCIATION_COPY_NONATOMIC = 3
    case OBJC_ASSOCIATION_RETAIN = 769
    case OBJC_ASSOCIATION_COPY = 771
}

func objc_setAssociatedObject(_ obj: Any, _ key: UnsafeRawPointer,
                              _ val: Any?, _ policy: objc_AssociationPolicy) {}
func objc_getAssociatedObject(_ obj: Any,
                              _ key: UnsafeRawPointer) -> Any? { nil }
#endif
