// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import SyncbaseCore

class JSONTests: XCTestCase {
  // Emulate syncbase's put
  func toJSON(any: SyncbaseJsonConvertible) -> (NSData, JsonDataType) {
    return try! any.toSyncbaseJson()
  }

  func toString(json: NSData) -> String {
    return String(data: json, encoding: NSUTF8StringEncoding)!
  }

  func testBasicEncoding() {
    var (data, type) = try! 5.toSyncbaseJson()
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int)
    (data, type) = toJSON(5)
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int)
    (data, type) = try! true.toSyncbaseJson()
    XCTAssertEqual(toString(data), "true")
    XCTAssertEqual(type, JsonDataType.Bool)
    (data, type) = try! false.toSyncbaseJson()
    XCTAssertEqual(toString(data), "false")
    XCTAssertEqual(type, JsonDataType.Bool)
    (data, type) = try! Int8(5).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int8)
    (data, type) = try! Int16(5).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int16)
    (data, type) = try! Int32(5).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int32)
    (data, type) = try! Int64(5).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5")
    XCTAssertEqual(type, JsonDataType.Int64)
    (data, type) = try! Int64(Int64(Int32.max) + 10).toSyncbaseJson()
    XCTAssertEqual(toString(data), "\(Int64(Int32.max) + 10)")
    XCTAssertEqual(type, JsonDataType.Int64)
    (data, type) = try! Float(5.0).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5") // 5 is ok here since we pass knowledge it's a float
    XCTAssertEqual(type, JsonDataType.Float)
    (data, type) = try! Double(5.1).toSyncbaseJson()
    XCTAssertEqual(toString(data), "5.1") // 5 is ok here since we pass knowledge it's a float
    XCTAssertEqual(type, JsonDataType.Double)
    (data, type) = try! "Hello world! 👠".toSyncbaseJson()
    XCTAssertEqual(toString(data), "\"Hello world! 👠\"")
    XCTAssertEqual(type, JsonDataType.String)
    (data, type) = try! [1, 2, 3, 4].toSyncbaseJson()
    XCTAssertEqual(toString(data), "[1,2,3,4]")
    XCTAssertEqual(type, JsonDataType.Array)
    (data, type) = toJSON([1, 2, 3, 4])
    XCTAssertEqual(toString(data), "[1,2,3,4]")
    XCTAssertEqual(type, JsonDataType.Array)
    (data, type) = try! ["a", "b", "c"].toSyncbaseJson()
    XCTAssertEqual(toString(data), "[\"a\",\"b\",\"c\"]")
    XCTAssertEqual(type, JsonDataType.Array)
    (data, type) = try! ["a": 1].toSyncbaseJson()
    XCTAssertEqual(toString(data), "{\"a\":1}")
    XCTAssertEqual(type, JsonDataType.Dictionary)
    (data, type) = try! ["b": true].toSyncbaseJson()
    XCTAssertEqual(toString(data), "{\"b\":true}")
    XCTAssertEqual(type, JsonDataType.Dictionary)
    (data, type) = try! ["c": "👠"].toSyncbaseJson()
    XCTAssertEqual(toString(data), "{\"c\":\"👠\"}")
    XCTAssertEqual(type, JsonDataType.Dictionary)
    (data, type) = toJSON(["c": "👠"])
    XCTAssertEqual(toString(data), "{\"c\":\"👠\"}")
    XCTAssertEqual(type, JsonDataType.Dictionary)
  }
}
