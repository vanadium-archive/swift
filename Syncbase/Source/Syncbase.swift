// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Syncbase is a storage system for developers that makes it easy to synchronize app data between
/// devices. It works even when devices are not connected to the Internet.
public enum Syncbase {
  // Constants
  static let DbName = "db"
  public static let UserdataSyncgroupName = "userdata__",
    UserdataCollectionPrefix = "__collections/"
  // Initialization state
  static var isUnitTest = false
  static var didInit = false
  static var didPostLogin = false
  static var didStartShutdown = false
  // Main database.
  static var db: Database?
  // The userdata collection, created post-login.
  static var userdataCollection: Collection?
  // Options for opening a database.
  static var cloudName: String?
  static var cloudBlessing: String?
  static var disableSyncgroupPublishing = false
  static var disableUserdataSyncgroup = false
  static var mountPoints: [String] = []
  /// Queue used to dispatch all asynchronous callbacks. Defaults to main.
  public static var queue: dispatch_queue_t {
    // Map directly to SyncbaseCore.
    get {
      return SyncbaseCore.Syncbase.queue
    }
    set(queue) {
      SyncbaseCore.Syncbase.queue = queue
    }
  }

  static public var defaultRootDir: String {
    return NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("Syncbase")
      .path!
  }

  static var publishSyncbaseName: String? {
    if disableSyncgroupPublishing {
      return nil
    }
    if usesCloud {
      return cloudName
    }
    return nil
  }

  static var usesCloud: Bool {
    return cloudName != nil && cloudBlessing != nil
  }

  /// Starts Syncbase if needed; creates default database if needed; performs create-or-join for
  /// "userdata" syncgroup if needed.
  ///
  /// The "userdata" collection is a per-user collection (and associated syncgroup) for data that
  /// should automatically get synced across a given user's devices. It has the following schema:
  /// - `/syncgroups/{encodedSyncgroupId}` -> `nil`
  /// - `/ignoredInvites/{encodedSyncgroupId}` -> `nil`
  ///
  /// Cloud usage is optional. It can be used for initial bootstrapping and increased data
  /// availability. Apps that use a cloud will automatically synchronize data across all of the same
  /// user's devices. To allocate a cloud instance of Syncbase, visit https://sb-allocator.v.io/home
  /// to create your instance. There you'll be able to see the parameters for `cloudName` and
  /// `cloudBlessing` parameters. After that, please complete the following steps (until we the
  /// webpage includes similar functionality, see https://github.com/vanadium/issues/issues/1414):

  /// 1. Install Vanadium from https://vanadium.github.io/installation/
  ///
  /// 2. Install the principal & sb binaries
  /// `jiri go install v.io/...`
  ///
  /// 3. Create your principal
  /// `$JIRI_ROOT/release/go/bin/principal create $JIRI_ROOT/.v23creds`
  ///
  /// 4. Bless it via OAuth. On the Vanadium blessings page, just click bless.
  /// `$JIRI_ROOT/release/go/bin/principal -v23.credentials=$JIRI_ROOT/.v23creds seekblessings`
  ///
  /// 5. Create the shared database using the app client id blessing. Notice the , in the id...
  /// it's _blessing_,db
  /// `$JIRI_ROOT/release/go/bin/sb --v23.credentials=$JIRI_ROOT/.v23creds \
  /// -service=/ns.dev.v.io:8101/sb/syncbased-<SYNCBASEID> -create-if-absent=true \
  /// --db dev.v.io:o:<GOOGLE SIGNIN CLIENTID>,db`
  ///
  /// 6. At this point you can go to sb-allocator.v.io, click debug on your instance,
  /// click Syncbase in the upper right, then verify the database was created. You can't currently
  /// view the collections or syncgroups as the website is not authenticated to show them.
  ///
  /// - parameter rootDir:                     Where data should be persisted.
  /// - parameter cloudName:                   Name of the cloud. See https://sb-allocator.v.io/home
  /// - parameter cloudBlessing:               The cloud's blessing pattern. See https://sb-allocator.v.io/home
  /// - parameter mountPoints:                 // TODO(zinman): Get appropriate documentation on mountPoints
  /// - parameter disableSyncgroupPublishing:  **FOR ADVANCED USERS**. If true, syncgroups will not be published to the cloud peer.
  /// - parameter disableUserdataSyncgroup:    **FOR ADVANCED USERS**. If true, the user's data will not be synced across their devices.
  /// - parameter callback:                    Called on `Syncbase.queue` with either `Database` if successful, or an error if unsuccessful.
  public static func configure(
    // Default to Application Support/Syncbase.
    rootDir rootDir: String = defaultRootDir,
    cloudName: String? = nil,
    cloudBlessing: String? = nil,
    mountPoints: [String],
    disableSyncgroupPublishing: Bool = false,
    disableUserdataSyncgroup: Bool = false,
    queue: dispatch_queue_t = dispatch_get_main_queue()) throws {
      if Syncbase.didInit {
        throw SyncbaseError.AlreadyConfigured
      }
      Syncbase.cloudName = cloudName
      Syncbase.cloudBlessing = cloudBlessing
      Syncbase.mountPoints = mountPoints
      Syncbase.disableSyncgroupPublishing = disableSyncgroupPublishing
      Syncbase.disableUserdataSyncgroup = disableUserdataSyncgroup
      Syncbase.didPostLogin = false
      Syncbase.didStartShutdown = false
      // We don't need to set Syncbase.queue as it is a proxy for SyncbaseCore's queue, which is
      // set in the configure below.
      try SyncbaseError.wrap {
        try SyncbaseCore.Syncbase.configure(rootDir: rootDir, queue: queue)
      }
      // We use SyncbaseCore's isLoggedIn because this frameworks would fail as didInit hasn't
      // been set to true yet.
      if (SyncbaseCore.Syncbase.isLoggedIn) {
        do {
          try Syncbase.postLoginCreateDefaults()
        } catch let e {
          // If we get an exception after configuring the low-level API, make sure we shutdown
          // Syncbase so that any subsequent call to this configure method doesn't get a
          // SyncbaseError.AlreadyConfigured exception from SyncbaseCore.Syncbase.configure.
          Syncbase.shutdown()
          throw e
        }
      }
      Syncbase.didInit = true
  }

