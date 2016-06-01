// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// All of this is trash to be replaced by syncbase model
class Task {
  var text: String = ""
  var addedAt: NSDate = NSDate()
  var done: Bool = false

  convenience init(text: String) {
    self.init()
    self.text = text
  }

  convenience init(text: String, done: Bool) {
    self.init()
    self.text = text
    self.done = done
  }
}