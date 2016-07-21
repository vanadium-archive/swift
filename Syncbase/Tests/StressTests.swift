// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import Syncbase

class StressTests: XCTestCase {
  override class func setUp() {
    configureDb(disableUserdataSyncgroup: false, disableSyncgroupPublishing: true)
  }

  override class func tearDown() {
    Syncbase.shutdown()
  }

  func testManyCollectionsAndSyncgroups() {
    let count = 1024
    XCTAssertEqual(try! Syncbase.database().collections().count, 0)
    for _ in 0 ..< count {
      try! Syncbase.database().createCollection(withoutSyncgroup: false)
    }
    XCTAssertEqual(try! Syncbase.database().collections().count, count)
    // See https://github.com/vanadium/issues/issues/1404 for motivation.
    try! Syncbase.startAdvertisingPresenceInNeighborhood()
    XCTAssertTrue(Syncbase.isAdvertisingPresenceInNeighborhood())
    try! Syncbase.stopAdvertisingPresenceInNeighborhood()
    XCTAssertFalse(Syncbase.isAdvertisingPresenceInNeighborhood())
  }
}

