// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

class BasicDatabaseTests: XCTestCase {

  // MARK: Basic test helpers

  func withTestDb(runBlock: Database throws -> Void) {
    do {
      let db = try Syncbase.instance.database("test1")
      print("Got db \(db)")
      XCTAssertFalse(try db.exists(), "Database shouldn't exist before being created")
      print("Creating db \(db)")
      try db.create(nil)
      XCTAssertTrue(try db.exists(), "Database should exist after being created")

      try runBlock(db)

      print("Destroying db \(db)")
      try db.destroy()
      XCTAssertFalse(try db.exists(), "Database shouldn't exist after being destroyed")
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
      XCTAssertEqual(databases.count, 1)
      XCTAssertTrue(databases.first! == db.databaseId)
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

  // MARK: Test getting/putting data

  class func testGetPutRow<T: SyncbaseJsonConvertible where T: Equatable>(collection: Collection, key: String, targetValue: T, equals: ((T, T) -> Bool)? = nil) throws {
    var value: T? = try collection.get(key)
    XCTAssertNil(value, "Row shouldn't exist yet")
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

  func testPrimitivesGetPut() {
    withTestCollection { db, collection in
      let key = "testrow"
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: true)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: false)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Int8.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Int16.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Int32.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Int64.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Int.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: UInt8.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: UInt16.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: UInt32.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: UInt64.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: UInt.max)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: Float(M_PI), equals: BasicDatabaseTests.floatEq)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: M_PI, equals: BasicDatabaseTests.doubleEq)
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: "oh hai")
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: "你好，世界 👠💪🏿")
    }
  }

  func testNonMixedArrayGetPut() {
    let key = "testrow"
    withTestCollection { db, collection in
      try BasicDatabaseTests.testGetPutRow(collection, key: key, targetValue: [])
      try BasicDatabaseTests.testGetPutRow(collection, key: key,
        targetValue: [UInt.max, UInt.min])
      try BasicDatabaseTests.testGetPutRow(collection, key: key,
        targetValue: [Int.max, Int.min])
      try BasicDatabaseTests.testGetPutRow(collection, key: key,
        targetValue: ["oh hai", "你好，世界 👠💪🏿"])
    }
  }

  func testMixedArrayGetPut() {
    let key = "testrow"
    withTestCollection { db, collection in
      try BasicDatabaseTests.testGetPutRow(collection, key: key,
        targetValue: [15, UInt.max, Int.min])
      try BasicDatabaseTests.testGetPutRow(collection, key: key,
        targetValue: [false, 3939, "你好，世界 👠💪🏿"])
    }
  }

  func testIntGetPut() {
    withTestCollection { db, collection in
      let key = "testrow"
      let targetValue = 283783
      var value: Int? = try collection.get(key)
      XCTAssertNil(value, "Row shouldn't exist yet")
      try collection.put(key, value: targetValue)
      value = try collection.get(key)
      XCTAssertEqual(value!, targetValue, "Value should be defined and \(targetValue)")
      try collection.delete(key)
      value = try collection.get(key)
      XCTAssertNil(value, "Deleted row shouldn't exist")
    }
  }

  // MARK: Helpers

  class func floatEq(lhs: Float, rhs: Float) -> Bool {
    return fabs(lhs - rhs) <= FLT_EPSILON
  }

  class func doubleEq(lhs: Double, rhs: Double) -> Bool {
    return fabs(lhs - rhs) <= DBL_EPSILON
  }
}
