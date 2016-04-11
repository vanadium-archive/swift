// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

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
