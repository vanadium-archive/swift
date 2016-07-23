// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// NOTE: This file is largely temporary until we have a proper Swift-VOM implementation.

import Foundation

// The initial capacity fits the version byte, the type byte as well as up to 9 bytes to encode
// doubles, float and the maximum Var128 value.
let basicTypeInitialCapacity = 11

public enum JsonErrors: ErrorType {
  case ArrayContainsInvalidTypes
  case DictionaryContainsInvalidTypes
  case CastError(value: Any, target: Any)
  case EncodingError(obj: Any)
}

extension NSJSONSerialization {
  static func serialize(obj: AnyObject) throws -> NSData {
    do {
      var data: NSData?
      try SBObjcHelpers.catchObjcException {
        data = try? NSJSONSerialization.dataWithJSONObject(obj, options: [])
      }
      if let d = data {
        return d
      }
    } catch { }
    // Either threw an exception already or otherwise wasn't able to serialize this.
    throw JsonErrors.EncodingError(obj: obj)
  }

  /// Serializes primitives to JSON using Apple's NSJSONSerializer. This function gets around
  /// Apple's limitation of requiring top
  static func hackSerializeAnyObject(obj: AnyObject) throws -> NSData {
    let data = try serialize([obj])
    // Hack of first and last runes, which also happen to be single byte UTF-8s
    return data.subdataWithRange(NSMakeRange(1, data.length - 2))
  }

  static func deserialize(data: NSData) throws -> AnyObject {
    do {
      return try NSJSONSerialization.JSONObjectWithData(data, options: [.AllowFragments])
    } catch (let e) {
      let str = NSString(data: data, encoding: NSUTF8StringEncoding) ?? data.description
      log.warning("Unable to json deserialize data: \(str)")
      throw e
    }
  }
}

public protocol SyncbaseConvertible {
  func serializeToSyncbase() throws -> NSData
  static func deserializeFromSyncbase<T: SyncbaseConvertible>(data: NSData) throws -> T
}

private func serializeType(wireType: VOM.WireType, data: [UInt8]? = nil) -> NSMutableData {
  let buffer = NSMutableData(capacity: basicTypeInitialCapacity)!
  buffer.appendBytes([VOM.encodingVersion], length: 1)
  let type = VOM.binaryEncodeInt(wireType.rawValue)
  buffer.appendBytes(type, length: type.count)
  if let binaryData = data {
    buffer.appendBytes(binaryData, length: binaryData.count)
  }
  return buffer
}

private func deserializeType(inout ptr: UnsafePointer<UInt8>, inout length: Int) throws -> VOM.WireType {
  guard length > 1 && ptr[0] == VOM.encodingVersion else {
    throw SyncbaseError.DeserializationError(detail: "Unsupported serialization version")
  }

  ptr = ptr.advancedBy(1); length -= 1
  let encodedWireType = try VOM.binaryDecodeInt(ptr, available: length)
  ptr = ptr.advancedBy(encodedWireType.bytesRead); length -= encodedWireType.bytesRead

  guard let type = VOM.WireType(rawValue: encodedWireType.value) else {
    throw SyncbaseError.DeserializationError(detail: "Invalid data type")
  }

  return type
}

