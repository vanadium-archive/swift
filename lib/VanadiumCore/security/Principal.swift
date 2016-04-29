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
  public static func setBlessings(vomEncodedBlessings:NSData) throws {
    let ctx = V23.instance.context
    // We can safely force this case because we know that CGO won't actually modify any of the
    // NSData's bytes.
    let cgoData = unsafeBitCast(vomEncodedBlessings.bytes, UnsafeMutablePointer<Void>.self)
    let data = SwiftByteArray(length: UInt64(vomEncodedBlessings.length), data: cgoData)
    try SwiftVError.catchAndThrowError { errPtr in
      swift_io_v_v23_security_simple_nativeSetBlessings(ctx.handle.goHandle, data, errPtr)
    }
  }

  /// Returns a string that encapsulates the current blessing of the principal. It will look
  /// something like dev.v.io:o:6183738471-jsl8jlsaj.apps.googleusercontent.com:frank@gmail.com
  public static func blessingsDebugString() throws -> String {
    let ctx = V23.instance.context
    let cstr = swift_io_v_v23_security_simple_nativeBlessingsDebugString(ctx.handle.goHandle)
    let str = String.fromCStringNoCopy(cstr, freeWhenDone: true)
    if str == nil {
      throw StringErrors.InvalidString
    }
    return str!
  }

  /// Base64 DER-encoded representation of the auto-generated public-key using Golang's URLEncoding,
  /// which is not compatible with NSData's base64 encoder/decoder.
  public static func publicKey() throws -> String {
    let str:String? = try SwiftVError.catchAndThrowError { errPtr in
      let ctx = V23.instance.context
      let cstr = swift_io_v_v23_security_simple_nativePublicKey(ctx.handle.goHandle, errPtr)
      return String.fromCStringNoCopy(cstr, freeWhenDone: true)
    }
    if str == nil {
      throw StringErrors.InvalidString
    }
    return str!
  }
}
