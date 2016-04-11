// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit

protocol DemoDescription : CustomStringConvertible {
  var segue: String { get }
  var instance: Demo { get }
}

protocol Demo {
  mutating func start()
}
