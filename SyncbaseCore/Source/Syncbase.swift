// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

//public let instance = Syncbase.instance

public class Syncbase: Service {
  /// The singleton instance of Syncbase that represents the local store.
  /// You won't be able to sync with anybody unless you grant yourself a blessing via the authorize
  /// method.
  public static var instance: Syncbase = Syncbase()

  /// Private constructor -- because this class is a singleton it should only be called once
  /// and by the static instance method.
  private init() {
    v23_syncbase_Init()
  }

  /// Create a database using the relative name and user's blessings.
  public func database(name: String) throws -> Database {
    return try database(Identifier(name: name, blessing: try Principal.appBlessing()))
  }

  /// DatabaseForId returns the Database with the given app blessing and name (from the Id struct).
  public func database(databaseId: Identifier) throws -> Database {
    guard let db = Database(databaseId: databaseId, batchHandle: nil) else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: "\(databaseId)")
    }
    return db
  }

  /// ListDatabases returns a list of all Database ids that the caller is allowed to see.
  /// The list is sorted by blessing, then by name.
  public func listDatabases() throws -> [Identifier] {
    var ids = v23_syncbase_Ids()
    return try VError.maybeThrow({ err in
      v23_syncbase_ServiceListDatabases(&ids, err)
      return ids.toIdentifiers()
    })
  }

  /// Must return true before any Syncbase operation can work. Authorize using GoogleCredentials
  /// created from a Google OAuth token (you should use the Google Sign In SDK to get this).
  public var isLoggedIn: Bool {
    log.debug("Blessings debug string is \(Principal.blessingsDebugDescription)")
    return Principal.blessingsAreValid()
  }

  /// For debugging the current Syncbase user blessings.
  public var loggedInBlessingDebugDescription: String {
    return Principal.blessingsDebugDescription
  }

  /// Authorize using GoogleCredentials created from a Google OAuth token (you should use the
  /// Google Sign In SDK to get this). You must login and have valid credentials before any
  /// Syncbase operation will work.
  ///
  /// Calls callback on main with nil on success, or on failure a SyncbaseError or VError.
  ///
  /// TODO(zinman): Make sure the blessings cache works so we don't actually have to login
  /// every single time.
  public func login(credentials: GoogleCredentials, callback: ErrorType? -> Void) {
    // Go's login is blocking, so call on a background concurrent queue.
    RunInBackgroundQueue {
      var err: ErrorType? = nil
      do {
        try VError.maybeThrow { errPtr in
          v23_syncbase_Login(
            try credentials.provider.rawValue.toCgoString(),
            try credentials.token.toCgoString(),
            errPtr)
        }
      } catch (let e) {
        err = e
      }
      RunInMainQueue { callback(err) }
    }
  }
}

extension Syncbase: AccessController {
  /// setPermissions replaces the current Permissions for an object.
  public func setPermissions(perms: Permissions, version: PermissionsVersion) throws {
    preconditionFailure("Implement me")
  }

  /// getPermissions returns the current Permissions for an object.
  /// For detailed documentation, see Object.GetPermissions.
  public func getPermissions() throws -> (Permissions, PermissionsVersion) {
    preconditionFailure("Implement me")
  }
}
