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
  static var didInit = false
  static var didPostLogin = false
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
      if Syncbase.didInit {
        throw SyncbaseError.AlreadyConfigured
      }
      Syncbase.adminUserId = adminUserId
      Syncbase.rootDir = rootDir
      Syncbase.mountPoints = mountPoints
      Syncbase.defaultBlessingStringPrefix = defaultBlessingStringPrefix
      Syncbase.disableSyncgroupPublishing = disableSyncgroupPublishing
      Syncbase.disableUserdataSyncgroup = disableUserdataSyncgroup
      Syncbase.didPostLogin = false
      // We don't need to set Syncbase.queue as it is a proxy for SyncbaseCore's queue, which is
      // set in the configure below.
      try SyncbaseError.wrap {
        try SyncbaseCore.Syncbase.configure(rootDir: Syncbase.rootDir, queue: queue)
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
          SyncbaseCore.Syncbase.shutdown()
          throw e
        }
      }
      Syncbase.didInit = true
  }

  private static func postLoginCreateDefaults() throws {
    let coreDb = try SyncbaseCore.Syncbase.database(Syncbase.DB_NAME)
    let database = Database(coreDatabase: coreDb)
    try database.createIfMissing()
    if (Syncbase.disableUserdataSyncgroup) {
      try database.collection(Syncbase.USERDATA_SYNCGROUP_NAME, withoutSyncgroup: true)
    } else {
      // FIXME(zinman): Implement create-or-join (and watch) of userdata syncgroup.
      throw SyncbaseError.IllegalArgument(detail: "Synced userdata collection is not yet supported")
    }
    Syncbase.db = database
    Syncbase.didPostLogin = true
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
        guard err == nil else {
          if let e = err as? SyncbaseCore.SyncbaseError {
            callback(err: SyncbaseError(coreError: e))
          } else {
            callback(err: err)
          }
          return
        }
        // postLoginCreateDefaults can be blocking when performing create-or-join. Run on
        // a background queue to prevent blocking from the Go callback.
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
          var callbackErr: ErrorType?
          do {
            try postLoginCreateDefaults()
          } catch let e {
            callbackErr = e
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
}
