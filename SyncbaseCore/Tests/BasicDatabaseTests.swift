// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

class BasicDatabaseTests: XCTestCase {

  // MARK: Basic test helpers

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

  func testDbCreateExistsDestroy() {
    withTestDb { db in }
  }

  func testListDatabases() {
    withTestDb { db in
      let databases = try Syncbase.instance.listDatabases()
      XCTAssertFalse(databases.isEmpty)
      if !databases.isEmpty {
        XCTAssertTrue(databases.first! == db.databaseId)
      }
    }
  }

  func testCollectionCreateExistsDestroy() {
    withTestCollection { db, collection in }
  }

  func testListCollections() {
    withTestCollection { db, collection in
      let collections = try db.listCollections()
      XCTAssertEqual(collections.count, 1)
      XCTAssertTrue(collections.first! == collection.collectionId)
    }
  }

  // MARK: Test getting/putting/deleting data

  class func testGetPutRow<T: SyncbaseConvertible where T: Equatable>(collection: Collection, key: String, targetValue: T, equals: ((T, T) -> Bool)? = nil) throws {
    var value: T? = try collection.get(key)
    XCTAssertNil(value, "Row shouldn't exist yet; yet it has value \(value)")
    try collection.put(key, value: targetValue)
    value = try collection.get(key)
    if let eq = equals {
      XCTAssertTrue(eq(value!, targetValue), "Value should be defined and \(targetValue)")
    } else {
      XCTAssertEqual(value!, targetValue, "Value should be defined and \(targetValue)")
    }
    try collection.delete(key)
    value = try collection.get(key)
    XCTAssertNil(value, "Deleted row shouldn't exist")
  }

