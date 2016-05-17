// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

extension Bool {
  public func toGo() -> GoUint8 { if (self) { return GoUint8(1) } else { return GoUint8(0) } }
}

extension Int {
  public func toGo() -> GoInt { return GoInt(self) }
}

extension Int32 {
  public func toGo() -> GoInt32 { return GoInt32(self) }
}

extension Int8 {
  public func toGo() -> GoInt8 { return GoInt8(self) }
}

extension Float {
  public func toGo() -> GoFloat32 { return GoFloat32(self) }
}

extension Double {
  public func toGo() -> GoFloat64 { return GoFloat64(self) }
}

extension String {
  public func toGo() -> UnsafeMutablePointer<Int8> { return UnsafeMutablePointer<Int8>((self as NSString).UTF8String) }
}

/// Currently this is unused as it's not guarunteed past 1.x cgo
//extension GoString {
//  /// Given a string optional, call a block with an UTF8 copy version of a Go String, which itself is
//  /// annotated such that that the closed string shouldn't escape this block. That way we can be
//  /// safe about making sure the underlying c-string reference stays in memory for the duration
//  /// of the pointer usage, and Swift is the one ultimately responsible for its garbage collection.
//  public static func inScope(strOpt:String?, @noescape block: GoString->Void) {
//    guard let str = strOpt else {
//      block(empty)
//      return
//    }
//
//    // We use the NSString bridge as its an order of magnitude faster than using nulTerminatedUtf8,
//    // the UTF8 views, or withCString as of Swift 2.1 (11/17/15)
//    let utf8 = (str as NSString).UTF8String
//    let goStr = GoString(p: UnsafeMutablePointer<Int8>(utf8), n: GoInt(strlen(utf8)))
//    block(goStr)
//  }
//
//  /// An empty (nil) string
//  static let empty = GoString(p: nil, n: 0)
//}

extension SwiftByteArrayArray: CollectionType, CustomDebugStringConvertible {
  public typealias Index = Int

  public var startIndex: Int {
    return 0
  }

  public var endIndex: Int {
    return count()
  }

  public subscript(i: Int) -> SwiftByteArray {
    return data[i]
  }

  public func count() -> Int { return Int(length) }

  public func dealloc() {
    for i in 0 ..< length {
      let byteArray = data[Int(i)]
      byteArray.dealloc()
    }
    data.dealloc(count())
  }

  public var debugDescription: String {
    get {
      var totalSize = 0
      for byteArray in self {
        totalSize += Int(byteArray.length)
      }
      return "[SwiftByteArrayArray length=\(length) totalHoldingSize=\(totalSize) data=\(data)]"
    }
  }
}

extension SwiftByteArray: CustomDebugStringConvertible {
  public func count() -> Int { return Int(length) }

  public func dealloc() {
    data.dealloc(count())
  }

  init(dataNoCopy data: NSData) {
    self.length = _GoUint64(data.length)
    self.data = unsafeBitCast(data.bytes, UnsafeMutablePointer<Void>.self)
  }

  public func toNSDataNoCopyNoFree() -> NSData {
    return NSData(bytesNoCopy: data, length: count(), freeWhenDone: false)
  }

  public func toNSDataNoCopyFreeWhenDone() -> NSData {
    return NSData(bytesNoCopy: data, length: count(), freeWhenDone: true)
  }

  public var debugDescription: String {
    get {
      let utf8 = NSString(
        bytes: data,
        length: Int(length),
        encoding: NSUTF8StringEncoding)
      return "[SwiftByteArray length=\(length) dataInUtf8=\(utf8)]"
    }
  }
}

extension SwiftCStringArray: CollectionType {
  public typealias Index = Int

  public var startIndex: Int {
    return 0
  }

  public var endIndex: Int {
    return count()
  }

  public subscript(i: Int) -> SwiftCString {
    return data[i]
  }

  public func count() -> Int { return Int(length) }

  init(stringsCopied strings: [String]) {
    self.length = _GoUint64(strings.count)
    self.data = unsafeBitCast(malloc(size_t(strings.count * sizeof(SwiftCString.self))),
      UnsafeMutablePointer<SwiftCString>.self)
    for i in 0 ..< strings.count {
      let string = strings[i]
      self.data[i] = SwiftCString(stringCopied: string)
    }
  }

  public mutating func dealloc() {
    for i in 0 ..< length {
      var string = data[Int(i)]
      string.dealloc()
    }
    data.dealloc(count())
    length = 0
    data = nil
  }
}

extension SwiftCString: CustomStringConvertible {
  init(stringCopied string: String) {
    let length = string.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
    let data = malloc(length)
    assert(data != nil)
    memcpy(data, (string as NSString).UTF8String, length + 1)
    self.length = _GoUint64(length)
    self.data = unsafeBitCast(data, UnsafeMutablePointer<Int8>.self)
  }

  public mutating func dealloc() {
    free(data)
    length = 0
    data = nil
  }

  public var description: String {
    return String(CString: data, encoding: NSUTF8StringEncoding)!
  }
}
