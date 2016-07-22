// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
@testable import SyncbaseCore
import XCTest

class IdentifierTest: XCTestCase {
  func testEncodeDecodeEquality() {
    do {
      for id in [
        Identifier(name: "cx_0EA0EA98AA9B4636AA058EA88C25DB2A", blessing: "root:o:app:user"),
        Identifier(name: "_%/-,,hi", blessing: "root:o:app:user"),
        Identifier(name: "", blessing: "root:o:app:user"),
        Identifier(name: "something", blessing: "")] {
          let mirror = try Identifier.decode(try id.encode().extract()!)
          XCTAssertEqual(id, mirror)
      }
    } catch {
      XCTFail("Unexpected error: \(error)")
    }
  }
}