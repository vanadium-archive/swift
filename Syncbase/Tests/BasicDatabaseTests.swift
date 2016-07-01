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

      // Expect filtered from HLAPI
      let collections = try db.collections()
      XCTAssertEqual(collections.count, 0)

      let coreSyncgroups = try db.coreDatabase.listSyncgroups()
      XCTAssertEqual(coreSyncgroups.count, 1)
      XCTAssertEqual(coreSyncgroups[0].name, Syncbase.USERDATA_SYNCGROUP_NAME)

      // Expect filtered from HLAPI
      let syncgroups = try db.syncgroups()
      XCTAssertEqual(syncgroups.count, 0)

      let verSpec = try db.coreDatabase.syncgroup(Syncbase.USERDATA_SYNCGROUP_NAME).getSpec()
      XCTAssertEqual(verSpec.spec.collections.count, 1)

      // TODO(razvanm): Make the userdata syncgroup private.
      XCTAssertEqual(verSpec.spec.isPrivate, false)
    }
  }

  func testWatchIgnoresUserData() {
    withDb { db in
      var semaphore = dispatch_semaphore_create(0)
      // Nothing for a generic watch.
      try db.addWatchChangeHandler(handler: WatchChangeHandler(
        onInitialState: { changes in
          XCTAssertEqual(changes.count, 0)
          dispatch_semaphore_signal(semaphore)
        },
        onChangeBatch: { changes in
          XCTFail("Unexpected changes: \(changes)") },
        onError: { err in
          XCTFail("Unexpected error: \(err)")
        }))
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
      // TODO(zinman): Add this when we support canceling watches.
//      db.removeAllWatchChangeHandlers()

      // Userdata only appears when explicitly asking for it.
      semaphore = dispatch_semaphore_create(0)
      try db.addUserDataWatchChangeHandler(
        handler: WatchChangeHandler(
          onInitialState: { changes in
            XCTAssertEqual(changes.count, 1)
            XCTAssert(changes[0].collectionId?.name == Syncbase.USERDATA_SYNCGROUP_NAME)
            dispatch_semaphore_signal(semaphore)
          },
          onChangeBatch: { changes in
            XCTFail("Unexpected changes: \(changes)") },
          onError: { err in
            XCTFail("Unexpected error: \(err)")
        }))
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }
  }
}
