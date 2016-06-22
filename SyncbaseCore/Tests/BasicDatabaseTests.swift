// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

struct EmptyCredentials: OAuthCredentials {
  let provider: OAuthProvider = OAuthProvider.Google
  let token: String = ""
}

let testQueue = dispatch_queue_create("SyncbaseQueue", DISPATCH_QUEUE_SERIAL)

class BasicDatabaseTests: XCTestCase {
  override class func setUp() {
    Syncbase.isUnitTest = true
    let rootDir = NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("SyncbaseUnitTest")
      .absoluteString
    try! Syncbase.configure(rootDir: rootDir, queue: testQueue)
    let semaphore = dispatch_semaphore_create(0)
    Syncbase.login(EmptyCredentials(), callback: { err in
      XCTAssertNil(err)
      dispatch_semaphore_signal(semaphore)
    })
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
  }

  override class func tearDown() {
    Syncbase.shutdown()
  }

  // MARK: Database & collection creation / destroying / listing

  func testDbCreateExistsDestroy() {
    withTestDb { db in }
  }

  func testListDatabases() {
    withTestDb { db in
      let databases = try Syncbase.listDatabases()
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
    XCTAssertTrue(try collection.exists(key))
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
      // Generate some test data (1 to 4096 in hex).
      var data = [String: NSData]()
      for i in 1...4096 {
        let key = NSString(format: "%x", i) as String
        let value = key.dataUsingEncoding(NSUTF8StringEncoding)!
        data[key] = value
        try collection.put(key, value: value)
      }

      // Delete single row.
      try collection.deleteRange(RowRangeSingleRow(row: "9"))
      let value: NSData? = try collection.get("9")
      XCTAssertNil(value)

      // Delete a*.
      try collection.deleteRange(RowRangePrefix(prefix: "a"))
      var stream = try collection.scan(RowRangePrefix(prefix: "a"))
      XCTAssertNil(stream.next())

      // Delete b-bc.
      try collection.deleteRange(RowRangeStandard(start: "b", limit: "bc"))
      // Get all the keys including bc and after.
      var keys = Array(data.keys.filter { $0.hasPrefix("b") }).sort()
      let bcIdx = keys.indexOf("bc")!
      keys = Array(keys.dropFirst(bcIdx))
      // Verify that's what's in the db.
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
      // Generate some test data (1 to 200 in hex).
      var data = [String: NSData]()
      for i in 1...200 {
        let key = NSString(format: "%x", i) as String
        let value = key.dataUsingEncoding(NSUTF8StringEncoding)!
        data[key] = value
        try collection.put(key, value: value)
      }

      // Test all rows scan.
      var stream = try collection.scan(RowRangeAll())
      var keys = Array(data.keys).sort() // Lexographic sort
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

      // Test single row scan.
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
      // Doing it again should be ok.
      XCTAssertNil(stream.next())

      // Test prefix scan.
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
      let collection = try batchDb.collection(Identifier(name: "collection2", blessing: anyPermissions))
      try collection.create(anyCollectionPermissions)
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
      let valueA: NSData? = try db.collection(Identifier(name: "collection2", blessing: anyPermissions)).get("a")
      let value1: NSData? = try db.collection(Identifier(name: "collection2", blessing: anyPermissions)).get("1")
      let value2: NSData? = try db.collection(Identifier(name: "collection2", blessing: anyPermissions)).get("2")
      XCTAssertNotNil(valueA)
      XCTAssertNotNil(value1)
      XCTAssertNotNil(value2)
    }
  }

