// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// All of this is trash to be replaced by syncbase model
class Person {
  var name: String = ""
  var imageName: String = ""

  convenience init(name: String, imageName: String) {
    self.init()
    self.name = name
    self.imageName = imageName
  }
}