extension SyncbaseConvertible {
  public static func deserializeFromSyncbase<T: SyncbaseConvertible>(data: NSData) throws -> T {
    var ptr = UnsafePointer<UInt8>(data.bytes)
    var length = data.length
    let wireType = try deserializeType(&ptr, length: &length)

    switch wireType {
    case VOM.WireType.Bool:
      guard let result = try VOM.binaryDecodeBool(ptr, available: length).value as? T else {
        throw SyncbaseError.CastError(obj: data)
      }
      return result
    case VOM.WireType.Int8, VOM.WireType.Int16, VOM.WireType.Int32, VOM.WireType.Int64:
      let value: Int64 = try VOM.binaryDecodeInt(ptr, available: length).value
      // VOM allows conversions between certain compatible types. We mirror this here with conditional
      // casts for integers.
      if let result = Int64(value) as? T {
        return result
      } else if value >= Int64(Int.min) && value <= Int64(Int.max), let result = Int(value) as? T {
        // Note: Not using ranges since the maximum Int64 can't be included inside of a range.
        return result
      } else if Int64(Int32.min)...Int64(Int32.max) ~= value, let result = Int32(value) as? T {
        return result
      } else if Int64(Int16.min)...Int64(Int16.max) ~= value, let result = Int16(value) as? T {
        return result
      } else if Int64(Int8.min)...Int64(Int8.max) ~= value, let result = Int8(value) as? T {
        return result
      }
      throw SyncbaseError.CastError(obj: data)
    case VOM.WireType.UInt8, VOM.WireType.UInt16, VOM.WireType.UInt32, VOM.WireType.UInt64:
      var value: UInt64
      if (wireType == VOM.WireType.UInt8) {
        // In version 0x80, bytes are written directly as bytes to the stream.
        // TODO(mrschmidt): Implement 0x81 decoding
        value = UInt64(ptr[0])
      } else {
        value = try VOM.binaryDecodeUInt(ptr, available: length).value
      }

      // VOM allows conversions between certain compatible types. We mirror this here with conditional
      // casts for unsigned integers.
      if let result = UInt64(value) as? T {
        return result
      } else if value >= UInt64(UInt.min) && value <= UInt64(UInt.max), let result = UInt(value) as? T {
        // Note: Not using ranges since the maximum UInt64 can't be included inside of a range.
        return result
      } else if UInt64(UInt32.min)...UInt64(UInt32.max) ~= value, let result = UInt32(value) as? T {
        return result
      } else if UInt64(UInt16.min)...UInt64(UInt16.max) ~= value, let result = UInt16(value) as? T {
        return result
      } else if UInt64(UInt8.min)...UInt64(UInt8.max) ~= value, let result = UInt8(value) as? T {
        return result
      }
      throw SyncbaseError.CastError(obj: data)
    case VOM.WireType.Float, VOM.WireType.Double:
      let value: Double = try VOM.binaryDecodeDouble(ptr, available: length).value
      // VOM allows conversions between certain compatible types. We mirror this here with conditional
      // casts for floating point numbers.
      if let result = Double(value) as? T {
        return result
      } else if let result = Float(value) as? T {
        return result
      }
      throw SyncbaseError.CastError(obj: data)
    case VOM.WireType.String:
      guard let result = try VOM.binaryDecodeString(ptr, available: length).value as? T else {
        throw SyncbaseError.CastError(obj: data)
      }
      return result
    default:
      throw SyncbaseError.DeserializationError(detail: "Unsupported data type")
    }
  }
}

extension Bool: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Bool, data: VOM.binaryEncodeBool(self))
  }
}

extension Int: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Int64, data: VOM.binaryEncodeInt(Int64(self)))
  }
}

extension Int8: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Int8, data: VOM.binaryEncodeInt(Int64(self)))
  }
}

extension Int16: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Int16, data: VOM.binaryEncodeInt(Int64(self)))
  }
}

extension Int32: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Int32, data: VOM.binaryEncodeInt(Int64(self)))
  }
}

extension Int64: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Int64, data: VOM.binaryEncodeInt(self))
  }
}

extension UInt: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.UInt64, data: VOM.binaryEncodeUInt(UInt64(self)))
  }
}

extension UInt8: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    // VOM 0x80 directly serializes bytes
    return serializeType(VOM.WireType.UInt8, data: [self])
  }
}

extension UInt16: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.UInt16, data: VOM.binaryEncodeUInt(UInt64(self)))
  }
}

extension UInt32: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.UInt32, data: VOM.binaryEncodeUInt(UInt64(self)))
  }
}

