// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Uniquely identifies a database, collection, or syncgroup.
public struct Identifier: Hashable {
  public let name: String
  public let blessing: String

  public init(name: String, blessing: String) {
    self.name = name
    self.blessing = blessing
  }

  init(coreId: SyncbaseCore.Identifier) {
    self.name = coreId.name
    self.blessing = coreId.blessing
  }

  public func encode() throws -> String {
    // If there was a UTF-8 problem, it would have been thrown when UTF-8 encoding core's call
    // to CGO. Therefore, we can be confident in unwrapping the conditional here.
    return try toCore().encode().extract()!
  }

  public static func decode(encodedId: String) throws -> Identifier {
    return Identifier(coreId: try SyncbaseCore.Identifier.decode(encodedId))
  }

  public var hashValue: Int {
    var result = 1
    let prime = 31
    result = prime &* result &+ blessing.hashValue
    result = prime &* result &+ name.hashValue
    return result
  }

  public var description: String {
    return "Id(\(try? encode() ?? "<UTF-8 ERROR>"))"
  }

  func toCore() -> SyncbaseCore.Identifier {
    return SyncbaseCore.Identifier(name: name, blessing: blessing)
  }
}

public func == (d1: Identifier, d2: Identifier) -> Bool {
  return d1.blessing == d2.blessing && d1.name == d2.name
}
