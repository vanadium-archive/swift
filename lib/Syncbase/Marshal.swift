// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum JsonErrors: ErrorType {
  case ArrayContainsInvalidTypes
  case DictionaryContainsInvalidTypes
  case CastError(value: Any, target: Any)
  case EncodingError
}

public enum JsonDataType: Int {
  case Bool = 0,
    Int, Int8, Int16, Int32, Int64,
    UInt, UInt8, UInt16, UInt32, UInt64,
    Float, Double,
    String,
    Array, Dictionary,
    RawJson
}

public protocol SyncbaseJsonConvertible {
  func toSyncbaseJson() throws -> (NSData, JsonDataType)
}

/// Serializes primitives to JSON using Apple's NSJSONSerializer. This function gets around
/// Apple's limitation of requiring top
private func hackNSJsonSerializer(obj: AnyObject) throws -> NSData {
  var data: NSData?
  try SyncbaseUtil.catchObjcException {
    data = try? NSJSONSerialization.dataWithJSONObject([obj], options: [])
  }
  // Hack of first and last runes, which also happen to be single byte UTF8s
  guard data != nil else {
    throw JsonErrors.EncodingError
  }
  return data!.subdataWithRange(NSMakeRange(1, data!.length - 2))
}

extension Bool: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.Bool)
  }
}

// Wish we could put an extension on a protocol like IntegerLiterableConvertable or IntegerType
// but we can't as of Swift 2.2, so we enumerate all the possiblities

extension Int: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.Int)
  }
}

extension Int8: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(Int(self)), JsonDataType.Int8)
  }
}

extension Int16: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(Int(self)), JsonDataType.Int16)
  }
}

extension Int32: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(Int(self)), JsonDataType.Int32)
  }
}

extension Int64: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(NSNumber(longLong: self)), JsonDataType.Int64)
  }
}

extension UInt: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.UInt)
  }
}

extension UInt8: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(UInt(self)), JsonDataType.UInt8)
  }
}

extension UInt16: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(UInt(self)), JsonDataType.UInt16)
  }
}

extension UInt32: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(UInt(self)), JsonDataType.UInt32)
  }
}

extension UInt64: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(NSNumber(unsignedLongLong: self)), JsonDataType.UInt64)
  }
}

extension Float: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.Float)
  }
}

extension Double: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.Double)
  }
}

extension String: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try hackNSJsonSerializer(self), JsonDataType.String)
  }
}

// Wish we could do this:
// extension Array : SyncbaseJsonConvertible where Element: AnyObject {
// but it's not valid Swift 2.2

extension Array where Element: AnyObject {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try! NSJSONSerialization.dataWithJSONObject(self, options: []), JsonDataType.Array)
  }
}

extension NSArray: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try! NSJSONSerialization.dataWithJSONObject(self, options: []), JsonDataType.Array)
  }
}

extension NSDictionary: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (try! NSJSONSerialization.dataWithJSONObject(self, options: []), JsonDataType.Dictionary)
  }
}

// Annoyingly we can't directly cast an Array that we have no type information on into an AnyObject
// or similarly the same for Dictionary. So instead we're forced to copy all the elements and test
// all individual types inside.
extension Array: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    let copy: [AnyObject] = try self.map { elem in
      guard let jsonable = elem as? AnyObject else {
        throw JsonErrors.ArrayContainsInvalidTypes
      }
      return jsonable
    }
    var data: NSData?
    try SyncbaseUtil.catchObjcException {
      data = try? NSJSONSerialization.dataWithJSONObject(copy, options: [])
    }
    guard data != nil else {
      throw JsonErrors.EncodingError
    }
    return (data!, JsonDataType.Array)
  }
}

extension Dictionary: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    let copy = NSMutableDictionary()
    try self.forEach { (key, value) in
      guard let strKey = key as? String else {
        throw JsonErrors.DictionaryContainsInvalidTypes
      }
      guard let jsonable = value as? AnyObject else {
        throw JsonErrors.DictionaryContainsInvalidTypes
      }
      copy[strKey] = jsonable
    }

    var data: NSData?
    try SyncbaseUtil.catchObjcException {
      data = try? NSJSONSerialization.dataWithJSONObject(copy, options: [])
    }
    guard data != nil else {
      throw JsonErrors.EncodingError
    }
    return (data!, JsonDataType.Dictionary)
  }
}

extension NSData: SyncbaseJsonConvertible {
  public func toSyncbaseJson() throws -> (NSData, JsonDataType) {
    return (self, JsonDataType.RawJson)
  }
}
