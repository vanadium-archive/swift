// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
import Syncbase

extension XCTestCase {
  func asyncDbTest(runBlock: Database throws -> Void) {
    do {
      let db = try Syncbase.database()
      try runBlock(db)
    } catch let e {
      XCTFail("Unexpected error: \(e)")
    }
  }
}
