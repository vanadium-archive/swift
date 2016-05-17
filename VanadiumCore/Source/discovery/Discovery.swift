// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum Security {
  /// BlessingPattern is a pattern that is matched by specific blessings.
  ///
  /// A pattern can either be a blessing (slash-separated human-readable string)
  /// or a blessing ending in "/$". A pattern ending in "/$" is matched exactly
  /// by the blessing specified by the pattern string with the "/$" suffix stripped
  /// out. For example, the pattern "a/b/c/$" is matched by exactly by the blessing
  /// "a/b/c".
  ///
  /// A pattern not ending in "/$" is more permissive, and is also matched by blessings
  /// that are extensions of the pattern (including the pattern itself). For example, the
  /// pattern "a/b/c" is matched by the blessings "a/b/c", "a/b/c/x", "a/b/c/x/y", etc.
  ///
  /// TODO(ataly, ashankar): Define a formal BNF grammar for blessings and blessing patterns.
  public typealias BlessingPattern = String

  static let AllPrincipals = BlessingPattern("...") // Glob pattern that matches all blessings.
}

public struct Discovery {
  internal let context: Context
  internal let handle: DiscoveryHandle
  internal class DiscoveryHandle: CustomStringConvertible, CustomDebugStringConvertible {
    internal let goHandle: GoDiscoveryHandle

    internal init(_ goHandle: GoDiscoveryHandle) {
      self.goHandle = goHandle
    }

    deinit {
      if goHandle != 0 {
        swift_io_v_v23_discovery_finalize(goHandle)
      }
    }

    var description: String { return "[DiscoveryHandle \(goHandle)]" }
    var debugDescription: String { return "[DiscoveryHandle handle=\(goHandle)]" }
  }

  public init?(context: Context) {
    do {
      let handle = try SwiftVError.catchAndThrowError { err in
        return swift_io_v_v23_discovery_new(context.handle.goHandle, err)
      }
      self.context = context
      self.handle = DiscoveryHandle(handle)
    } catch (let e) {
      log.warning("Unable to create discovery: \(e)")
      return nil
    }
  }

  private static let outstandingAdvertisements = GoPromises<Void>(timeout: nil)

  /// Called when advertising is done
  public typealias OnDone = Void -> Void

  /// Advertise broadcasts the advertisement to be discovered by "Scan" operations.
  ///
  /// visibility is used to limit the principals that can see the advertisement. An
  /// empty set means that there are no restrictions on visibility (i.e, equivalent
  /// to [Security.AllPrincipals].
  ///
  /// If the advertisement id is not specified, a random unique a random unique identifier
  /// will be assigned. The advertisement should not be changed while it is being advertised.
  ///
  /// It is an error to have simultaneously active advertisements for two identical
  /// instances (Advertisement.Id).
  ///
  /// Advertising will continue until the context is canceled or exceeds its deadline
  /// and then onDone will be called.
  ///
  /// Will throw a VError if unable to start advertising -- onDone will not be called if thrown.
  public func advertise(ad: Advertisement, visibility: [Security.BlessingPattern]?, onDone: OnDone) throws {
    let adJsonData = try NSJSONSerialization.dataWithJSONObject(ad.toJsonable(), options: [])
    let adJson = SwiftByteArray(dataNoCopy: adJsonData)
    let visibilityStrings: [String] = visibility ?? []
    var visibilityArray = SwiftCStringArray(stringsCopied: visibilityStrings)
    defer { visibilityArray.dealloc() }
    let (asyncId, p) = Discovery.outstandingAdvertisements.newPromise()
    p.onResolve { _ in onDone() }
    try SwiftVError.catchAndThrowError { err in
      swift_io_v_v23_discovery_advertise(context.handle.goHandle,
        handle.goHandle,
        adJson,
        visibilityArray,
        asyncId, { asyncId in Discovery.onDoneCallback(asyncId) },
        err)
    }
  }

  private static func onDoneCallback(asyncId: AsyncCallbackIdentifier) {
    if let p = Discovery.outstandingAdvertisements.getAndDeleteRef(asyncId) {
      RunOnMain {
        do {
          try p.resolve()
        } catch let e {
          log.warning("Unable to resolve onDone: \(e)")
        }
      }
    }
  }

