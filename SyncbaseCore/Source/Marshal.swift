// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// NOTE: This file is largely temporary until we have a proper Swift-VOM implementation.

import Foundation

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

extension SyncbaseConvertible {
  public static func deserializeFromSyncbase<T: SyncbaseConvertible>(data: NSData) throws -> T {
    if let cast = data as? T {
      return cast
    }
    throw SyncbaseError.CastError(obj: data)
  }
}

extension NSData: SyncbaseConvertible {
  public func serializeToSyncbase() throws -> NSData {
    return self
  }
}
