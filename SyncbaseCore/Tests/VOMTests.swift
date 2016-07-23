// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import XCTest
@testable import SyncbaseCore

class VOMTest: XCTestCase {
  func testBinaryEncodeDecodeBool() throws {
    let testValues: [Bool: String] = {
      var testValues = [Bool: String]()
      testValues[false] = "00"
      testValues[true] = "01"
      return testValues
    }()

    for (boolEncoding, hexEncoding) in testValues {
      let data = VOM.binaryEncodeBool(boolEncoding)
      XCTAssertEqual(dataToHexString(NSData(bytes: data, length: data.count)), hexEncoding)
    }

    for (boolEncoding, hexEncoding) in testValues {
      let inputData = hexStringToData(hexEncoding)
      XCTAssertEqual(try VOM.binaryDecodeBool(UnsafePointer<UInt8>(inputData.bytes), available: inputData.length).value,
        boolEncoding)
    }
  }

  func testBinaryEncodeDecodeUInt64() throws {
    let testValues: [UInt64: String] = {
      var testValues = [UInt64: String]()
      testValues[UInt64(0)] = "00"
      testValues[UInt64(1)] = "01"
      testValues[UInt64(2)] = "02"
      testValues[UInt64(127)] = "7f"
      testValues[UInt64(128)] = "ff80"
      testValues[UInt64(255)] = "ffff"
      testValues[UInt64(256)] = "fe0100"
      testValues[UInt64(257)] = "fe0101"
      testValues[UInt64(0xffff)] = "feffff"
      testValues[UInt64(0xffffff)] = "fdffffff"
      testValues[UInt64(0xffffffff)] = "fcffffffff"
      testValues[UInt64(0xffffffffff)] = "fbffffffffff"
      testValues[UInt64(0xffffffffffff)] = "faffffffffffff"
      testValues[UInt64(0xffffffffffffff)] = "f9ffffffffffffff"
      return testValues
    }()

    for (integerEncoding, hexEncoding) in testValues {
      let data = VOM.binaryEncodeUInt(integerEncoding)
      XCTAssertEqual(dataToHexString(NSData(bytes: data, length: data.count)), hexEncoding)
    }

    for (integerEncoding, hexEncoding) in testValues {
      let inputData = hexStringToData(hexEncoding)
      XCTAssertEqual(try VOM.binaryDecodeUInt(UnsafePointer<UInt8>(inputData.bytes), available: inputData.length).value,
        integerEncoding)
    }
  }

  func testBinaryEncodeDecodeInt64() throws {
    let testValues: [Int64: String] = {
      var testValues = [Int64: String]()
      testValues[Int64(0)] = "00"
      testValues[Int64(1)] = "02"
      testValues[Int64(2)] = "04"
      testValues[Int64(63)] = "7e"
      testValues[Int64(64)] = "ff80"
      testValues[Int64(65)] = "ff82"
      testValues[Int64(127)] = "fffe"
      testValues[Int64(128)] = "fe0100"
      testValues[Int64(129)] = "fe0102"
      testValues[Int64(Int16.max)] = "fefffe"
      testValues[Int64(Int32.max)] = "fcfffffffe"
      testValues[Int64(Int64.max)] = "f8fffffffffffffffe"
      testValues[Int64(-1)] = "01"
      testValues[Int64(-2)] = "03"
      testValues[Int64(-64)] = "7f"
      testValues[Int64(-65)] = "ff81"
      testValues[Int64(-66)] = "ff83"
      testValues[Int64(-128)] = "ffff"
      testValues[Int64(-129)] = "fe0101"
      testValues[Int64(-130)] = "fe0103"
      testValues[Int64(Int16.min)] = "feffff"
      testValues[Int64(Int32.min)] = "fcffffffff"
      testValues[Int64(Int64.min)] = "f8ffffffffffffffff"
      return testValues
    }()

    for (integerEncoding, hexEncoding) in testValues {
      let data = VOM.binaryEncodeInt(integerEncoding)
      XCTAssertEqual(dataToHexString(NSData(bytes: data, length: data.count)), hexEncoding)
    }

    for (integerEncoding, hexEncoding) in testValues {
      let inputData = hexStringToData(hexEncoding)
      XCTAssertEqual(try VOM.binaryDecodeInt(UnsafePointer<UInt8>(inputData.bytes), available: inputData.length).value,
        integerEncoding)
    }
  }

  func testBinaryEncodeDecodeDouble() throws {
    let testValues: [Double: String] = {
      var testValues = [Double: String]()
      testValues[Double(0)] = "00"
      testValues[Double(1)] = "fef03f"
      testValues[Double(17)] = "fe3140"
      testValues[Double(18)] = "fe3240"
      return testValues
    }()

    for (doubleEncoding, hexEncoding) in testValues {
      let data = VOM.binaryEncodeDouble(doubleEncoding)
      XCTAssertEqual(dataToHexString(NSData(bytes: data, length: data.count)), hexEncoding)
    }

    for (doubleEncoding, hexEncoding) in testValues {
      let inputData = hexStringToData(hexEncoding)
      XCTAssertEqual(try VOM.binaryDecodeDouble(UnsafePointer<UInt8>(inputData.bytes), available: inputData.length).value,
        doubleEncoding)
    }
  }

  func testBinaryEncodeDecodeString() throws {
    let testValues: [String: String] = {
      var testValues = [String: String]()
      testValues[""] = "00"
      testValues["abc"] = "03616263"
      testValues["defghi"] = "06646566676869"
      testValues["你好，世界"] = "0fe4bda0e5a5bdefbc8ce4b896e7958c"
      testValues["😊"] = "04f09f988a"
      return testValues
    }()

    for (stringEnconding, hexEncoding) in testValues {
      let data = VOM.binaryEncodeString(stringEnconding)
      XCTAssertEqual(dataToHexString(data!), hexEncoding)
    }

    for (stringEnconding, hexEncoding) in testValues {
      let inputData = hexStringToData(hexEncoding)
      XCTAssertEqual(try VOM.binaryDecodeString(UnsafePointer<UInt8>(inputData.bytes), available: inputData.length).value,
        stringEnconding)
    }
  }
}

