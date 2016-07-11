// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents a user.
public class User: Hashable {
  public let alias: String

  public init(alias:String) {
    self.alias = alias
  }

  public var hashValue: Int {
    return alias.hashValue
  }
}

public func == (lhs: User, rhs: User) -> Bool {
  return lhs.alias == rhs.alias
}
