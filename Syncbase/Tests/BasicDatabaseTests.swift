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

class AdvertiseScanTests: XCTestCase {
  override class func setUp() {
    configureDb(disableUserdataSyncgroup: true, disableSyncgroupPublishing: true)
  }

  override class func tearDown() {
    Syncbase.shutdown()
  }

  func testAdvertise() {
    XCTAssertFalse(Syncbase.isAdvertisingPresenceInNeighborhood())
    withDb { _ in
      // Just a simple test of the API as a sanity check -- we'd need an integration test across
      // devices or multiple simulators to make sure advertising properly worked. Testing within one
      // process inside the simulator doesn't allow us to test Bluetooth (not possible anyway on the
      // simulator -- see https://forums.developer.apple.com/thread/47230 ) or mDNS across a real
      // network. Luckily the Go code has integration tests for discovery already.
      try Syncbase.startAdvertisingPresenceInNeighborhood()
      XCTAssertTrue(Syncbase.isAdvertisingPresenceInNeighborhood())
      try Syncbase.stopAdvertisingPresenceInNeighborhood()
      XCTAssertFalse(Syncbase.isAdvertisingPresenceInNeighborhood())

      try Syncbase.startAdvertisingPresenceInNeighborhood([User(alias: "zinman@google.com")])
      XCTAssertTrue(Syncbase.isAdvertisingPresenceInNeighborhood())
      try Syncbase.stopAdvertisingPresenceInNeighborhood()
      XCTAssertFalse(Syncbase.isAdvertisingPresenceInNeighborhood())
    }
  }

  func testScan() {
    withDb { _ in
      let handler = ScanNeighborhoodForUsersHandler(
        onFound: { user in
          XCTFail("Unexpected onFound user during unit test: \(user)")
        },
        onLost: { user in
          XCTFail("Unexpected onLost user during unit test: \(user)")
      })
      try Syncbase.startScanForUsersInNeighborhood(handler)

      Syncbase.neighborhoodScansMu.lock()
      XCTAssertEqual(Syncbase.neighborhoodScans.count, 1)
      Syncbase.neighborhoodScansMu.unlock()

      Syncbase.stopScanForUsersInNeighborhood(handler)

      Syncbase.neighborhoodScansMu.lock()
      XCTAssertEqual(Syncbase.neighborhoodScans.count, 0)
      Syncbase.neighborhoodScansMu.unlock()

      try Syncbase.startScanForUsersInNeighborhood(handler)
      Syncbase.stopAllScansForUsersInNeighborhood()
    }
  }
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

  func testAddingSyncgroup() {
    withDb { db in
      let initialSemaphore = dispatch_semaphore_create(0)
      let changeSemaphore = dispatch_semaphore_create(0)
      let sg1 = Identifier(coreId: SyncbaseCore.Identifier(name: "sg1", blessing: "..."))
      var didChange = false
      try db.addUserDataWatchChangeHandler(handler: WatchChangeHandler(
        onInitialState: { _ in
          dispatch_semaphore_signal(initialSemaphore)
        },
        onChangeBatch: { changes in
          XCTAssertFalse(didChange)
          XCTAssertEqual(changes.count, 1)
          let change = changes.first!
          XCTAssertEqual(change.row, try? sg1.encode())
          XCTAssertEqual(change.changeType, WatchChange.ChangeType.Put)
          XCTAssertEqual(change.value, NSData())
          didChange = true
          dispatch_semaphore_signal(changeSemaphore)
        },
        onError: failOnNonContextError))
      if dispatch_semaphore_wait(initialSemaphore, secondsGCD(1)) != 0 {
        XCTFail("Timed out")
      }

      try Syncbase.addSyncgroupToUserData(sg1)
      if dispatch_semaphore_wait(changeSemaphore, secondsGCD(1)) != 0 {
        XCTFail("Timed out")
      }
      XCTAssertEqual(didChange, true)
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
          XCTFail("Unexpected changes: \(changes)")
        },
        onError: failOnNonContextError))
      if dispatch_semaphore_wait(semaphore, secondsGCD(1)) != 0 {
        XCTFail("Timed out")
      }
      // TODO(zinman): Add this when we support canceling watches.
//      db.removeAllWatchChangeHandlers()

      // Userdata only appears when explicitly asking for it.
      semaphore = dispatch_semaphore_create(0)
      try db.addUserDataWatchChangeHandler(
        handler: WatchChangeHandler(
          onInitialState: { changes in
            for change in changes {
              XCTAssert(change.collectionId?.name == Syncbase.USERDATA_SYNCGROUP_NAME)
            }
            dispatch_semaphore_signal(semaphore)
          },
          onChangeBatch: { changes in
            XCTFail("Unexpected changes: \(changes)")
          },
          onError: failOnNonContextError))
      if dispatch_semaphore_wait(semaphore, secondsGCD(1)) != 0 {
        XCTFail("Timed out")
      }
    }
  }
}
