// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

extension NSData {
  func toString() -> String {
    return String(data: self, encoding: NSUTF8StringEncoding) ?? self.description
  }
}
