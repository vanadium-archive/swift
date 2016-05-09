// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import SyncbaseCore

class NSNumberTests: XCTestCase {
  func testISNSNumber() {
    XCTAssertTrue(NSNumber.isNSNumber(NSNumber(bool: true)))
    XCTAssertFalse(NSNumber.isNSNumber(true))
    XCTAssertTrue(NSNumber.isNSNumber(true as AnyObject))
    XCTAssertTrue(NSNumber.isNSNumber(true as NSNumber))
    XCTAssertFalse(NSNumber.isNSNumber(""))
    XCTAssertFalse(NSNumber.isNSNumber(5))
    XCTAssertTrue(NSNumber.isNSNumber(5 as AnyObject))
  }

  func testConservationOfPrecision() {
    var anyobj: AnyObject?
    var nsnumber: NSNumber?
    var bool: Bool? = true
    var int: Int? = Int.max
    var int8: Int8? = Int8.max
    var int16: Int16? = Int16.max
    var int32: Int32? = Int32.max
    var int64: Int64? = Int64.max
    var float: Float? = Float(Int32.max)
    var double: Double? = Double(Int64.max)
    var long: CLong? = CLong.max
    var uint: UInt? = UInt.max
    var uint8: UInt8? = UInt8.max
    var uint16: UInt16? = UInt16.max
    var uint32: UInt32? = UInt32.max
    var uint64: UInt64? = UInt64.max
    var ulong: CUnsignedLong? = CUnsignedLong.max

    // Preserve booleans
    XCTAssertTrue((true as NSNumber).isTargetCastable(&bool))
    XCTAssertTrue((true as NSNumber).isTargetCastable(&anyobj))
    XCTAssertTrue((true as NSNumber).isTargetCastable(&nsnumber))
    XCTAssertFalse((true as NSNumber).isTargetCastable(&int))
    XCTAssertFalse((true as NSNumber).isTargetCastable(&float))
    XCTAssertFalse((true as NSNumber).isTargetCastable(&long))

    // Preserved size
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&int8))
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&int16))
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&int32))
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&int64))
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&int))
    XCTAssertTrue(NSNumber(char: int8!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(char: int8!).isTargetCastable(&float))
    XCTAssertFalse(NSNumber(char: int8!).isTargetCastable(&double))

    XCTAssertFalse(NSNumber(short: int16!).isTargetCastable(&int8))
    XCTAssertTrue(NSNumber(short: int16!).isTargetCastable(&int16))
    XCTAssertTrue(NSNumber(short: int16!).isTargetCastable(&int32))
    XCTAssertTrue(NSNumber(short: int16!).isTargetCastable(&int64))
    XCTAssertTrue(NSNumber(short: int16!).isTargetCastable(&int))
    XCTAssertTrue(NSNumber(short: int16!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(short: int16!).isTargetCastable(&float))
    XCTAssertFalse(NSNumber(short: int16!).isTargetCastable(&double))

    XCTAssertFalse(NSNumber(int: int32!).isTargetCastable(&int8))
    XCTAssertFalse(NSNumber(int: int32!).isTargetCastable(&int16))
    XCTAssertTrue(NSNumber(int: int32!).isTargetCastable(&int32))
    XCTAssertTrue(NSNumber(int: int32!).isTargetCastable(&int64))
    XCTAssertTrue(NSNumber(int: int32!).isTargetCastable(&int))
    XCTAssertTrue(NSNumber(int: int32!).isTargetCastable(&uint))
    XCTAssertTrue(NSNumber(int: int32!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(int: int32!).isTargetCastable(&float))
    XCTAssertFalse(NSNumber(int: int32!).isTargetCastable(&double))

    if sizeof(CLong) == sizeof(Int64) {
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&int8))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&int16))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&int32))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&int64))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&long))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&int))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&uint))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&float))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&double))
    } else {
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&int8))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&int16))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&int32))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&int64))
      XCTAssertTrue(NSNumber(long: int!).isTargetCastable(&long))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&float))
      XCTAssertFalse(NSNumber(long: int!).isTargetCastable(&double))
    }

    XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&int8))
    XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&int16))
    XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&int32))
    if sizeof(Int) == sizeof(Int64) {
      XCTAssertTrue(NSNumber(longLong: int64!).isTargetCastable(&int))
    } else {
      XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&int))
    }
    XCTAssertTrue(NSNumber(longLong: int64!).isTargetCastable(&int64))
    XCTAssertTrue(NSNumber(longLong: int64!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&float))
    XCTAssertFalse(NSNumber(longLong: int64!).isTargetCastable(&double))

    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int8))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int16))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int32))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&uint8))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&uint16))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&uint32))
    XCTAssertTrue(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&uint64))
    XCTAssertTrue(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&ulong))
    // TODO(zinman): Be smarter about when we allow this or not
    if sizeof(Int) == sizeof(Int64) {
      XCTAssertTrue(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int))
    } else {
      XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int))
    }
    XCTAssertTrue(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&int64))
    XCTAssertTrue(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&float))
    XCTAssertFalse(NSNumber(unsignedLongLong: uint64!).isTargetCastable(&double))

    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&int8))
    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&int16))
    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&int32))
    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&int64))
    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&int))
    XCTAssertFalse(NSNumber(float: float!).isTargetCastable(&long))
    XCTAssertTrue(NSNumber(float: float!).isTargetCastable(&float))
    XCTAssertTrue(NSNumber(float: float!).isTargetCastable(&double))

    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&int8))
    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&int16))
    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&int32))
    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&int64))
    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&long))
    XCTAssertFalse(NSNumber(double: double!).isTargetCastable(&float))
    XCTAssertTrue(NSNumber(double: double!).isTargetCastable(&double))
  }
}
