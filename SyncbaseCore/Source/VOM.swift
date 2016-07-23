// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

typealias VomRawBytes = NSData

/// VOM utility functions to encode and decode Bootstrap data types.
/// This is mostly a port from binary_util.go.
enum VOM {
  static let encodingVersion = UInt8(0x80)

  /// WireType is a mapping from Swift type name to their respective VDL constants as defined by
  /// v.io/v23/vom/wiretype.vdl
  enum WireType: Int64 {
    case Bool = 1
    case UInt8 = 2
    case String = 3
    case UInt16 = 4
    case UInt32 = 5
    case UInt64 = 6
    case Int16 = 7
    case Int32 = 8
    case Int64 = 9
    case Float = 10
    case Double = 11
    case Int8 = 16
    case ByteList = 39
    case StringList = 40
  }

  static let maxBufferSize = 9 // Maximum size for a Var128 encoded number

  static func binaryEncodeBool(value: Bool) -> [UInt8] {
    // Bools are encoded as a byte where 0 = false and anything else is true.
    return [value ? 1 : 0]
  }

  typealias BoolWithEncodedLength = (value: Bool, bytesRead: Int)
  static func binaryDecodeBool(bytes: UnsafePointer<UInt8>, available: Int) throws -> BoolWithEncodedLength {
    guard available > 0 else {
      throw SyncbaseError.DeserializationError(detail: "No or invalid data encountered")
    }

    return (bytes[0] == 1, 1)
  }

  static func binaryEncodeUInt(value: UInt64) -> [UInt8] {
    // Unsigned integers are the basis for all other primitive values.  This is a
    // two-state encoding.  If the number is less than 128 (0 through 0x7f), its
    // value is written directly.  Otherwise the value is written in big-endian byte
    // order preceded by the negated byte length.
    switch value {
    case 0 ... 0x7f:
      var buffer = [UInt8](count: 1, repeatedValue: 0)
      buffer[0] = UInt8(value)
      return buffer
    case 0x80...0xff:
      var buffer = [UInt8](count: 2, repeatedValue: 0)
      buffer[0] = UInt8(0xFF)
      buffer[1] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x100...0xffff:
      var buffer = [UInt8](count: 3, repeatedValue: 0)
      buffer[0] = UInt8(0xFE)
      buffer[1] = UInt8(truncatingBitPattern: value >> 8)
      buffer[2] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x10000...0xffffff:
      var buffer = [UInt8](count: 4, repeatedValue: 0)
      buffer[0] = UInt8(0xFD)
      buffer[1] = UInt8(truncatingBitPattern: value >> 16)
      buffer[2] = UInt8(truncatingBitPattern: value >> 8)
      buffer[3] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x1000000...0xffffffff:
      var buffer = [UInt8](count: 5, repeatedValue: 0)
      buffer[0] = UInt8(0xFC)
      buffer[1] = UInt8(truncatingBitPattern: value >> 24)
      buffer[2] = UInt8(truncatingBitPattern: value >> 16)
      buffer[3] = UInt8(truncatingBitPattern: value >> 8)
      buffer[4] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x100000000...0xffffffffff:
      var buffer = [UInt8](count: 6, repeatedValue: 0)
      buffer[0] = UInt8(0xFB)
      buffer[1] = UInt8(truncatingBitPattern: value >> 32)
      buffer[2] = UInt8(truncatingBitPattern: value >> 24)
      buffer[3] = UInt8(truncatingBitPattern: value >> 16)
      buffer[4] = UInt8(truncatingBitPattern: value >> 8)
      buffer[5] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x10000000000...0xffffffffffff:
      var buffer = [UInt8](count: 7, repeatedValue: 0)
      buffer[0] = UInt8(0xFA)
      buffer[1] = UInt8(truncatingBitPattern: value >> 40)
      buffer[2] = UInt8(truncatingBitPattern: value >> 32)
      buffer[3] = UInt8(truncatingBitPattern: value >> 24)
      buffer[4] = UInt8(truncatingBitPattern: value >> 16)
      buffer[5] = UInt8(truncatingBitPattern: value >> 8)
      buffer[6] = UInt8(truncatingBitPattern: value)
      return buffer
    case 0x1000000000000...0xffffffffffffff:
      var buffer = [UInt8](count: 8, repeatedValue: 0)
      buffer[0] = UInt8(0xF9)
      buffer[1] = UInt8(truncatingBitPattern: value >> 48)
      buffer[2] = UInt8(truncatingBitPattern: value >> 40)
      buffer[3] = UInt8(truncatingBitPattern: value >> 32)
      buffer[4] = UInt8(truncatingBitPattern: value >> 24)
      buffer[5] = UInt8(truncatingBitPattern: value >> 16)
      buffer[6] = UInt8(truncatingBitPattern: value >> 8)
      buffer[7] = UInt8(truncatingBitPattern: value)
      return buffer
    default:
      var buffer = [UInt8](count: 9, repeatedValue: 0)
      buffer[0] = UInt8(0xF8)
      buffer[1] = UInt8(truncatingBitPattern: value >> 56)
      buffer[2] = UInt8(truncatingBitPattern: value >> 48)
      buffer[3] = UInt8(truncatingBitPattern: value >> 40)
      buffer[4] = UInt8(truncatingBitPattern: value >> 32)
      buffer[5] = UInt8(truncatingBitPattern: value >> 24)
      buffer[6] = UInt8(truncatingBitPattern: value >> 16)
      buffer[7] = UInt8(truncatingBitPattern: value >> 8)
      buffer[8] = UInt8(truncatingBitPattern: value)
      return buffer
    }
  }