  /// Shuts down the Syncbase service. You must call configure again before any calls will work.
  public static func shutdown() {
    Syncbase.didStartShutdown = true
    SyncbaseCore.Syncbase.shutdown()
    Syncbase.didInit = false
    Syncbase.didPostLogin = false
  }

  private static func postLoginCreateDefaults() throws {
    let coreDb = try SyncbaseCore.Syncbase.database(Syncbase.DbName)
    let database = Database(coreDatabase: coreDb)
    try database.createIfMissing()
    userdataCollection = try database.createCollection(
      name: Syncbase.UserdataSyncgroupName, withoutSyncgroup: true)
    // We only create a userdata syncgroup if we use the cloud (or we're in a unit test).
    if (usesCloud || isUnitTest) && !Syncbase.disableUserdataSyncgroup {
      let syncgroup = try userdataCollection!.syncgroup()
      do {
        // TODO(zinman): Return (via throwing) if this fails because the cloud isn't accessible,
        // instead of it failing because a join isn't possible.
        try syncgroup.join()
      } catch {
        // The above join() will fail the first time the user logs in and we create the syncgroup
        // UNLESS another device of the same user is available to discovery (nearby or connected
        // via some network path). If so, then the join will work. In subsequent boots join() will
        // not throw and we won't re-attempt creation.
        try syncgroup.createIfMissing([userdataCollection!])
      }
      // TODO(zinman): Figure out when/how this can throw and if we should handle it better.
      try database.addInternalUserdataWatchChangeHandler(
        handler: WatchChangeHandler(
          onInitialState: onUserdataWatchChange,
          onChangeBatch: onUserdataWatchChange,
          onError: { err in
            if !Syncbase.didStartShutdown {
              NSLog("Syncbase - Error watching userdata syncgroups: %@", "\(err)")
            }
        }))
    }

    Syncbase.db = database
    Syncbase.didPostLogin = true
  }

  private static func onUserdataWatchChange(changes: [WatchChange]) {
    for change in changes {
      guard let row = change.row where change.entityType == .Row && change.changeType == .Put else {
        continue
      }
      guard let syncgroupId = try? Identifier.decode(
        row.stringByReplacingOccurrencesOfString(Syncbase.UserdataCollectionPrefix, withString: "")) else {
          print("Syncbase - Unable to decode userdata key: (row)")
          continue
      }
      do {
        let syncgroup = try Syncbase.database().syncgroup(syncgroupId)
        try syncgroup.join()
      } catch {
        NSLog("Syncbase - Error joining syncgroup \(syncgroupId): %@", "\(error)")
      }
    }
  }

  static func addSyncgroupToUserdata(syncgroupId: Identifier) throws {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    if !Syncbase.didPostLogin {
      throw SyncbaseError.NotLoggedIn
    }
    guard let userdataCollection = Syncbase.userdataCollection else {
      throw SyncbaseError.IllegalArgument(detail: "No user data collection")
    }
    try userdataCollection.put(try Syncbase.UserdataCollectionPrefix + syncgroupId.encode(), value: NSData())
  }

  /// Returns the shared database handle. Must have already called `configure` and be logged in,
  /// otherwise this will throw a `SyncbaseError.NotConfigured` or `SyncbaseError.NotLoggedIn`
  /// error.
  public static func database() throws -> Database {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    guard let db = Syncbase.db where Syncbase.didPostLogin else {
      throw SyncbaseError.NotLoggedIn
    }
    return db
  }

  public typealias LoginCallback = (err: SyncbaseError?) -> Void

