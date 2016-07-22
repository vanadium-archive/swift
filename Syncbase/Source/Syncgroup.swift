// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents a set of collections, synced amongst a set of users.
/// To get a Syncgroup handle, call `Database.syncgroup`.
public class Syncgroup: CustomStringConvertible {
  let database: Database
  let coreSyncgroup: SyncbaseCore.Syncgroup

  static var syncgroupMemberInfo: SyncgroupMemberInfo {
    // TODO(zinman): Validate these are correct.
    return SyncgroupMemberInfo(syncPriority: UInt8(3), blobDevType: BlobDevType.Leaf)
  }

  func createIfMissing(collections: [Collection]) throws {
    let cxCoreIds = collections.map { $0.collectionId.toCore() }
    let spec = SyncgroupSpec(
      description: "",
      collections: cxCoreIds,
      permissions: try defaultSyncgroupPerms(),
      publishSyncbaseName: Syncbase.publishSyncbaseName,
      mountTables: Syncbase.mountPoints,
      isPrivate: false)
    do {
      try SyncbaseError.wrap {
        try self.coreSyncgroup.create(spec, myInfo: Syncgroup.syncgroupMemberInfo)
      }
    } catch SyncbaseError.Exist {
      // Syncgroup already exists.
      // TODO(sadovsky): Verify that the existing syncgroup has the specified configuration,
      // e.g. the specified collections?
    }
  }

  init(coreSyncgroup: SyncbaseCore.Syncgroup, database: Database) {
    self.coreSyncgroup = coreSyncgroup
    self.database = database
  }

  /// Returns the id of this syncgroup.
  public var syncgroupId: Identifier {
    return Identifier(coreId: coreSyncgroup.syncgroupId)
  }

  func join() throws {
    // TODO(razvanm): Find a way to restrict the remote blessing.
    try coreSyncgroup.join(
      Syncbase.cloudName ?? "",
      expectedSyncbaseBlessings: ["..."],
      myInfo: Syncgroup.syncgroupMemberInfo)
  }

  /// Returns the `AccessList` for this syncgroup.
  public func accessList() throws -> AccessList {
    return try AccessList(perms: try coreSyncgroup.getSpec().spec.permissions)
  }

  /// **FOR ADVANCED USERS**. Adds the given users to the syncgroup, with the specified access level.
  ///
  /// - parameter users:          Users to add to the syncgroup.
  /// - parameter level:          Access level for the specified `users`.
  /// - parameter syncgroupOnly:  If false (the default), update the `AccessList` for the syncgroup
  /// and its associated collections. If true, only update the `AccessList` for the syncgroup.
  public func inviteUsers(users: [User], level: AccessList.AccessLevel, syncgroupOnly: Bool = false) throws {
    var delta = AccessList()
    for user in users {
      delta.users[user.alias] = level
    }
    try updateAccessList(delta, syncgroupOnly: syncgroupOnly)
  }

  /// Adds the given user to the syncgroup, with the specified access level.
  ///
  /// - parameter user:           User to add to the syncgroup.
  /// - parameter level:          Access level for the specified `user`.
  /// - parameter syncgroupOnly:  If false (the default), update the `AccessList` for the syncgroup
  /// and its associated collections. If true, only update the `AccessList` for the syncgroup.
  public func inviteUser(user: User, level: AccessList.AccessLevel, syncgroupOnly: Bool = false) throws {
    try inviteUsers([user], level: level, syncgroupOnly: syncgroupOnly)
  }

  /// **FOR ADVANCED USERS**. Removes the given users from the syncgroup.
  ///
  /// - parameter users:          Users to eject from the Syncgroup.
  /// - parameter syncgroupOnly:  If false (the default), update the `AccessList` for the syncgroup
  /// and its associated collections. If true, only update the `AccessList` for the syncgroup.
  public func ejectUsers(users: [User], syncgroupOnly: Bool = false) throws {
    var delta = AccessList()
    for user in users {
      delta.users[user.alias] = AccessList.AccessLevel.INTERNAL_ONLY_REMOVE
    }
    try updateAccessList(delta, syncgroupOnly: syncgroupOnly)
  }

  /// Removes the given user from the syncgroup.
  ///
  /// - parameter user:           User to eject from the Syncgroup.
  /// - parameter syncgroupOnly:  If false (the default), update the `AccessList` for the syncgroup
  /// and its associated collections. If true, only update the `AccessList` for the syncgroup.
  public func ejectUser(user: User, syncgroupOnly: Bool = false) throws {
    try ejectUsers([user], syncgroupOnly: syncgroupOnly)
  }

  /// **FOR ADVANCED USERS**. Applies `delta` to the `AccessList`.
  ///
  /// - parameter delta:          AccessList changes to the Syncgroup.
  /// - parameter syncgroupOnly:  If false (the default), update the `AccessList` for the syncgroup
  /// and its associated collections. If true, only update the `AccessList` for the syncgroup.
  public func updateAccessList(delta: AccessList, syncgroupOnly: Bool = false) throws {
    try SyncbaseError.wrap {
      // TODO(sadovsky): Make it so SyncgroupSpec can be updated as part of a batch?
      let versionedSpec = try self.coreSyncgroup.getSpec()
      let permissions = try AccessList.applyDelta(versionedSpec.spec.permissions, delta: delta)
      let oldSpec = versionedSpec.spec
      try self.coreSyncgroup.setSpec(VersionedSpec(
        spec: SyncgroupSpec(description: oldSpec.description,
          collections: oldSpec.collections,
          permissions: permissions,
          publishSyncbaseName: oldSpec.publishSyncbaseName,
          mountTables: oldSpec.mountTables,
          isPrivate: oldSpec.isPrivate),
        version: versionedSpec.version))
      // TODO(sadovsky): There's a race here - it's possible for a collection to get destroyed
      // after spec.getCollections() but before db.getCollection().
      try self.database.runInBatch { db in
        for id in oldSpec.collections {
          try db.collection(Identifier(coreId: id)).updateAccessList(delta)
        }
      }
    }
  }

  public var description: String {
    return "[Syncbase.Syncgroup id=\(syncgroupId)]"
  }
}
