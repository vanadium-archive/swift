// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

extension XCTestCase {
  func withTestDb(runBlock: Database throws -> Void) {
    withTestDbAsync { (db, cleanup) in
      defer { cleanup() }
      try runBlock(db)
    }
  }

  func withTestDbAsync(runBlock: (db: Database, cleanup: Void -> Void) throws -> Void) {
    do {
      // Randomize the name to prevent conflicts between tests
      let dbName = "test\(NSUUID().UUIDString)".stringByReplacingOccurrencesOfString("-", withString: "")
      let db = try Syncbase.instance.database(dbName)
      let cleanup = {
        do {
          print("Destroying db \(db)")
          try db.destroy()
          XCTAssertFalse(try db.exists(), "Database shouldn't exist after being destroyed")
        } catch let e {
          log.warning("Unable to delete db: \(e)")
        }
      }
      do {
        print("Got db \(db)")
        XCTAssertFalse(try db.exists(), "Database shouldn't exist before being created")
        print("Creating db \(db)")
        try db.create(nil)
        XCTAssertTrue(try db.exists(), "Database should exist after being created")
        // Always delete the db at the end to prevent conflicts between tests
        try runBlock(db: db, cleanup: cleanup)
      } catch let e {
        XCTFail("Got unexpected exception: \(e)")
        cleanup()
      }
    } catch (let e) {
      XCTFail("Got unexpected exception: \(e)")
    }
  }

  func withTestCollection(runBlock: (Database, Collection) throws -> Void) {
    withTestDb { db in
      let collection = try db.collection("collection1")
      XCTAssertFalse(try collection.exists())
      try collection.create(nil)
      XCTAssertTrue(try collection.exists())

      try runBlock(db, collection)

      try collection.destroy()
      XCTAssertFalse(try collection.exists())
    }
  }
}
