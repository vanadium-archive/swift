// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

extension String {
  static func fromCStringNoCopy(ptr: UnsafeMutablePointer<Int8>, freeWhenDone: Bool) -> String? {
    return String.init(bytesNoCopy: ptr, length: Int(strlen(ptr)),
      encoding: NSUTF8StringEncoding, freeWhenDone: true)
  }
}