  func testBatchAbort() {
    withTestDb { db in
      let batchDb = try db.beginBatch(nil)
      let collection = try batchDb.collection(Identifier(name: "collection2", blessing: anyPermissions))
      try collection.create(anyCollectionPermissions)
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
      let valueB: NSData? = try db.collection(Identifier(name: "collection2", blessing: anyPermissions)).get("b")
      let valueC: NSData? = try db.collection(Identifier(name: "collection2", blessing: anyPermissions)).get("c")
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
          let collection = try batchDb.collection(Identifier(name: "collection3", blessing: anyPermissions))
          try collection.create(anyCollectionPermissions)
          try collection.put("a", value: NSData())
        },
        completionHandler: { err in
          XCTAssertNil(err)
          do {
            let collection = try db.collection(Identifier(name: "collection3", blessing: anyPermissions))
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

    // Test sync version
    withTestDb { db in
      try Batch.runInBatchSync(db: db, opts: nil) { batchDb in
        let collection = try batchDb.collection(Identifier(name: "collection3", blessing: anyPermissions))
        try collection.create(anyCollectionPermissions)
        try collection.put("b", value: NSData())
      }
      do {
        let collection = try db.collection(Identifier(name: "collection3", blessing: anyPermissions))
        let value: NSData? = try collection.get("b")
        XCTAssertNotNil(value)
      } catch let e {
        XCTFail("Unexpected error: \(e)")
      }
    }
  }

  func testRunInBatchAbort() {
    let completed = expectationWithDescription("Completed runInBatch for abort")
    withTestDbAsync { (db, cleanup) in
      Batch.runInBatch(
        db: db,
        opts: nil,
        op: { batchDb in
          let collection = try batchDb.collection(Identifier(name: "collection4", blessing: anyPermissions))
          try collection.create(anyCollectionPermissions)
          try collection.put("a", value: NSData())
          try batchDb.abort()
        },
        completionHandler: { err in
          XCTAssertNil(err)
          do {
            let collection = try db.collection(Identifier(name: "collection4", blessing: anyPermissions))
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

    withTestDb { db in
      try Batch.runInBatchSync(db: db, opts: nil) { batchDb in
        let collection = try batchDb.collection(Identifier(name: "collection4", blessing: anyPermissions))
        try collection.create(anyCollectionPermissions)
        try collection.put("a", value: NSData())
        try batchDb.abort()
      }

      do {
        let collection = try db.collection(Identifier(name: "collection4", blessing: anyPermissions))
        let value: NSData? = try collection.get("a")
        XCTAssertNil(value)
      } catch let e {
        XCTFail("Unexpected error: \(e)")
      }
    }
  }

  // MARK: Test watch

  func testWatchTimeout() {
    let completed = expectationWithDescription("Completed watch timeout")
    withTestDbAsync { (db, cleanup) in
      self.withTestCollection(db) { db, collection in
        try collection.put("a", value: NSData())
        let stream = try db.watch([CollectionRowPattern(
          collectionName: collection.collectionId.name,
          collectionBlessing: collection.collectionId.blessing,
          rowKey: nil)])
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
          XCTAssertNil(stream.next(timeout: 0.1))
          XCTAssertNil(stream.err())
          cleanup()
          completed.fulfill()
        }
      }
    }
    waitForExpectationsWithTimeout(2) { XCTAssertNil($0) }
  }

  func testWatchPut() {
    let completed = expectationWithDescription("Completed watch put")
    // Test zero-value and non-zero-valued data. Base64 is just an easy way to pass raw bytes.
    let data = [("a", NSData()),
      ("b", NSData(base64EncodedString: "YXNka2psa2FzamQgZmxrYXNqIGRmbGthag==", options: [])!)]

    withTestDbAsync { (db, cleanup) in
      let collection = try db.collection(Identifier(name: "collectionWatchPut", blessing: anyPermissions))
      try collection.create(anyCollectionPermissions)
      let stream = try db.watch([CollectionRowPattern(
        collectionName: collection.collectionId.name,
        collectionBlessing: collection.collectionId.blessing,
        rowKey: nil)])
      let semaphore = dispatch_semaphore_create(0)
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
        dispatch_semaphore_signal(semaphore)
        // Watch for changes in bg thread.
        for tup in data {
          let (key, value) = tup
          guard let change = stream.next(timeout: 1) else {
            cleanup()
            XCTFail("Missing put change")
            completed.fulfill()
            return
          }
          XCTAssertNotNil(change)
          XCTAssertNil(stream.err())
          XCTAssertEqual(change.changeType, WatchChange.ChangeType.Put)
          XCTAssertEqual(change.collectionId.blessing, collection.collectionId.blessing)
          XCTAssertEqual(change.collectionId.name, collection.collectionId.name)
          XCTAssertFalse(change.isContinued)
          XCTAssertFalse(change.isFromSync)
          XCTAssertGreaterThan(change.resumeMarker.length, 0)
          XCTAssertEqual(change.row, key)
          XCTAssertEqual(change.value, value)
        }
        cleanup()
        completed.fulfill()
      }

      // Wait for background thread to start.
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

      // Add data.
      do {
        NSThread.sleepForTimeInterval(0.05) // Wait until the stream.next is called and blocking
        for tup in data {
          try collection.put(tup.0, value: tup.1)
        }
      } catch let e {
        XCTFail("Unexpected error: \(e)")
      }
    }
    waitForExpectationsWithTimeout(2) { XCTAssertNil($0) }
  }

  func testWatchDelete() {
    let completed = expectationWithDescription("Completed watch delete")
    // Test zero-value and non-zero-valued data. Base64 is just an easy way to pass raw bytes.
    let data = [("a", NSData()),
      ("b", NSData(base64EncodedString: "YXNka2psa2FzamQgZmxrYXNqIGRmbGthag==", options: [])!)]

    withTestDbAsync { (db, cleanup) in
      let collection = try db.collection(Identifier(name: "collectionWatchDelete", blessing: anyPermissions))
      try collection.create(anyCollectionPermissions)
      for tup in data {
        try collection.put(tup.0, value: tup.1)
      }
      let stream = try db.watch([CollectionRowPattern(
        collectionName: collection.collectionId.name,
        collectionBlessing: collection.collectionId.blessing,
        rowKey: nil)])
      let semaphore = dispatch_semaphore_create(0)
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
        dispatch_semaphore_signal(semaphore)
        // Watch for changes in bg thread.
        for tup in data {
          let (key, _) = tup
          guard let change = stream.next(timeout: 1) else {
            cleanup()
            XCTFail("Missing delete change")
            completed.fulfill()
            return
          }
          XCTAssertNil(stream.err())
          XCTAssertEqual(change.changeType, WatchChange.ChangeType.Delete)
          XCTAssertEqual(change.collectionId.blessing, collection.collectionId.blessing)
          XCTAssertEqual(change.collectionId.name, collection.collectionId.name)
          XCTAssertFalse(change.isContinued)
          XCTAssertFalse(change.isFromSync)
          XCTAssertGreaterThan(change.resumeMarker.length, 0)
          XCTAssertEqual(change.row, key)
          XCTAssertNil(change.value)
        }
        cleanup()
        completed.fulfill()
      }

      // Wait for background thread to start.
      dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

      do {
        NSThread.sleepForTimeInterval(0.05) // Wait until the stream.next is called and blocking
        // Delete rows.
        for tup in data {
          try collection.delete(tup.0)
        }
      } catch let e {
        XCTFail("Unexpected error: \(e)")
      }
    }
    waitForExpectationsWithTimeout(2) { XCTAssertNil($0) }
  }

  func testWatchError() {
    var stream: WatchStream? = nil
    withTestDb { db in
      let collection = try db.collection(Identifier(name: "collectionWatchError", blessing: anyPermissions))
      XCTAssertFalse(try collection.exists())
      try collection.create(anyCollectionPermissions)
      stream = try db.watch([CollectionRowPattern(
        collectionName: collection.collectionId.name,
        collectionBlessing: collection.collectionId.blessing,
        rowKey: nil)])
      try collection.destroy()
    }
    let change = stream!.next(timeout: 1)
    print("Got watch change: \(stream!.err())")
    XCTAssertNil(change)
    XCTAssertNotNil(stream!.err())
    let verr = stream!.err() as! VError
    XCTAssertTrue(verr.id.hasPrefix("v.io/v23/verror"))
  }
}
