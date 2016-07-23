// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

// Constants that are used to facilitate permissions for unit tests when we haven't properly
// logged in and received a real blessing.

let anyPermissions = "..."

let anyDbPermissions: Permissions = [
  "Admin": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Write": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Read": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Resolve": AccessList(allowed: [anyPermissions], notAllowed: [])]

let anyCollectionPermissions = [
  "Admin": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Write": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Read": AccessList(allowed: [anyPermissions], notAllowed: [])]

let anySyncgroupPermissions = [
  "Admin": AccessList(allowed: [anyPermissions], notAllowed: []),
  "Read": AccessList(allowed: [anyPermissions], notAllowed: [])]

/// Convert NSData to its hex representation.
func dataToHexString(data: NSData) -> String {
  let buf = UnsafePointer<UInt8>(data.bytes)

  func base16(value: UInt8) -> UInt8 {
    let charA = UInt8(UnicodeScalar("a").value)
    let char0 = UInt8(UnicodeScalar("0").value)
    return (value > 9) ? (charA + value - 10) : (char0 + value)
  }

  let ptr = UnsafeMutablePointer<UInt8>.alloc(data.length * 2)
  for i in 0 ..< data.length {
    ptr[i * 2] = base16((buf[i] >> 4) & 0xF)
    ptr[i * 2 + 1] = base16(buf[i] & 0xF)
  }

  return String(bytesNoCopy: ptr, length: data.length * 2, encoding: NSASCIIStringEncoding, freeWhenDone: true)!
}

/// Convert a Hex String to NSData.
func hexStringToData(hex: String) -> NSData {
  let result = NSMutableData()

  var startIndex = hex.startIndex
  for _ in 0..<hex.characters.count / 2 {
    let endIndex = startIndex.advancedBy(2)
    let singleByte = UInt8(hex[startIndex..<endIndex], radix: 16)!
    result.appendBytes([singleByte], length: 1)
    startIndex = endIndex
  }

  return result
}

/// Convert integer seconds into Grand Central Dispatch (GCD)'s dispatch_time_t format.
func secondsGCD(seconds: Int64) -> dispatch_time_t {
  return dispatch_time(DISPATCH_TIME_NOW, seconds * Int64(NSEC_PER_SEC))
}

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
      let db = try Syncbase.database(Identifier(name: dbName, blessing: anyPermissions))
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
        try db.create(anyDbPermissions)
        XCTAssertTrue(try db.exists(), "Database should exist after being created")
        // Always delete the db at the end to prevent conflicts between tests
        try runBlock(db: db, cleanup: cleanup)
      } catch {
        print("Got unexpected exception: \(error)")
        XCTFail("Got unexpected exception: \(error)")
        cleanup()
      }
    } catch {
      // TODO(zinman): Remove once https://github.com/vanadium/issues/issues/1391 is solved.
      print("Got unexpected exception: \(error)")
      XCTFail("Got unexpected exception: \(error)")
    }
  }

  func withTestCollection(db: Database? = nil, runBlock: (Database, Collection) throws -> Void) {
    let f = { (db: Database) in
      let collection = try db.collection(Identifier(name: "collection1", blessing: anyPermissions))
      XCTAssertFalse(try collection.exists())
      try collection.create(anyCollectionPermissions)
      XCTAssertTrue(try collection.exists())

      try runBlock(db, collection)

      try collection.destroy()
      XCTAssertFalse(try collection.exists())
    }

    do {
      if let db = db {
        try f(db)
      } else {
        withTestDb { db in
          try f(db)
        }
      }
    } catch {
      // TODO(zinman): Remove once https://github.com/vanadium/issues/issues/1391 is solved.
      print("Got unexpected exception: \(error)")
      XCTFail("Got unexpected exception: \(error)")
    }
  }
}
