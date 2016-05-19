// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct Identifier {
  public let name: String
  public let blessing: String

  public init(name: String, blessing: String) {
    self.name = name
    self.blessing = blessing
  }

  func encodeId() throws -> v23_syncbase_String {
    var cStr = v23_syncbase_String()
    guard let id = v23_syncbase_Id(self) else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: "\(self)")
    }
    v23_syncbase_EncodeId(id, &cStr)
    return cStr
  }
}

public func == (d1: Identifier, d2: Identifier) -> Bool {
  return d1.blessing == d2.blessing && d1.name == d2.name
}
