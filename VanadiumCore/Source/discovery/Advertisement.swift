// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct Advertisement {
  public typealias AdId = NSData // size 16
  public typealias Attributes = [String: String]
  public typealias Attachments = [String: NSData]

  /// Universal unique identifier of the advertisement.
  /// If this is not specified, a random unique identifier will be assigned.
  public let adId: AdId?

  /// Interface name that the advertised service implements.
  /// E.g., 'v.io/v23/services/vtrace.Store'.
  public let interfaceName: String

  /// Addresses (vanadium object names) that the advertised service is served on.
  /// E.g., '/host:port/a/b/c', '/ns.dev.v.io:8101/blah/blah'.
  public let addresses: [String]

  /// Attributes as a key/value pair.
  /// E.g., {'resolution': '1024x768'}.
  ///
  /// The key must be US-ASCII printable characters, excluding the '=' character
  /// and should not start with '_' character.
  ///
  /// We limit the maximum number of attachments to 32.
  public let attributes: Attributes?

  /// Attachments as a key/value pair.
  /// E.g., {'thumbnail': binary_data }.
  ///
  /// Unlike attributes, attachments are for binary data and they are not queryable.
  ///
  /// The key must be US-ASCII printable characters, excluding the '=' character
  /// and should not start with '_' character.
  ///
  /// We limit the maximum number of attachments to 32 and the maximum size of each
  /// attachment is 4K bytes.
  public let attachments: Attachments?

  public init(id adId: AdId?, interfaceName: String, addresses: [String], attributes: Attributes? = nil, attachments: Attachments? = nil) {
    self.adId = adId
    self.interfaceName = interfaceName
    self.addresses = addresses
    self.attributes = attributes
    self.attachments = attachments
  }

  public func toJsonable() -> [String: AnyObject] {
    var json = [String: AnyObject]()
    if let id = adId {
      json["Id"] = id.base64EncodedStringWithOptions([])
    }
    json["InterfaceName"] = interfaceName
    json["Addresses"] = addresses
    if let attrs = attributes {
      json["Attributes"] = attrs
    }
    if let a = attachments {
      var attachments = [String: String]()
      for (key, data) in a {
        attachments[key] = data.base64EncodedStringWithOptions([])
      }
      json["Attachments"] = attachments
    }
    return json
  }

  public enum JsonErrors: ErrorType {
    case InvalidJsonData
  }

  public static func fromJsonable(data: [String: AnyObject]) throws -> Advertisement {
    guard let adIdBytes = data["Id"] as? NSArray,
      let ifaceName = data["InterfaceName"] as? String,
      let addresses = data["Addresses"] as? [String],
      let attributes = data["Attributes"] as? [String: String]?,
      let attachmentsBytes = data["Attachments"] as? [String: NSArray]? else {
        throw JsonErrors.InvalidJsonData
    }
    let adId = adIdBytes.toNSData()
    let attachments = attachmentsBytes?.reduce([String: NSData](), combine: { (acc, elem) in
      var ret = acc
      ret[elem.0] = elem.1.toNSData()
      return ret
    })
    return Advertisement(
      id: adId,
      interfaceName: ifaceName,
      addresses: addresses,
      attributes: attributes,
      attachments: attachments)
  }
}