  func testRawBytesGetPut() {
    withTestCollection { db, collection in
      let key = "testrow"
      try collection.delete(key)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: NSData())
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: NSJSONSerialization.hackSerializeAnyObject(false))
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: NSJSONSerialization.hackSerializeAnyObject(M_PI))
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: NSJSONSerialization.hackSerializeAnyObject("你好，世界 👠💪🏿"))
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: "\0\0\0".dataUsingEncoding(NSUTF8StringEncoding)!)
      if let p = NSBundle.mainBundle().executablePath,
        data = NSFileManager.defaultManager().contentsAtPath(p) {
          try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: data)
      }
    }
  }

  func testDeleteRange() {
    withTestCollection { db, collection in
      // Generate some test data (1 to 4096 in hex)
      var data = [String: NSData]()
      for i in 1...4096 {
        let key = NSString(format: "%x", i) as String
        let value = key.dataUsingEncoding(NSUTF8StringEncoding)!
        data[key] = value
        try collection.put(key, value: value)
      }

      // Delete single row
      try collection.deleteRange(RowRangeSingleRow(row: "9"))
      let value: NSData? = try collection.get("9")
      XCTAssertNil(value)

      // Delete a*
      try collection.deleteRange(RowRangePrefix(prefix: "a"))
      var stream = try collection.scan(RowRangePrefix(prefix: "a"))
      XCTAssertNil(stream.next())

      // Delete b-bc
      try collection.deleteRange(RowRangeStandard(start: "b", limit: "bc"))
      // Get all the keys including bc and after
      var keys = Array(data.keys.filter { $0.hasPrefix("b") }).sort()
      let bcIdx = keys.indexOf("bc")!
      keys = Array(keys.dropFirst(bcIdx))
      // Verify that's what's in the db
      stream = try collection.scan(RowRangePrefix(prefix: "b"))
      for (key, _) in stream {
        let targetKey = keys[0]
        XCTAssertEqual(key, targetKey)
        keys.removeFirst()
      }
      XCTAssertTrue(keys.isEmpty)
      XCTAssertNil(stream.next())
    }
  }

  func testScan() {
    withTestCollection { db, collection in
      // Generate some test data (1 to 200 in hex)
      var data = [String: NSData]()
      for i in 1...200 {
        let key = NSString(format: "%x", i) as String
        let value = key.dataUsingEncoding(NSUTF8StringEncoding)!
        data[key] = value
        try collection.put(key, value: value)
      }

      // All rows
      var stream = try collection.scan(RowRangeAll())
      var keys = Array(data.keys).sort() // lexographic sort
      for (key, getValue) in stream {
        let value = try getValue() as! NSData
        let valueStr = NSString(data: value, encoding: NSUTF8StringEncoding)!
        XCTAssertEqual(key, valueStr)

        let targetKey = keys[0]
        XCTAssertEqual(key, targetKey)
        keys.removeFirst()
      }
      XCTAssertTrue(keys.isEmpty)
      XCTAssertNil(stream.next())

      // Single Row
      stream = try collection.scan(RowRangeSingleRow(row: "a"))
      guard let (key, getValue) = stream.next() else {
        XCTFail()
        return
      }
      XCTAssertEqual(key, "a")
      let value = try getValue() as! NSData
      let valueStr = NSString(data: value, encoding: NSUTF8StringEncoding)!
      XCTAssertEqual(key, valueStr)
      XCTAssertNil(stream.next())
      // Doing it again should be ok
      XCTAssertNil(stream.next())

      // Prefix
      stream = try collection.scan(RowRangePrefix(prefix: "8"))
      keys = Array(data.keys.filter { $0.hasPrefix("8") }).sort() // lexographic sort
      for (key, _) in stream {
        let targetKey = keys[0]
        XCTAssertEqual(key, targetKey)
        keys.removeFirst()
      }
      XCTAssertTrue(keys.isEmpty)
      XCTAssertNil(stream.next())
    }
  }

  // MARK: Test batches

  func testBatchCommit() {
    withTestDb { db in
      let batchDb = try db.beginBatch(nil)
      let collection = try batchDb.collection("collection2")
      try collection.create(nil)
      try collection.put("a", value: NSData())
      try collection.put("1", value: NSData())
      try collection.put("2", value: NSData())
      try batchDb.commit()
      do {
        let _: NSData? = try collection.get("a")
        XCTFail("Should have thrown an UnknownBatch exception")
      } catch SyncbaseError.UnknownBatch {
        // Expect this to fail since the batch is already commited -- the collection reference
        // is now invalid.
      } catch {
        XCTFail("Should have thrown an UnknownBatch exception")
      }
      let valueA: NSData? = try db.collection("collection2").get("a")
      let value1: NSData? = try db.collection("collection2").get("1")
      let value2: NSData? = try db.collection("collection2").get("2")
      XCTAssertNotNil(valueA)
      XCTAssertNotNil(value1)
      XCTAssertNotNil(value2)
    }
  }

  func testBatchAbort() {
    withTestDb { db in
      let batchDb = try db.beginBatch(nil)
      let collection = try batchDb.collection("collection2")
      try collection.create(nil)
      try collection.put("b", value: NSData())
      try collection.put("c", value: NSData())
      try batchDb.abort()
      do {
        let _: NSData? = try collection.get("a")
        XCTFail("Should have thrown an UnknownBatch exception")
      } catch SyncbaseError.UnknownBatch {
        // Expect this to fail since the batch is already commited -- the collection reference
        // is now invalid.
      } catch {
        XCTFail("Should have thrown an UnknownBatch exception")
      }
      let valueB: NSData? = try db.collection("collection2").get("b")
      let valueC: NSData? = try db.collection("collection2").get("c")
      XCTAssertNil(valueB)
      XCTAssertNil(valueC)
    }
  }

  func testRunInBatchAutoCommit() {
    let completed = expectationWithDescription("Completed runInBatch for auto commit")
    withTestDbAsync { (db, cleanup) in
      Batch.runInBatch(
        db: db,
        opts: nil,
        op: { batchDb in
          let collection = try batchDb.collection("collection3")
          try collection.create(nil)
          try collection.put("a", value: NSData())
        },
        completionHandler: { err in
          XCTAssertNil(err)
          do {
            let collection = try db.collection("collection3")
            let value: NSData? = try collection.get("a")
            XCTAssertNotNil(value)
          } catch let e {
            XCTFail("Unexpected error: \(e)")
          }
          cleanup()
          completed.fulfill()
      })
    }
    waitForExpectationsWithTimeout(2) { XCTAssertNil($0) }
  }

  func testRunInBatchAbort() {
    let completed = expectationWithDescription("Completed runInBatch for abort")
    withTestDbAsync { (db, cleanup) in
      Batch.runInBatch(
        db: db,
        opts: nil,
        op: { batchDb in
          let collection = try batchDb.collection("collection4")
          try collection.create(nil)
          try collection.put("a", value: NSData())
          try batchDb.abort()
        },
        completionHandler: { err in
          XCTAssertNil(err)
          do {
            let collection = try db.collection("collection4")
            let value: NSData? = try collection.get("a")
            XCTAssertNil(value)
          } catch let e {
            XCTFail("Unexpected error: \(e)")
          }
          cleanup()
          completed.fulfill()
      })
    }
    waitForExpectationsWithTimeout(2) { XCTAssertNil($0) }
  }
}
