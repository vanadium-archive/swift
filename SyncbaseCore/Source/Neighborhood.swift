// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Represents a peer found in the neighborhood (via Bluetooth or mDNS) using the discovery APIs.
public struct NeighborhoodPeer {
  /// The name of the application advertising itself.
  public let appName: String
  /// The blessing pattern being advertised.
  public let blessings: String
  /// If true, then we no longer can see this advertisement. If false, then we have just discovered
  /// this advertisement.
  public let isLost: Bool

  public init(appName: String, blessings: String, isLost: Bool) {
    self.appName = appName
    self.blessings = blessings
    self.isLost = isLost
  }
}

public class NeighborhoodScanHandler {
  public let onPeer: NeighborhoodPeer -> Void
  var isStopped = false
  let isStoppedMu = NSLock()

  public init(onPeer: NeighborhoodPeer -> Void) {
    self.onPeer = onPeer
  }
}

public enum Neighborhood {
  public static func startAdvertising(visibility: [BlessingPattern]) throws {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    if !Syncbase.isLoggedIn {
      throw SyncbaseError.NotLoggedIn
    }
    try VError.maybeThrow { errPtr in
      v23_syncbase_NeighborhoodStartAdvertising(try v23_syncbase_Strings(visibility), errPtr)
    }
  }

  public static func stopAdvertising() throws {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    if !Syncbase.isLoggedIn {
      throw SyncbaseError.NotLoggedIn
    }
    v23_syncbase_NeighborhoodStopAdvertising()
  }

  public static func isAdvertising() -> Bool {
    if !Syncbase.didInit || !Syncbase.isLoggedIn {
      return false
    }
    var isAdvertising = false
    v23_syncbase_NeighborhoodIsAdvertising(&isAdvertising)
    return isAdvertising
  }

  public static func startScan(handler: NeighborhoodScanHandler) throws {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    if !Syncbase.isLoggedIn {
      throw SyncbaseError.NotLoggedIn
    }
    let unmanaged = Unmanaged.passRetained(handler)
    let oHandle = UnsafeMutablePointer<Void>(unmanaged.toOpaque())
    do {
      try VError.maybeThrow { errPtr in
        v23_syncbase_NeighborhoodNewScan(
          v23_syncbase_NeighborhoodScanCallbacks(
            handle: unsafeBitCast(oHandle, UInt.self),
            onPeer: { Neighborhood.onPeer($0, peer: $1) }),
          errPtr)
      }
    } catch {
      unmanaged.release()
      throw error
    }
  }

  static func onPeer(handle: v23_syncbase_Handle, peer: v23_syncbase_AppPeer) {
    let handle = Unmanaged<NeighborhoodScanHandler>.fromOpaque(
      COpaquePointer(bitPattern: handle)).takeUnretainedValue()
    let peer = peer.extract()
    handle.onPeer(peer)
  }

  public static func stopScan(handler: NeighborhoodScanHandler) {
    handler.isStoppedMu.lock()
    defer { handler.isStoppedMu.unlock() }
    if handler.isStopped {
      // Prevent double-free.
      return
    }
    let unmanaged = Unmanaged.passUnretained(handler)
    let oHandle = UnsafeMutablePointer<Void>(unmanaged.toOpaque())
    v23_syncbase_NeighborhoodStopScan(unsafeBitCast(oHandle, UInt.self))
    unmanaged.release()
    handler.isStopped = true
  }
}