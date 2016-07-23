// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
import SyncbaseCore

class MarshalTests: XCTestCase {
  func adheresToProtocol(value: SyncbaseConvertible) {
  }

  func testCompatibility() {
    // This is a compile-time test that makes sure that all primitive types conform to
    // SyncbaseConvertible.
    adheresToProtocol(true)
    adheresToProtocol(Int(0))
    adheresToProtocol(Int8(0))
    adheresToProtocol(Int16(0))
    adheresToProtocol(Int32(0))
    adheresToProtocol(Int64(0))
    adheresToProtocol(UInt(0))
    adheresToProtocol(UInt8(0))
    adheresToProtocol(UInt16(0))
    adheresToProtocol(UInt32(0))
    adheresToProtocol(UInt64(0))
    adheresToProtocol(Double(0))
    adheresToProtocol(Float(0))
    adheresToProtocol(String(""))
  }

  func testBool() throws {
    for value in [true, false] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Bool = try Bool.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt() throws {
    for value in [Int.min, 0, Int.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Int = try Int.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testUInt() throws {
    for value in [UInt.min, 0, UInt.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: UInt = try UInt.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt8() throws {
    for value in [Int8.min, 0, Int8.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Int8 = try Int8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testUInt8() throws {
    for value in [UInt8.min, 0, UInt8.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: UInt8 = try UInt8.deserializeFromSyncbase(serializedData)
      // UInt8 are always encoded as one byte, but we also encode the version and type byte.
      XCTAssertEqual(serializedData.length, 3)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt16() throws {
    for value in [Int16.min, 0, Int16.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Int16 = try Int16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testUInt16() throws {
    for value in [UInt16.min, 0, UInt16.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: UInt16 = try UInt16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt32() throws {
    for value in [Int32.min, 0, Int32.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Int32 = try Int32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testUInt32() throws {
    for value in [UInt32.min, 0, UInt32.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: UInt32 = try UInt32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt64() throws {
    for value in [Int64.min, 0, Int64.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: Int64 = try Int64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testInt64ToInt8() throws {
    for value in [Int8.min, 0, Int8.max] {
      let serializedData = try Int64(value).serializeToSyncbase()
      let deserializedValue: Int8 = try Int8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int8(value))
    }
  }

  func testInt64ToInt16() throws {
    for value in [Int16.min, 0, Int16.max] {
      let serializedData = try Int64(value).serializeToSyncbase()
      let deserializedValue: Int16 = try Int16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int16(value))
    }
  }

  func testInt64ToInt32() throws {
    for value in [Int32.min, 0, Int32.max] {
      let serializedData = try Int64(value).serializeToSyncbase()
      let deserializedValue: Int32 = try Int32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int32(value))
    }
  }

  func testInt32ToInt8() throws {
    for value in [Int8.min, 0, Int8.max] {
      let serializedData = try Int32(value).serializeToSyncbase()
      let deserializedValue: Int8 = try Int8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int8(value))
    }
  }

  func testInt32ToInt16() throws {
    for value in [Int16.min, 0, Int16.max] {
      let serializedData = try Int32(value).serializeToSyncbase()
      let deserializedValue: Int16 = try Int16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int16(value))
    }
  }

  func testInt32ToInt64() throws {
    for value in [Int32.min, 0, Int32.max] {
      let serializedData = try Int32(value).serializeToSyncbase()
      let deserializedValue: Int64 = try Int64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int64(value))
    }
  }

  func testInt16ToInt8() throws {
    for value in [Int8.min, 0, Int8.max] {
      let serializedData = try Int16(value).serializeToSyncbase()
      let deserializedValue: Int8 = try Int8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int8(value))
    }
  }

  func testInt16ToInt32() throws {
    for value in [Int16.min, 0, Int16.max] {
      let serializedData = try Int16(value).serializeToSyncbase()
      let deserializedValue: Int32 = try Int32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int32(value))
    }
  }

  func testInt16ToInt64() throws {
    for value in [Int16.min, 0, Int16.max] {
      let serializedData = try Int16(value).serializeToSyncbase()
      let deserializedValue: Int64 = try Int64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, Int64(value))
    }
  }

  func testUInt64() throws {
    for value in [UInt64.min, 0, UInt64.max] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: UInt64 = try UInt64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testUInt64ToUInt8() throws {
    for value in [UInt8.min, 0, UInt8.max] {
      let serializedData = try UInt64(value).serializeToSyncbase()
      let deserializedValue: UInt8 = try UInt8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt8(value))
    }
  }

  func testUInt64ToUInt16() throws {
    for value in [UInt16.min, 0, UInt16.max] {
      let serializedData = try UInt64(value).serializeToSyncbase()
      let deserializedValue: UInt16 = try UInt16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt16(value))
    }
  }

  func testUInt64ToUInt32() throws {
    for value in [UInt32.min, 0, UInt32.max] {
      let serializedData = try UInt64(value).serializeToSyncbase()
      let deserializedValue: UInt32 = try UInt32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt32(value))
    }
  }

  func testUInt32ToUInt8() throws {
    for value in [UInt8.min, 0, UInt8.max] {
      let serializedData = try UInt32(value).serializeToSyncbase()
      let deserializedValue: UInt8 = try UInt8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt8(value))
    }
  }

  func testUInt32ToUInt16() throws {
    for value in [UInt16.min, 0, UInt16.max] {
      let serializedData = try UInt32(value).serializeToSyncbase()
      let deserializedValue: UInt16 = try UInt16.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt16(value))
    }
  }

  func testUInt32ToUInt64() throws {
    for value in [UInt32.min, 0, UInt32.max] {
      let serializedData = try UInt32(value).serializeToSyncbase()
      let deserializedValue: UInt64 = try UInt64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt64(value))
    }
  }

  func testUInt16ToUInt8() throws {
    for value in [UInt8.min, 0, UInt8.max] {
      let serializedData = try UInt16(value).serializeToSyncbase()
      let deserializedValue: UInt8 = try UInt8.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt8(value))
    }
  }

  func testUInt16ToUInt32() throws {
    for value in [UInt16.min, 0, UInt16.max] {
      let serializedData = try UInt16(value).serializeToSyncbase()
      let deserializedValue: UInt32 = try UInt32.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt32(value))
    }
  }

  func testUInt16ToUInt64() throws {
    for value in [UInt16.min, 0, UInt16.max] {
      let serializedData = try UInt16(value).serializeToSyncbase()
      let deserializedValue: UInt64 = try UInt64.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, UInt64(value))
    }
  }

  func testFloat() throws {
    let value = Float(13.17)
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: Float = try Float.deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testDouble() throws {
    let value = Double(13.17)
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: Double = try Double.deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testDoubleToFloat() throws {
    let value = Double(13.17)
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: Float = try Float.deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, Float(value))
  }

  func testString() throws {
    for value in ["", "Hello world", "你好，世界", "😊"] {
      let serializedData = try value.serializeToSyncbase()
      let deserializedValue: String = try String.deserializeFromSyncbase(serializedData)
      XCTAssertEqual(deserializedValue, value)
    }
  }

  func testNSData() throws {
    let data: [UInt8] = [0, 1, 2, 3, 255]
    let value = NSData(bytes: data, length: data.count)
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: NSData = try NSData.deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testUInt8List() throws {
    let value: [UInt8] = [0, 1, 2, 3, 255]
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: [UInt8] = try [UInt8].deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testUInt8EmptyList() throws {
    let value: [UInt8] = []
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: [UInt8] = try [UInt8].deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testStringList() throws {
    let value = ["", "Hello world", "你好，世界", "😊"]
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: [String] = try [String].deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testStringEmptyList() throws {
    let value: [String] = []
    let serializedData = try value.serializeToSyncbase()
    let deserializedValue: [String] = try [String].deserializeFromSyncbase(serializedData)
    XCTAssertEqual(deserializedValue, value)
  }

  func testErrorUIntValueOfRange() throws {
    let value: UInt32 = UInt32(UInt16.max) + 1
    let serializedData = try value.serializeToSyncbase()
    do {
      let _: UInt16 = try UInt16.deserializeFromSyncbase(serializedData)
    } catch SyncbaseError.CastError {
      return
    }
    XCTFail()
  }

  func testErrorIntValueOfRange() throws {
    let value: Int32 = Int32(Int16.max) + 1
    let serializedData = try value.serializeToSyncbase()
    do {
      let _: Int16 = try Int16.deserializeFromSyncbase(serializedData)
    } catch SyncbaseError.CastError {
      return
    }
    XCTFail()
  }

  func testErrorErrorWrongType() throws {
    let value = "Hello world"
    let serializedData = try value.serializeToSyncbase()
    do {
      let _: Int16 = try Int16.deserializeFromSyncbase(serializedData)
    } catch SyncbaseError.CastError {
      return
    }
    XCTFail()
  }

  func testErrorInvalidData() throws {
    let serializedData = NSData(bytes: [UInt8(0)], length: 1)
    do {
      let _: Int16 = try Int16.deserializeFromSyncbase(serializedData)
    } catch SyncbaseError.DeserializationError {
      return
    }
    XCTFail()
  }
}
