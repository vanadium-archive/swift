// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

protocol Lockable {
  func lock(block:()->())
}

extension Lockable where Self : AnyObject {
  func lock(block:()->()) {
    objc_sync_enter(self)
    block()
    objc_sync_exit(self)
  }
}