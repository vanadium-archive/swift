// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

extension NSArray {
  func toNSData() -> NSData {
    var bytes = (self as! [NSNumber]).map { $0.unsignedCharValue }
    let dst = unsafeBitCast(malloc(bytes.count), UnsafeMutablePointer<UInt8>.self)
    for i in 0 ..< bytes.count {
      dst[i] = bytes[i]
    }
    return NSData(bytesNoCopy: dst, length: bytes.count, freeWhenDone: true)
  }
}