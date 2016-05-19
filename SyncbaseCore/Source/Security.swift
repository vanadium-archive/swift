// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import Alamofire

public protocol VanadiumBlesser {
  func blessingsFromGoogle(googleOauthToken: String, callback: (NSData?, ErrorType?) -> Void)
}

enum VanadiumUrls: String, URLStringConvertible {
  case DevBlessings = "https://dev.v.io/auth/google/bless"

  var URLString: String {
    return self.rawValue.URLString
  }
}

enum BlessingOutputFormat: String {
  case Base64VOM = "base64vom"
}

public enum VanadiumBlesserError: ErrorType {
  case EmptyResult
  case GatewayTimeout
  case InvalidHttpResponse(statusCode: Int)
  case NotBase64Encoded(invalid: String)
}

public extension VanadiumBlesser {
  public func blessingsFromGoogle(googleOauthToken: String, callback: (NSData?, ErrorType?) -> Void) {
    // Make sure the Syncbase instance exists, which inits V23
    let _ = Syncbase.instance
    do {
      let params: [String: AnyObject] = [
        "token": googleOauthToken,
        "public_key": try Principal.publicKey(),
        "output_format": BlessingOutputFormat.Base64VOM.rawValue]
      let request = Alamofire.request(.GET,
        VanadiumUrls.DevBlessings,
        parameters: params,
        encoding: ParameterEncoding.URLEncodedInURL,
        headers: nil)
      request.responseString { resp in
        guard let base64 = resp.result.value,
          let response = resp.response where response.statusCode == 200 else {
            if let err = resp.result.error {
              callback(nil, err)
            } else if let code = resp.response?.statusCode {
              switch code {
              case 504: callback(nil, VanadiumBlesserError.GatewayTimeout)
              default: callback(nil, VanadiumBlesserError.InvalidHttpResponse(statusCode: code))
              }
            } else {
              callback(nil, VanadiumBlesserError.EmptyResult)
            }
            return
        }

        // The base64 values are encoded using Go's URL-variant of base64 encoding, which is not
        // compatible with Apple's base64 encoder/decoder. So we call out to to Go directly to
        // decode this value into the vom-encoded byte array.
        var cErr = v23_syncbase_VError()
        var cData = v23_syncbase_Bytes()
        guard let cBase64 = try? base64.toCgoString() else {
          callback(nil, VanadiumBlesserError.EmptyResult)
          return
        }
        v23_syncbase_Base64UrlDecode(cBase64, &cData, &cErr)
        if let err = cErr.toVError() {
          callback(nil, err)
          return
        }
        guard let data = cData.toNSData() else {
          callback(nil, VanadiumBlesserError.EmptyResult)
          return
        }
        callback(data, nil)
      }
    } catch let err {
      callback(nil, err)
    }
  }
}

public protocol OAuthCredentials {
  var oauthToken: String { get }
}

public struct GoogleCredentials: OAuthCredentials, VanadiumBlesser {
  public let oauthToken: String

  public init(oauthToken: String) {
    self.oauthToken = oauthToken
  }

  public func authorize(callback: ErrorType? -> Void) {
    blessingsFromGoogle(oauthToken) { (blessings, errOpt) in
      if let err = errOpt {
        callback(err)
      } else {
        do {
          try Principal.setBlessings(blessings!)
          callback(nil)
        } catch (let e) {
          callback(e)
        }
      }
    }
  }
}
