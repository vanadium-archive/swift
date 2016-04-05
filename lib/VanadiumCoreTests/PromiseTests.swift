//
//  PromiseTests.swift
//  v23
//
//  Created by Aaron Zinman on 11/30/15.
//  Copyright © 2015 Google Inc. All rights reserved.
//

import XCTest
import VanadiumCore

enum TestErrors : ErrorType {
  case SomeError
  case SomeOtherError
}

class PromiseTests: XCTestCase {
  func testBasicResolution() {
    var alwaysRan = false
    let p = Promise<Int>()
      .onResolve { obj in XCTAssertEqual(obj, 5) }
      .onReject { err in XCTFail("Shouldn't have gotten \(err)") }
      .always { status in
        switch (status) {
        case .Pending: XCTFail("Can't get pending in always")
        case .Rejected(let e): XCTFail("Shouldn't have gotten \(e)")
        case .Resolved: alwaysRan = true
        }
      }
    try! p.resolve(5)
    XCTAssertTrue(alwaysRan)
    
    var ranNow = false
    p.onResolve { obj in
      ranNow = true
    }
    XCTAssertTrue(ranNow)
  }

  func testBasicRejection() {
    var alwaysRan = false
    let p = Promise<Int>()
      .onResolve { obj in XCTFail("Shouldn't have gotten \(obj)") }
      .onReject { err in
        guard let e = err else { XCTFail("Invalid nil error"); return }
        switch(e) {
        case TestErrors.SomeError: break
        default: XCTFail("Shouldn't have gotten this error \(e)")
        }
      }
      .always { status in
        switch (status) {
        case .Pending: XCTFail("Can't get pending in always")
        case .Rejected: alwaysRan = true
        case .Resolved(let o): XCTFail("Shouldn't have gotten \(o)")
        }
      }
    try! p.reject(TestErrors.SomeError)
    XCTAssertTrue(alwaysRan)

    var ranNow = false
    p.onReject { err in
      ranNow = true
    }
    XCTAssertTrue(ranNow)
  }

  func testResolutionDoesntRunOnResolve() {
    let p = Promise<Int>()
    p.onResolve { obj in
      XCTFail("Shouldn't have gotten \(obj)")
    }
    try! p.reject(TestErrors.SomeError)
  }
  
  func testRejectionDoesntRunOnResolve() {
    let p = Promise<Int>()
    p.onReject { err in
      XCTFail("Shouldn't have gotten \(err)")
    }
    try! p.resolve(5)
  }
  
  func testThenTransforms() {
    let p = Promise<Int>()
    try! p.resolve(5)
    
    var finalResult:String = ""
    p.then { obj -> String in
      XCTAssertEqual(obj, 5)
      return "hello"
    }.onResolve { obj in
      XCTAssertEqual(obj, "hello")
      finalResult = obj
    }
    XCTAssertEqual(finalResult, "hello")
  }

  func testThenPropagatesError() {
    let p = Promise<Int>()
    
    var didReject = false
    p.then { obj -> String in
      XCTAssertEqual(obj, 5)
      return "hello"
    }.onReject { _ in
      didReject = true
    }
    try! p.reject(TestErrors.SomeError)
    XCTAssertTrue(didReject)
  }
  
  func testThenReturningPromiseWorks() {
    let p = Promise<Int>()
    let bgQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
    let finalP = p.then(on: bgQueue) { x -> Promise<Int> in
      let newP = Promise<Int>()
      dispatch_async(bgQueue) {
        try! newP.resolve(x + 10)
      }
      return newP
    }
    
    try! p.resolve(5)
    let finalStatus = try! finalP.await()
    switch (finalStatus) {
    case .Resolved(let v): XCTAssertEqual(v, 15)
    default: XCTFail("Supposed to be resolved")
    }
  }
}
