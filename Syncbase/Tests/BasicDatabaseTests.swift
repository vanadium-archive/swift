// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import Syncbase
import SyncbaseCore

class BasicDatabaseTests: XCTestCase {
  override class func setUp() {
    try! Syncbase.configure(adminUserId: "unittest@google.com")
  }

  override class func tearDown() {
    SyncbaseCore.Syncbase.shutdown()
  }

  func testDatabaseInit() {
    asyncDbTest() { db in
      // Must be idempotent.
      try db.createIfMissing()
      try db.createIfMissing()
    }
  }

  func testCollection() {
    asyncDbTest() { db in
      var collections = try db.collections()
      XCTAssertEqual(collections.count, 0)

      let collection = try db.collection("collection1")
      // Must be idempotent.
      try collection.createIfMissing()
      try collection.createIfMissing()
      // Should be empty.
      XCTAssertFalse(try collection.exists("a"))

      collections = try db.collections()
      XCTAssertEqual(collections.count, 1)

      // TODO(zinman): Delete collection.
    }
  }

  // TODO(zinman): Add more unit tests.
}
