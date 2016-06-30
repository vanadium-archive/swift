// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import Syncbase
import enum Syncbase.Syncbase
@testable import SyncbaseCore

let testQueue = dispatch_queue_create("SyncbaseQueue", DISPATCH_QUEUE_SERIAL)

class BasicDatabaseTests: XCTestCase {
  override class func setUp() {
    configureDb(disableUserdataSyncgroup: true, disableSyncgroupPublishing: true)
  }

  override class func tearDown() {
    Syncbase.shutdown()
  }

  func testDatabaseInit() {
    withDb { db in
      // Must be idempotent.
      try db.createIfMissing()
      try db.createIfMissing()
    }
  }

  func testCollection() {
    withDb { db in
      var collections = try db.collections()
      XCTAssertEqual(collections.count, 0)

      let collection = try db.collection("collection1")
      // Must be idempotent.
      try collection.createIfMissing()
      try collection.createIfMissing()
      collections = try db.collections()
      XCTAssertEqual(collections.count, 1)
      // Should be empty.
      XCTAssertFalse(try collection.exists("a"))

      try collection.destroy()
      collections = try db.collections()
      XCTAssertEqual(collections.count, 0)
    }
  }

  // TODO(zinman): Add more unit tests.
}

class SyncgroupTests: XCTestCase {
  override class func setUp() {
    configureDb(disableUserdataSyncgroup: false, disableSyncgroupPublishing: true)
  }

  override class func tearDown() {
    Syncbase.shutdown()
  }

  func testUserdata() {
    withDb { db in
      let coreCollections = try db.coreDatabase.listCollections()
      XCTAssertEqual(coreCollections.count, 1)
      XCTAssertEqual(coreCollections[0].name, Syncbase.USERDATA_SYNCGROUP_NAME)

      let coreSyncgroups = try db.coreDatabase.listSyncgroups()
      XCTAssertEqual(coreSyncgroups.count, 1)
      XCTAssertEqual(coreSyncgroups[0].name, Syncbase.USERDATA_SYNCGROUP_NAME)

      let verSpec = try db.coreDatabase.syncgroup(Syncbase.USERDATA_SYNCGROUP_NAME).getSpec()
      XCTAssertEqual(verSpec.spec.collections.count, 1)

      // TODO(razvanm): Make the userdata syncgroup private.
      XCTAssertEqual(verSpec.spec.isPrivate, false)
    }
  }
}
