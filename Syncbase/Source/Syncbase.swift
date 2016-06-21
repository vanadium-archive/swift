// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Syncbase is a storage system for developers that makes it easy to synchronize app data between
/// devices. It works even when devices are not connected to the Internet.
public enum Syncbase {
  // Constants
  static let TAG = "syncbase",
    DIR_NAME = "syncbase",
    DB_NAME = "db",
    USERDATA_SYNCGROUP_NAME = "userdata__"
  // Initialization state
  static var didCreateOrJoin = false
  static var didInit = false
  // Main database.
  static var db: Database?
  // Options for opening a database.
  static var adminUserId = "alexfandrianto@google.com"
  static var defaultBlessingStringPrefix = "dev.v.io:o:608941808256-43vtfndets79kf5hac8ieujto8837660.apps.googleusercontent.com:"
  static var disableSyncgroupPublishing = false
  static var disableUserdataSyncgroup = false
  static var mountPoints = ["/ns.dev.v.io:8101/tmp/todos/users/"]
  static var rootDir = Syncbase.defaultRootDir
  /// Queue used to dispatch all asynchronous callbacks. Defaults to main.
  public static var queue: dispatch_queue_t = dispatch_get_main_queue()

  static public var defaultRootDir: String {
    return NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("Syncbase")
      .absoluteString
  }

  static var publishSyncbaseName: String? {
    if Syncbase.disableSyncgroupPublishing {
      return nil
    }
    return mountPoints[0] + "cloud"
  }

  static var cloudBlessing: String {
    return "dev.v.io:u:" + Syncbase.adminUserId
  }

  /// Starts Syncbase if needed; creates default database if needed; performs create-or-join for
  /// "userdata" syncgroup if needed.
  ///
  /// The "userdata" collection is a per-user collection (and associated syncgroup) for data that
  /// should automatically get synced across a given user's devices. It has the following schema:
  /// - `/syncgroups/{encodedSyncgroupId}` -> `nil`
  /// - `/ignoredInvites/{encodedSyncgroupId}` -> `nil`
  ///
  /// - parameter adminUserId:                 The email address for the administrator user.
  /// - parameter rootDir:                     Where data should be persisted.
  /// - parameter mountPoints:                 // TODO(zinman): Get appropriate documentation on mountPoints
  /// - parameter defaultBlessingStringPrefix: // TODO(zinman): Figure out what this should default to.
  /// - parameter disableSyncgroupPublishing:  **FOR ADVANCED USERS**. If true, syncgroups will not be published to the cloud peer.
  /// - parameter disableUserdataSyncgroup:    **FOR ADVANCED USERS**. If true, the user's data will not be synced across their devices.
  /// - parameter callback:                    Called on `Syncbase.queue` with either `Database` if successful, or an error if unsuccessful.
  public static func configure(
    adminUserId adminUserId: String,
    // Default to Application Support/Syncbase.
    rootDir: String = NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("Syncbase")
      .absoluteString,
    mountPoints: [String] = ["/ns.dev.v.io:8101/tmp/todos/users/"],
    defaultBlessingStringPrefix: String = "dev.v.io:o:608941808256-43vtfndets79kf5hac8ieujto8837660.apps.googleusercontent.com:",
    disableSyncgroupPublishing: Bool = false,
    disableUserdataSyncgroup: Bool = false,
    queue: dispatch_queue_t = dispatch_get_main_queue()) throws {
      if didInit {
        throw SyncbaseError.AlreadyConfigured
      }
      Syncbase.adminUserId = adminUserId
      Syncbase.rootDir = rootDir
      Syncbase.mountPoints = mountPoints
      Syncbase.defaultBlessingStringPrefix = defaultBlessingStringPrefix
      Syncbase.disableSyncgroupPublishing = disableSyncgroupPublishing
      Syncbase.disableUserdataSyncgroup = disableUserdataSyncgroup

      // TODO(zinman): Reconfigure this logic once we have CL #23295 merged.
      let database = try Syncbase.startSyncbaseAndInitDatabase()
      if (Syncbase.disableUserdataSyncgroup) {
        try database.collection(Syncbase.USERDATA_SYNCGROUP_NAME, withoutSyncgroup: true)
      } else {
        // This gets deferred to login as it's blocking. Once we've logged in we don't need it
        // anyway.
        didCreateOrJoin = false
        // FIXME(zinman): Implement create-or-join (and watch) of userdata syncgroup.
        throw SyncbaseError.IllegalArgument(detail: "Synced userdata collection is not yet supported")
      }
      Syncbase.db = database
      Syncbase.didInit = true
  }

  private static func startSyncbaseAndInitDatabase() throws -> Database {
    if Syncbase.rootDir == "" {
      throw SyncbaseError.IllegalArgument(detail: "Missing rootDir")
    }
    if !NSFileManager.defaultManager().fileExistsAtPath(Syncbase.rootDir) {
      try NSFileManager.defaultManager().createDirectoryAtPath(
        Syncbase.rootDir,
        withIntermediateDirectories: true,
        attributes: [NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication])
    }
    return try SyncbaseError.wrap {
      // TODO(zinman): Verify we should be using the user's blessing (by not explicitly passing
      // the blessings in an Identifier).
      try SyncbaseCore.Syncbase.configure(rootDir: Syncbase.rootDir, queue: Syncbase.queue)
      let coreDb = try SyncbaseCore.Syncbase.database(Syncbase.DB_NAME)
      let res = Database(coreDatabase: coreDb)
      try res.createIfMissing()
      return res
    }
  }

  /// Returns the shared database handle. Must have already called `configure` and be logged in,
  /// otherwise this will throw a `SyncbaseError.NotConfigured` or `SyncbaseError.NotLoggedIn`
  /// error.
  public static func database() throws -> Database {
    guard let db = Syncbase.db where Syncbase.didInit else {
      throw SyncbaseError.NotConfigured
    }
    if !SyncbaseCore.Syncbase.isLoggedIn {
      throw SyncbaseError.NotLoggedIn
    }
    if !Syncbase.disableUserdataSyncgroup && !Syncbase.didCreateOrJoin {
      // Create-or-join of userdata syncgroup occurs in login. We must have failed between
      // login() and the create-or-join call.
      throw SyncbaseError.NotLoggedIn
    }
    return db
  }

  public typealias LoginCallback = (err: ErrorType?) -> Void

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
        guard err != nil else {
          if let e = err as? SyncbaseCore.SyncbaseError {
            callback(err: SyncbaseError(coreError: e))
          } else {
            callback(err: err)
          }
          return
        }
        if Syncbase.disableUserdataSyncgroup {
          // Success
          dispatch_async(Syncbase.queue) {
            callback(err: nil)
          }
        } else {
          dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
            callback(err: SyncbaseError.IllegalArgument(detail:
                "Synced userdata collection is not yet supported"))
            return
            // FIXME(zinman): Implement create-or-join (and watch) of userdata syncgroup.
            // Syncbase.didCreateOrJoin = true
            // dispatch_async(Syncbase.queue) {
            // callback(nil)
            // }
          }
        }
    })
  }

  public static func isLoggedIn() throws -> Bool {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    if !Syncbase.disableUserdataSyncgroup && !Syncbase.didCreateOrJoin {
      // Create-or-join of userdata syncgroup occurs in login. We must have failed between
      // login() and the create-or-join call.
      throw SyncbaseError.NotLoggedIn
    }
    return SyncbaseCore.Syncbase.isLoggedIn
  }
}
