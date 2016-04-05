//
//  v23Tests.swift
//  v23Tests
//
//  Created by Aaron Zinman on 11/12/15.
//  Copyright © 2015 Google Inc. All rights reserved.
//

import XCTest
@testable import VanadiumCore

class VanadiumCoreTests: XCTestCase {
    func testInit() {
      // Currently this fails because of environmental flags passed by the Unit Test framework
      // that Vanadium ends up reading in and barfing on. Need to solve at some point.
      try! V23.configure()
      let instance = V23.instance
    }
}
