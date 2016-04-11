// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

import Alamofire
import VanadiumCore

public protocol VanadiumBlesser {
  func blessingsFromGoogle(googleOauthToken:String) -> Promise<NSData>
}

enum VanadiumUrls : String, URLStringConvertible {
  case DevBlessings = "https://dev.v.io/auth/google/bless"

  var URLString: String {
    return self.rawValue.URLString
  }
}

enum BlessingOutputFormat : String {
  case Base64VOM = "base64vom"
}

public enum VanadiumBlesserError : ErrorType {
  case EmptyResult
  case NotBase64Encoded(invalid:String)
}

public extension VanadiumBlesser {
  public func blessingsFromGoogle(googleOauthToken:String) -> Promise<NSData> {
    // Make sure the Syncbase instance exists, which inits V23
    let _ = Syncbase.instance
    let p = Promise<NSData>()
    do {
      let params:[String:AnyObject] = [
          "token": googleOauthToken,
          "public_key": try VanadiumCore.Principal.publicKey(),
          "output_format": BlessingOutputFormat.Base64VOM.rawValue]
      let request = Alamofire.request(.GET,
                        VanadiumUrls.DevBlessings,
                        parameters: params,
                        encoding: ParameterEncoding.URLEncodedInURL,
                        headers:nil)
      request.responseString { resp in
        guard let base64 = resp.result.value else {
          if let err = resp.result.error {
            try! p.reject(err)
          } else {
            try! p.reject(VanadiumBlesserError.EmptyResult)
          }
          return
        }

        // The base64 values are encoded using Go's URL-variant of base64 encoding, which is not
        // compatible with Apple's base64 encoder/decoder. So we call out to to Go directly to
        // decode this value into the vom-encoded byte array.
        let swiftArray = swift_io_v_swift_impl_util_type_nativeBase64UrlDecode(base64.toGo())
        if swiftArray.length == 0 {
          try! p.reject(VanadiumBlesserError.NotBase64Encoded(invalid: base64))
          return
        }
        let data = swiftArray.toNSDataNoCopyFreeWhenDone()
        try! p.resolve(data)
      }
    } catch let err {
      try! p.reject(err)
    }
    return p
  }
}

public protocol OAuthCredentials {
  var oauthToken:String { get }
}

public struct GoogleCredentials : OAuthCredentials, VanadiumBlesser {
  public let oauthToken: String

  public init(oauthToken: String) {
    self.oauthToken = oauthToken
  }

  public func authorize() -> Promise<Void> {
    return blessingsFromGoogle(oauthToken).thenInBackground { blessings in
      try VanadiumCore.Principal.setBlessings(blessings)
    }
  }
}
