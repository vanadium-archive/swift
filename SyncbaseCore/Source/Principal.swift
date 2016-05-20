// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Principal gets the default app/user blessings from the default blessings store. This class is
/// for internal use only. It is used for encoding Identifier and getting the blessing store
/// debug string.
enum Principal {
  /// Returns a debug string that contains the current blessing store. For debug use only.
  static var blessingsDebugDescription: String {
    var cStr = v23_syncbase_String()
    v23_syncbase_BlessingStoreDebugString(&cStr)
    return cStr.toString() ?? "ERROR"
  }

  /// Returns the app blessing from the main context. This is used for encoding database ids.
  /// If no app blessing has been set, this throws an exception.
  static func appBlessing() throws -> String {
    let cStr: v23_syncbase_String = try VError.maybeThrow { errPtr in
      var cStr = v23_syncbase_String()
      v23_syncbase_AppBlessingFromContext(&cStr, errPtr)
      return cStr
    }
    guard let str = cStr.toString() else {
      throw SyncbaseError.NotAuthorized
    }
    return str
  }

  /// Returns the user blessing from the main context. This is used for encoding collection ids.
  /// If no user blessing has been set, this throws an exception.
  static func userBlessing() throws -> String {
    let cStr: v23_syncbase_String = try VError.maybeThrow { errPtr in
      var cStr = v23_syncbase_String()
      v23_syncbase_UserBlessingFromContext(&cStr, errPtr)
      return cStr
    }
    guard let str = cStr.toString() else {
      throw SyncbaseError.NotAuthorized
    }
    return str
  }

  /// True if the blessings have been successfully retrieved via exchanging an oauth token.
  static func blessingsAreValid() -> Bool {
    do {
      try userBlessing()
      return true
    } catch {
      return false
    }
  }
}
