// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

//public let instance = Syncbase.instance

public struct Syncbase: Service {
  // TODO(zinman): Figure out what the local name is supposed to be be
  private static let kLocalName = ""
  public let fullName: String
  private static var _localInstance: Syncbase? = nil

  /// The singleton instance of Syncbase that represents the local store. This is the primary
  /// Syncbase client you want to work with, unless you explicitly want to connect to a remote
  /// Syncbase via RPC (then use the constructor with its object name passed)
  ///
  /// You won't be able to sync with anybody unless you grant yourself a blessing via the authorize
  /// method.
  public static var instance: Syncbase {
    get {
      if (_localInstance == nil) {
        do {
          _localInstance = try Syncbase(fullName: kLocalName)
        } catch let err {
          log.warning("Couldn't instantiate an instance of Syncbase: \(err)")
        }
      }
      return _localInstance!
    }

    set {
      if (_localInstance != nil) {
        fatalError("You cannot create another local instance of Syncbase")
      }
      _localInstance = newValue
    }
  }

  /**
   Returns a new client handle to a syncbase service running at the given name. The common scenario
   is to only use Syncbase.instance for the local store -- this constructor is used for connecting
   to remote Syncbases.

   - Parameter fullName: full (i.e., object) name of the syncbase service
   */
  public init(fullName: String) throws {
    self.fullName = fullName
    // STUB
  }

  /// Create a database using the relative name and user's blessings.
  public func database(name: String) throws -> Database {
    return database(DatabaseId(name: name, blessing: try Principal.blessingsDebugString()))
  }

  /// DatabaseForId returns the Database with the given app blessing and name (from the Id struct).
  public func database(databaseId: DatabaseId) -> Database {
    preconditionFailure("Implement me")
  }

  /// ListDatabases returns a list of all Database ids that the caller is allowed to see.
  /// The list is sorted by blessing, then by name.
  public func listDatabases() throws -> [DatabaseId] {
    preconditionFailure("Implement me")
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
