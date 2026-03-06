// SwiftHook - SwiftHookTests.swift
// Created by Krishna

import XCTest
@testable import SwiftHook

// MARK: - Test fixtures

class Greeter: NSObject {
    @objc dynamic func greet() -> String { "Hello" }
    @objc dynamic func add(_ a: Int, to b: Int) -> Int { a + b }
    @objc dynamic func doNothing() {}
}

class SwiftHookTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SwiftHook.loggingEnabled = true
    }

    // MARK: - Class-level hooking

    func testClassPatchModifiesAllInstances() throws {
        let hook = try SwiftHook(Greeter.self) {
            try $0.hook(
                #selector(Greeter.greet),
                methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
                hookSignature: (@convention(block) (AnyObject) -> String).self
            ) { patch in { `self` in
                let orig = patch.original(`self`, patch.selector)
                return orig + " World"
            }}
        }

        XCTAssertEqual(Greeter().greet(), "Hello World")

        try hook.revertAll()
        XCTAssertEqual(Greeter().greet(), "Hello")
    }

    func testClassPatchWithIntReturn() throws {
        let hook = try SwiftHook(Greeter.self) {
            try $0.hook(
                #selector(Greeter.add(_:to:)),
                methodSignature: (@convention(c) (AnyObject, Selector, Int, Int) -> Int).self,
                hookSignature: (@convention(block) (AnyObject, Int, Int) -> Int).self
            ) { patch in { `self`, a, b in
                patch.original(`self`, patch.selector, a, b) * 10
            }}
        }

        XCTAssertEqual(Greeter().add(2, to: 3), 50)

        try hook.revertAll()
        XCTAssertEqual(Greeter().add(2, to: 3), 5)
    }

    func testClassPatchVoidMethod() throws {
        var callCount = 0
        let hook = try SwiftHook(Greeter.self) {
            try $0.hook(
                #selector(Greeter.doNothing),
                methodSignature: (@convention(c) (AnyObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (AnyObject) -> Void).self
            ) { patch in { `self` in
                callCount += 1
                patch.original(`self`, patch.selector)
            }}
        }

        Greeter().doNothing()
        XCTAssertEqual(callCount, 1)

        try hook.revertAll()
    }

    // MARK: - Instance-level hooking

    func testInstancePatchAffectsOnlyOneObject() throws {
        let objA = Greeter()
        let objB = Greeter()

        try objA.hook(
            #selector(Greeter.greet),
            methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
            hookSignature: (@convention(block) (AnyObject) -> String).self
        ) { patch in { `self` in
            return "Patched"
        }}

        XCTAssertEqual(objA.greet(), "Patched")
        XCTAssertEqual(objB.greet(), "Hello")
    }

    // MARK: - NSObject class-method convenience

    func testNSObjectClassHook() throws {
        let patch = try Greeter.hook(
            #selector(Greeter.greet),
            methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
            hookSignature: (@convention(block) (AnyObject) -> String).self
        ) { p in { `self` in
            return "Class Hook"
        }}

        XCTAssertEqual(Greeter().greet(), "Class Hook")
        try patch.deactivate()
        XCTAssertEqual(Greeter().greet(), "Hello")
    }

    // MARK: - Error cases

    func testBadSelectorThrows() {
        XCTAssertThrowsError(try SwiftHook(Greeter.self) {
            try $0.hook(
                "totallyFakeSelector",
                methodSignature: (@convention(c) (AnyObject, Selector) -> Void).self,
                hookSignature: (@convention(block) (AnyObject) -> Void).self
            ) { _ in { _ in } }
        })
    }

    // MARK: - String-based selector

    func testHookViaStringSelector() throws {
        let hook = try SwiftHook(Greeter.self) {
            try $0.hook(
                "greet",
                methodSignature: (@convention(c) (AnyObject, Selector) -> String).self,
                hookSignature: (@convention(block) (AnyObject) -> String).self
            ) { patch in { `self` in
                return "StringSel"
            }}
        }

        XCTAssertEqual(Greeter().greet(), "StringSel")
        try hook.revertAll()
    }
}
