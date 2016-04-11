// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

internal extension String {
  internal static func fromCStringNoCopy(ptr:UnsafeMutablePointer<Int8>, freeWhenDone:Bool) -> String? {
    return String.init(bytesNoCopy: ptr, length: Int(strlen(ptr)),
      encoding: NSUTF8StringEncoding, freeWhenDone: true)
  }
}

public enum StringErrors : ErrorType {
  case InvalidString
}