extension UInt64: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.UInt64, data: VOM.binaryEncodeUInt(self))
  }
}

extension Float: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Float, data: VOM.binaryEncodeDouble(Double(self)))
  }
}

extension Double: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return serializeType(VOM.WireType.Double, data: VOM.binaryEncodeDouble(self))
  }
}

extension String: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    let buffer = serializeType(VOM.WireType.String)

    guard let data = VOM.binaryEncodeString(self) else {
      throw SyncbaseError.SerializationError(detail: "Cannot convert String to UTF-8")
    }

    buffer.appendData(data)
    return buffer
  }
}

extension NSData: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    let buffer = serializeType(VOM.WireType.ByteList)
    let length = VOM.binaryEncodeUInt(UInt64(self.length))
    buffer.appendBytes(length, length: length.count)
    buffer.appendBytes(self.bytes, length: self.length)
    return buffer
  }

  public static func deserializeFromSyncbase(data: NSData) throws -> NSData {
    let data: [UInt8] = try [UInt8].deserializeFromSyncbase(data)
    return NSData(bytes: data, length: data.count)
  }
}

// In Swift2, extensions with constraints cannot specify a protocol, so instead of adherering
// to SyncbaseConvertible, we provide custom functions that deal with [UInt8] and [String].
extension _ArrayType where Generator.Element == UInt8 {
  public func serializeToSyncbase() throws -> NSData {
    let buffer = serializeType(VOM.WireType.ByteList)
    let length = VOM.binaryEncodeUInt(UInt64(self.count))
    buffer.appendBytes(length, length: length.count)
    buffer.appendBytes([UInt8](self), length: self.count)
    return buffer
  }

  public static func deserializeFromSyncbase(data: NSData) throws -> [UInt8] {
    var ptr = UnsafePointer<UInt8>(data.bytes)
    var length = data.length

    guard try deserializeType(&ptr, length: &length) == VOM.WireType.ByteList else {
      throw SyncbaseError.DeserializationError(detail: "Unsupported data type")
    }
    let listLength = try VOM.binaryDecodeUInt(ptr, available: length)
    ptr = ptr.advancedBy(listLength.bytesRead); length -= listLength.bytesRead

    guard Int(listLength.value) <= length else {
      throw SyncbaseError.DeserializationError(detail: "Not enough data available")
    }
    let result = Array(UnsafeBufferPointer(start: UnsafePointer<UInt8>(ptr), count: Int(listLength.value)))
    return result
  }
}

extension _ArrayType where Generator.Element == String {
  public func serializeToSyncbase() throws -> NSData {
    let buffer = serializeType(VOM.WireType.StringList)
    let length = VOM.binaryEncodeUInt(UInt64(self.count))
    buffer.appendBytes(length, length: length.count)
    for value in self {
      guard let data = VOM.binaryEncodeString(value) else {
        throw SyncbaseError.SerializationError(detail: "Cannot convert String to UTF-8")
      }

      buffer.appendData(data)
    }
    return buffer
  }

  public static func deserializeFromSyncbase(data: NSData) throws -> [String] {
    var ptr = UnsafePointer<UInt8>(data.bytes)
    var length = data.length

    guard try deserializeType(&ptr, length: &length) == VOM.WireType.StringList else {
      throw SyncbaseError.DeserializationError(detail: "Unsupported data type")
    }

    let listLength = try VOM.binaryDecodeUInt(ptr, available: length)
    ptr = ptr.advancedBy(listLength.bytesRead); length -= listLength.bytesRead
    var result = [String](count: Int(listLength.value), repeatedValue: "")
    for i in 0..<Int(listLength.value) {
      let stringValue = try VOM.binaryDecodeString(ptr, available: length)
      ptr = ptr.advancedBy(stringValue.bytesRead); length -= stringValue.bytesRead
      result[i] = stringValue.value
    }
    return result
  }
}