  /// Authorize using an oauth token. Right now only Google OAuth token is supported
  /// (you should use the Google Sign In SDK to get this).
  ///
  /// You must login and have valid credentials before you can call `database()` to perform any
  /// operation.
  ///
  /// Calls `callback` on `Syncbase.queue` with any error that occured, or nil on success.
  public static func login(credentials: GoogleOAuthCredentials, callback: LoginCallback) {
    SyncbaseCore.Syncbase.login(
      SyncbaseCore.GoogleOAuthCredentials(token: credentials.token),
      callback: { err in
        guard err == nil else {
          callback(err: SyncbaseError(coreError: err!))
          return
        }
        // postLoginCreateDefaults can be blocking when performing create-or-join. Run on
        // a background queue to prevent blocking from the Go callback.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
          var callbackErr: SyncbaseError?
          do {
            try postLoginCreateDefaults()
          } catch let e as SyncbaseError {
            callbackErr = e
          } catch {
            preconditionFailure("Unsupported ErrorType: \(error)")
          }
          dispatch_async(Syncbase.queue) {
            callback(err: callbackErr)
          }
        }
    })
  }

  public static func isLoggedIn() throws -> Bool {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    return SyncbaseCore.Syncbase.isLoggedIn
  }

  public static func loggedInUser() -> User? {
    if let bp = try? personalBlessingString(),
      alias = aliasFromBlessingPattern(bp) {
        return User(alias: alias)
    }
    return nil
  }

  static var neighborhoodScans: [ScanNeighborhoodForUsersHandler: SyncbaseCore.NeighborhoodScanHandler] = [:]
  static let neighborhoodScansMu = NSLock()

  /// Scans the neighborhood for nearby users.
  ///
  /// - parameter handler: The handler for to call when a User is found or lost.
  /// Callbacks are called on `Syncbase.queue`.
  public static func startScanForUsersInNeighborhood(handler: ScanNeighborhoodForUsersHandler) throws {
    let coreHandler = NeighborhoodScanHandler(onPeer: { peer in
      guard let alias = aliasFromBlessingPattern(peer.blessings) else {
        NSLog("Syncbase - Could not get blessings from pattern %@", "\(peer.blessings)")
        return
      }
      let user = User(alias: alias)
      dispatch_async(Syncbase.queue) {
        if peer.isLost {
          handler.onLost(user)
        } else {
          handler.onFound(user)
        }
      }
    })
    try SyncbaseError.wrap {
      try Neighborhood.startScan(coreHandler)
    }
    neighborhoodScansMu.lock()
    neighborhoodScans[handler] = coreHandler
    neighborhoodScansMu.unlock()
  }

  /// Stops the handler from receiving new neighborhood scan updates.
  ///
  /// - parameter handler: The original handler passed to a started scan.
  public static func stopScanForUsersInNeighborhood(handler: ScanNeighborhoodForUsersHandler) {
    neighborhoodScansMu.lock()
    if let coreHandler = neighborhoodScans[handler] {
      Neighborhood.stopScan(coreHandler)
      neighborhoodScans.removeValueForKey(handler)
    }
    neighborhoodScansMu.unlock()
  }

  /// Stops all existing scanning handlers from receiving new neighborhood scan updates.
  public static func stopAllScansForUsersInNeighborhood() {
    neighborhoodScansMu.lock()
    for coreHandler in neighborhoodScans.values {
      Neighborhood.stopScan(coreHandler)
    }
    neighborhoodScans.removeAll()
    neighborhoodScansMu.unlock()
  }

  /// Advertises the logged in user's presence to the target set of users who must be around them.
  ///
  /// - parameter usersWhoCanSee: The set of users who are allowed to find this user. If empty
  /// then everyone can see the advertisement.
  public static func startAdvertisingPresenceInNeighborhood(usersWhoCanSee: [User] = []) throws {
    let visibility = try usersWhoCanSee.map { return try blessingPatternFromAlias($0.alias) }
    try SyncbaseError.wrap {
      try Neighborhood.startAdvertising(visibility)
    }
  }

  /// Stops advertising the presence of the logged in user so that they can no longer be found.
  public static func stopAdvertisingPresenceInNeighborhood() throws {
    try SyncbaseError.wrap {
      try Neighborhood.stopAdvertising()
    }
  }

  /// Returns true iff this person appears in the neighborhood.
  public static func isAdvertisingPresenceInNeighborhood() -> Bool {
    return Neighborhood.isAdvertising()
  }
}

public struct ScanNeighborhoodForUsersHandler: Hashable {
  public let onFound: User -> Void
  public let onLost: User -> Void
  // This internal-only variable allows us to test ScanNeighborhoodForUsersHandler structs for equality.
  // This cannot be done otherwise as function calls cannot be tested for equality.
  // Equality/hashValue is used to keep the set of all handlers in use.
  let uniqueId = OSAtomicIncrement32(&uniqueIdCounter)

  public init(onFound: User -> Void, onLost: User -> Void) {
    self.onFound = onFound
    self.onLost = onLost
  }

  public var hashValue: Int {
    return uniqueId.hashValue
  }
}

public func == (lhs: ScanNeighborhoodForUsersHandler, rhs: ScanNeighborhoodForUsersHandler) -> Bool {
  return lhs.uniqueId == rhs.uniqueId
}
