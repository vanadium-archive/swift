// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Principal houses the basic tools for blessing the principal, which is to say it
/// contains the functions needed for authentication between devices/users.
public enum Principal {
  /// Sets the blessing for the principal. This blessing must be VOM encoded, and is typically
  /// provided by a Vanadium-service over HTTP (for example exchanging an oauth token for a V23
  /// blessing).
  public static func setBlessings(vomEncodedBlessings: NSData) throws {
    // We can safely force this case because we know that CGO won't actually modify any of the
    // NSData's bytes.
    let data = v23_syncbase_Bytes(vomEncodedBlessings)
    try VError.maybeThrow { errPtr in
      v23_syncbase_SetVomEncodedBlessings(data, errPtr)
    }
  }

  /// Returns a string that encapsulates the current blessing of the principal. It will look
  /// something like dev.v.io:o:6183738471-jsl8jlsaj.apps.googleusercontent.com:frank@gmail.com
  public static func blessingsDebugString() -> String? {
    var cStr = v23_syncbase_String()
    v23_syncbase_BlessingsStoreDebugString(&cStr)
    let str = cStr.toString()
    log.debug("Got back blessings: \(str)")
    return str
  }

  /// Returns the user blessings from the main context. This can be used for collection blessings
  /// in constructing CollectionIds.
  public static func userBlessings() throws -> String {
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

  public static func appBlessings() throws -> String {
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

  public static func hasValidBlessings() -> Bool {
    var b = v23_syncbase_Bool(false)
    v23_syncbase_HasValidBlessings(&b)
    return b.toBool()
  }

  /// Base64 DER-encoded representation of the auto-generated public-key using Golang's URLEncoding,
  /// which is not compatible with NSData's base64 encoder/decoder.
  public static func publicKey() throws -> String {
    let str: String? = try VError.maybeThrow { errPtr in
      var cStr = v23_syncbase_String()
      v23_syncbase_PublicKey(&cStr, errPtr)
      return cStr.toString()
    }
    // We know this works, and should crash if it doesn't as it's unexpected behavior.
    return str!
  }
}