  private static let outstandingScans = GoAsyncHandle<OnUpdate>()

  /// Callback on discovery updates. When scanning is cancelled the update will be nil and
  /// isScanDone will be true.
  public typealias OnUpdate = (update: Update?, isScanDone: Bool) -> Void

  /// Scan scans advertisements that match the query and returns the channel of updates.
  ///
  /// Scan excludes the advertisements that are advertised from the same discovery
  /// instance.
  ///
  /// The query is a WHERE expression of a syncQL query against advertisements, where
  /// key is Advertisement.Id and value is Advertisement.
  ///
  /// Will call the JSON update callback with an empty byte arraywhen done, signaling
  /// to Swift that it may free the function pointer.
  ///
  /// Examples
  ///
  /// v.InterfaceName = "v.io/i"
  /// v.InterfaceName = "v.io/i" AND v.Attributes["a"] = "v"
  /// v.Attributes["a"] = "v1" OR v.Attributes["a"] = "v2"
  ///
  /// SyncQL tutorial at:
  /// https://vanadium.github.io/tutorials/syncbase/syncql-tutorial.html
  ///
  public func scan(query: String, onUpdate: OnUpdate) throws {
    var cQuery = SwiftCString(stringCopied: query)
    defer { cQuery.dealloc() }
    let asyncId = Discovery.outstandingScans.newRef(onUpdate)
    try SwiftVError.catchAndThrowError { err in
      swift_io_v_v23_discovery_scan(context.handle.goHandle,
        handle.goHandle,
        cQuery,
        asyncId, { asyncId, json in Discovery.onUpdateCallback(asyncId, json: json) },
        err)
    }
  }

  private static func onUpdateCallback(asyncId: AsyncCallbackIdentifier, json: SwiftByteArray) {
    if json.length == 0 || json.data == nil {
      // We're done
      guard let callback = outstandingScans.getAndDeleteRef(asyncId) else {
        return
      }
      callback(update: nil, isScanDone: true)
    } else {
      // We got an update
      guard let callback = outstandingScans.getRef(asyncId) else {
        return
      }
      guard let data = try? NSJSONSerialization.JSONObjectWithData(json.toNSDataNoCopyNoFree(), options: []) as? [String: AnyObject],
        let update = try? Update.fromJsonable(data!) else {
          let str = String(data: json.toNSDataNoCopyNoFree(), encoding: NSUTF8StringEncoding)
          log.warning("Unable to json deserialize: \(str)")
          return
      }
      RunOnMain { callback(update: update, isScanDone: false) }
    }
  }

  /// Update is the struct for a discovery update.
  public struct Update {
    /// IsLost returns true when this update corresponds to an advertisement
    /// that led to a previous update vanishing.
    public let isLost: Bool

    /// Id returns the universal unique identifier of the advertisement.
    public var adId: Advertisement.AdId {
      return advertisement.adId!
    }

    /// InterfaceName returns the interface name that the service implements.
    public var interfaceName: String {
      return advertisement.interfaceName
    }

    /// Addresses returns the addresses (vanadium object names) that the service
    /// is served on.
    public var addresses: [String] {
      return advertisement.addresses
    }

    // Attribute returns the named attribute. An empty string is returned if
    // not found.
//    public func attribute(name: String) -> String {
//    }

    // Attachment returns the channel on which the named attachment can be read.
    // Nil data is returned if not found.
    //
    // This may do RPC calls if the attachment is not fetched yet and fetching
    // will fail if the context is canceled or exceeds its deadline.
    //
    // Attachments may not be available when this update is for lost advertisement.
//    public Attachment(ctx * context.T, name string) <- chan DataOrError

    /// Advertisement returns a copy of the advertisement that this update
    /// corresponds to.
    ///
    /// The returned advertisement may not include all attachments.
    public let advertisement: Advertisement

    public enum JsonErrors: ErrorType {
      case InvalidJsonData
    }

    internal static func fromJsonable(data: [String: AnyObject]) throws -> Update {
      guard let isLost = data["IsLost"] as? Bool,
        adObj = data["Ad"] as? [String: AnyObject] else {
          throw JsonErrors.InvalidJsonData
      }
      let ad = try Advertisement.fromJsonable(adObj)
      return Update(isLost: isLost, advertisement: ad)
    }
  }
}
