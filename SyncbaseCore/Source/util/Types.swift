// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: Imported C structs have a default initializer in Swift that zero-initializes all fields.
// https://developer.apple.com/library/ios/releasenotes/DeveloperTools/RN-Xcode/Chapters/xc6_release_notes.html

import Foundation

extension v23_syncbase_String {
  init?(s: String) {
    // TODO: If possible, make one copy instead of two, e.g. using s.getCString.
    guard let data = s.dataUsingEncoding(NSUTF8StringEncoding) else {
      return nil
    }
    let p = malloc(data.length)
    if p == nil {
      return nil
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

extension v23_syncbase_Bytes {
  init?(data: NSData) {
    let p = malloc(data.length)
    if p == nil {
      return nil
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

  static func maybeThrow<T>(@noescape f: UnsafeMutablePointer<v23_syncbase_VError> -> T) throws -> T {
    var e = v23_syncbase_VError()
    let res = f(&e)
    if let err = e.toVError() {
      throw err
    }
    return res
  }
}
