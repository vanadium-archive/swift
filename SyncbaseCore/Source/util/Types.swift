// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: Imported C structs have a default initializer in Swift that zero-initializes all fields.
// https://developer.apple.com/library/ios/releasenotes/DeveloperTools/RN-Xcode/Chapters/xc6_release_notes.html

import Foundation

extension v23_syncbase_Bool {
  init(_ bool: Bool) {
    switch bool {
    case true: self = 1
    case false: self = 0
    }
  }

  func toBool() -> Bool {
    switch self {
    case 0: return false
    default: return true
    }
  }
}

extension v23_syncbase_String {
  init?(_ string: String) {
    // TODO: If possible, make one copy instead of two, e.g. using s.getCString.
    guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
      return nil
    }
    let p = malloc(data.length)
    if p == nil {
      fatalError("Unable to allocate \(data.length) bytes")
    }
    let n = data.length
    data.getBytes(p, length: n)
    self.p = UnsafeMutablePointer<Int8>(p)
    self.n = Int32(n)
  }

  // Return value takes ownership of the memory associated with this object.
  func toString() -> String? {
    if p == nil {
      return nil
    }
    return String(bytesNoCopy: UnsafeMutablePointer<Void>(p),
      length: Int(n),
      encoding: NSUTF8StringEncoding,
      freeWhenDone: true)
  }
}

extension v23_syncbase_Strings {
  init?(_ strings: [String]) {
    let arrayBytes = strings.count * sizeof(v23_syncbase_String)
    let p = unsafeBitCast(malloc(arrayBytes), UnsafeMutablePointer<v23_syncbase_String>.self)
    if p == nil {
      fatalError("Couldn't allocate \(arrayBytes) bytes")
    }
    var i = 0
    for string in strings {
      guard let cStr = v23_syncbase_String(string) else {
        for j in 0 ..< i {
          free(p.advancedBy(j).memory.p)
        }
        free(p)
        return nil
      }
      p.advancedBy(i).memory = cStr
      i += 1
    }
    self.p = p
    self.n = Int32(strings.count)
  }

  init(_ strings: [v23_syncbase_String]) {
    let arrayBytes = strings.count * sizeof(v23_syncbase_String)
    let p = unsafeBitCast(malloc(arrayBytes), UnsafeMutablePointer<v23_syncbase_String>.self)
    if p == nil {
      fatalError("Couldn't allocate \(arrayBytes) bytes")
    }
    var i = 0
    for string in strings {
      p.advancedBy(i).memory = string
      i += 1
    }
    self.p = p
    self.n = Int32(strings.count)
  }

  // Return value takes ownership of the memory associated with this object.
  func toString() -> String? {
    if p == nil {
      return nil
    }
    return String(bytesNoCopy: UnsafeMutablePointer<Void>(p),
      length: Int(n),
      encoding: NSUTF8StringEncoding,
      freeWhenDone: true)
  }
}

extension String {
  /// Create a Cgo-passable string struct forceably (will crash if the string cannot be created).
  func toCgoString() throws -> v23_syncbase_String {
    guard let cStr = v23_syncbase_String(self) else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: self)
    }
    return cStr
  }
}

extension v23_syncbase_Bytes {
  init(_ data: NSData) {
    let p = malloc(data.length)
    if p == nil {
      fatalError("Couldn't allocate \(data.length) bytes")
    }
    let n = data.length
    data.getBytes(p, length: n)
    self.p = UnsafeMutablePointer<UInt8>(p)
    self.n = Int32(n)
  }

  // Return value takes ownership of the memory associated with this object.
  func toNSData() -> NSData? {
    if p == nil {
      return nil
    }
    return NSData(bytesNoCopy: UnsafeMutablePointer<Void>(p), length: Int(n), freeWhenDone: true)
  }
}

// Note, we don't define init?(VError) since we never pass Swift VError objects to Go.
extension v23_syncbase_VError {
  // Return value takes ownership of the memory associated with this object.
  func toVError() -> VError? {
    if id.p == nil {
      return nil
    }
    // Take ownership of all memory before checking optionals.
    let vId = id.toString(), vMsg = msg.toString(), vStack = stack.toString()
    // TODO: Stop requiring id, msg, and stack to be valid UTF8?
    return VError(id: vId!, actionCode: actionCode, msg: vMsg!, stack: vStack!)
  }
}

public struct VError: ErrorType {
  public let id: String
  public let actionCode: UInt32
  public let msg: String
  public let stack: String

  static func maybeThrow<T>(@noescape f: UnsafeMutablePointer<v23_syncbase_VError> throws -> T) throws -> T {
    var e = v23_syncbase_VError()
    let res = try f(&e)
    if let err = e.toVError() {
      throw err
    }
    return res
  }
}

extension v23_syncbase_Ids {
  func toIdentifiers() -> [Identifier] {
    var ids: [Identifier] = []
    for i in 0 ..< n {
      let idStruct = p.advancedBy(Int(i)).memory
      if let id = idStruct.toIdentifier() {
        ids.append(id)
      }
    }
    if p != nil {
      free(p)
    }
    return ids
  }
}

extension v23_syncbase_Id {
  init?(_ id: Identifier) {
    do {
      self.name = try id.name.toCgoString()
      self.blessing = try id.blessing.toCgoString()
    } catch (let e) {
      log.warning("Unable to UTF8-encode id: \(e)")
      return nil
    }
  }

  func toIdentifier() -> Identifier? {
    guard let name = name.toString(),
      let blessing = blessing.toString() else {
        return nil
    }
    return Identifier(name: name, blessing: blessing)
  }
}

extension v23_syncbase_Permissions {
  init?(_ permissions: Permissions?) {
    guard let p = permissions where !p.isEmpty else {
      // Zero-value constructor.
      self.json = v23_syncbase_Bytes()
      return
    }
    var m = [String: AnyObject]()
    for (key, value) in p {
      m[key as String] = (value as AccessList).toJsonable()
    }
    do {
      let serialized = try NSJSONSerialization.serialize(m)
      let bytes = v23_syncbase_Bytes(serialized)
      self.json = bytes
    } catch {
      log.warning("Unable to serialize permissions: \(permissions)")
      return nil
    }
  }
}
