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
    SyncbaseCore.Syncbase.isUnitTest = true
    let rootDir = NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("SyncbaseUnitTest")
      .path!
    // TODO(zinman): Once we have create-and-join implemented don't always set
    // disableUserdataSyncgroup to true.
    try! Syncbase.configure(
      adminUserId: "unittest@google.com",
      rootDir: rootDir,
      disableUserdataSyncgroup: true,
      queue: testQueue)
    let semaphore = dispatch_semaphore_create(0)
    Syncbase.login(GoogleOAuthCredentials(token: ""), callback: { err in
      XCTAssertNil(err)
      dispatch_semaphore_signal(semaphore)
    })
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
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
