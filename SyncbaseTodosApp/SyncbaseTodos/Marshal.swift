// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// NOTE: This file is largely temporary until we have a proper Swift-VOM implementation.

import Foundation
import Syncbase

protocol Jsonable {
  func toJsonable() -> [String: AnyObject]
  static func fromJsonable(data: [String: AnyObject]) -> Self?
}

extension NSData {
  func unpack<T: Jsonable>() throws -> T? {
    guard let data = try NSJSONSerialization.JSONObjectWithData(self, options: []) as? [String: AnyObject] else {
      throw SyncbaseError.CastError(obj: NSString(data: self, encoding: NSUTF8StringEncoding) ??
        self.description)
    }
    return T.fromJsonable(data)
  }

  func pack<T: Jsonable>(obj: T) throws -> NSData {
    let jsonable = obj.toJsonable()
    return try NSJSONSerialization.dataWithJSONObject(jsonable, options: [])
  }
}