  typealias UIntWithEncodedLength = (value: UInt64, bytesRead: Int)
  static func binaryDecodeUInt(bytes: UnsafePointer<UInt8>, available: Int) throws -> UIntWithEncodedLength {
    guard available > 0 else {
      throw SyncbaseError.DeserializationError(detail: "No data available")
    }

    let firstByte = bytes[0]
    // Handle single-byte encoding.
    if firstByte <= 0x7f {
      return (UInt64(firstByte), 1)
    }

    // Handle multi-byte encoding.
    let typeLength = Int(~firstByte + 1)
    guard typeLength >= 1 && typeLength <= maxBufferSize && typeLength <= available else {
      throw SyncbaseError.DeserializationError(detail: "Invalid length encountered")
    }

    var result: UInt64 = 0
    for pos in 1...typeLength {
      result = result << 8 | UInt64(bitPattern: Int64(bytes[pos]))
    }

    return (result, 1 + typeLength)
  }

  static func binaryEncodeInt(value: Int64) -> [UInt8] {
    // Signed integers are encoded as unsigned integers, where the low bit says
    // whether to complement the other bits to recover the int.
    var uvalue: UInt64
    if value < 0 {
      uvalue = UInt64(~value) << 1 | 1
    } else {
      uvalue = UInt64(value) << 1
    }
    return binaryEncodeUInt(uvalue)
  }

  typealias IntWithEncodedLength = (value: Int64, bytesRead: Int)
  static func binaryDecodeInt(bytes: UnsafePointer<UInt8>, available: Int) throws -> IntWithEncodedLength {
    guard available > 0 else {
      throw SyncbaseError.DeserializationError(detail: "No data available")
    }

    let firstByte = bytes[0]
    // Handle single-byte encoding.
    if firstByte <= 0x7f {
      // The least significant bit is used to differentiate positive from negative values.
      if firstByte & 0x1 == 1 {
        return (~Int64(firstByte >> 1), 1)
      }
      return (Int64(firstByte >> 1), 1)
    }

    // Handle multi-byte encoding.
    let typeLength = Int(~firstByte + 1)
    guard typeLength >= 1 && typeLength <= maxBufferSize && typeLength <= available else {
      throw SyncbaseError.DeserializationError(detail: "Invalid length encountered")
    }

    var result: UInt64 = 0
    for pos in 1...typeLength {
      // Need to convert UInt8 to Int64 here, since UInt64's bitPattern constructor takes an Int64.
      result = result << 8 | UInt64(bitPattern: Int64(bytes[pos]))
    }

    if result & 0x1 == 1 {
      // The least significant bit is used to differentiate positive from negative values.
      return (~Int64(result >> 1), 1 + typeLength)
    }
    return (Int64(result >> 1), 1 + typeLength)
  }

  /// Reverses the byte order in data and returns resulting UInt64.
  private static func reverseBytes(data: UInt64) -> UInt64 {
    return (data&0x00000000000000ff) << 56 |
    (data&0x000000000000ff00) << 40 |
    (data&0x0000000000ff0000) << 24 |
    (data&0x00000000ff000000) << 8 |
    (data&0x000000ff00000000) >> 8 |
    (data&0x0000ff0000000000) >> 24 |
    (data&0x00ff000000000000) >> 40 |
    (data&0xff00000000000000) >> 56
  }

  static func binaryEncodeDouble(value: Double) -> [UInt8] {
    // Floating point numbers are encoded as byte-reversed IEEE 754.
    let ieee = value._toBitPattern()
    // Manually unrolled byte-reversing (to decrease size of output value).
    let unsignedValue = reverseBytes(ieee)
    return binaryEncodeUInt(unsignedValue)
  }

  typealias DoubleWithEncodedLength = (value: Double, bytesRead: Int)
  static func binaryDecodeDouble(bytes: UnsafePointer<UInt8>, available: Int) throws -> DoubleWithEncodedLength {
    let unsignedValue = try binaryDecodeUInt(bytes, available: available)
    // Manually unrolled byte-reversing.
    let ieee = reverseBytes(unsignedValue.value)
    return (Double._fromBitPattern(ieee), unsignedValue.bytesRead)
  }

  static func binaryEncodeString(value: String) -> NSData? {
    // Strings are encoded as the byte count followed by uninterpreted bytes.
    let buffer = NSMutableData()
    let length = binaryEncodeUInt(UInt64(value.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)))
    buffer.appendBytes(length, length: length.count)
    if let data = value.dataUsingEncoding(NSUTF8StringEncoding) {
      buffer.appendData(data)
      return buffer
    } else {
      return nil
    }
  }

  static func binaryDecodeString(bytes: UnsafePointer<UInt8>, available: Int) throws -> (value: String, bytesRead: Int) {
    let typeLength = Int(try binaryDecodeUInt(bytes, available: available).value)

    if typeLength == 0 {
      return ("", 1)
    }

    guard typeLength + 1 <= available else {
      throw SyncbaseError.DeserializationError(detail: "Not enough data available")
    }

    if let result = String(data: NSData(bytes: bytes + 1, length: typeLength), encoding: NSUTF8StringEncoding) {
      return (result, typeLength + 1)
    } else {
      throw SyncbaseError.DeserializationError(detail: "Invalid UTF-8 Sequence")
    }
  }
}