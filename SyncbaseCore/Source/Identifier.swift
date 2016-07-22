// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct Identifier: Equatable {
  public let name: String
  public let blessing: String

  public init(name: String, blessing: String) {
    self.name = name
    self.blessing = blessing
  }

  /// ***Advanced users only*** encodes this identifier as needed for low-level Syncbase APIs.
  public func encode() throws -> v23_syncbase_String {
    var cStr = v23_syncbase_String()
    let id = try v23_syncbase_Id(self)
    v23_syncbase_EncodeId(id, &cStr)
    return cStr
  }

  /// ***Advanced users only*** decodes an identifier as returned from low-level Syncbase APIs.
  public static func decode(encodedId: String) throws -> Identifier {
    var cId = v23_syncbase_Id()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DecodeId(try v23_syncbase_String(encodedId), &cId, errPtr)
    }
    return cId.extract()!
  }
}

public func == (d1: Identifier, d2: Identifier) -> Bool {
  return d1.blessing == d2.blessing && d1.name == d2.name
}
