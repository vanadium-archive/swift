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
    var cStr = v23_syncbase_String()
    let id = try v23_syncbase_Id(toCore())
    v23_syncbase_EncodeId(id, &cStr)
    // If there was a UTF-8 problem, it would have been thrown when UTF-8 encoding the id above.
    // Therefore, we can be confident in unwrapping the conditional here.
    return cStr.toString()!
  }

  // TODO(zinman): Replace decode method implementations with call to Cgo.
  static let separator = ","
  public static func decode(encodedId: String) throws -> Identifier {
    let parts = encodedId.componentsSeparatedByString(separator)
    if parts.count != 2 {
      throw SyncbaseError.IllegalArgument(detail: "Invalid encoded id: \(encodedId)")
    }
    let (blessing, name) = (parts[0], parts[1])
    return Identifier(name: name, blessing: blessing)
  }

  public var hashValue: Int {
    // Note: Copied from VDL.
    var result = 1
    let prime = 31
    result = prime * result + blessing.hashValue
    result = prime * result + name.hashValue
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
