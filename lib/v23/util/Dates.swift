// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

internal extension NSDate {
  internal func isBefore(otherDate:NSDate) -> Bool {
    return otherDate.timeIntervalSinceReferenceDate < self.timeIntervalSinceReferenceDate
  }

  internal func isAfter(otherDate:NSDate) -> Bool {
    return otherDate.timeIntervalSinceReferenceDate < self.timeIntervalSinceReferenceDate
  }
}
