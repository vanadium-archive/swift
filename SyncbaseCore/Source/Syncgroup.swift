// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct VersionedSpec {
  public let spec: SyncgroupSpec
  public let version: String

  public init(spec: SyncgroupSpec, version: String) {
    self.spec = spec
    self.version = version
  }
}

public class Syncgroup {
  let encodedDatabaseName: String
  public let syncgroupId: Identifier

  init(encodedDatabaseName: String, syncgroupId: Identifier) {
    self.encodedDatabaseName = encodedDatabaseName
    self.syncgroupId = syncgroupId
  }

  /// Create creates a new syncgroup with the given spec.
  ///
  /// Requires: Client must have at least Read access on the Database; all
  /// Collections specified in prefixes must exist; Client must have at least
  /// Read access on each of the Collection ACLs.
  public func create(spec: SyncgroupSpec, myInfo: SyncgroupMemberInfo) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbCreateSyncgroup(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        try v23_syncbase_SyncgroupSpec(spec),
        v23_syncbase_SyncgroupMemberInfo(myInfo),
        errPtr)
    }
  }

  /// Join joins a syncgroup.
  ///
  /// - Parameter remoteSyncbaseName: This is the remote address, analagous to a git remote repo.
  /// The value will be provided via discovery; you'll never
  /// automatically know this.
  ///
  /// - Parameter expectedSyncbaseBlessings: The blessings you believe the remote side will have,
  /// to make sure we are talking to who we expect.
  ///
  /// - Parameter myInfo: The sync priority and blob device type.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  public func join(remoteSyncbaseName: String, expectedSyncbaseBlessings: [String], myInfo: SyncgroupMemberInfo) throws -> SyncgroupSpec {
    var spec = v23_syncbase_SyncgroupSpec()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbJoinSyncgroup(
        try encodedDatabaseName.toCgoString(),
        try remoteSyncbaseName.toCgoString(),
        try v23_syncbase_Strings(expectedSyncbaseBlessings),
        try v23_syncbase_Id(syncgroupId),
        v23_syncbase_SyncgroupMemberInfo(myInfo),
        &spec,
        errPtr)
    }
    return try spec.toSyncgroupSpec()
  }

  /// Leave leaves the syncgroup. Previously synced data will continue
  /// to be available.
  ///
  /// Requires: Client must have at least Read access on the Database.
  public func leave() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbLeaveSyncgroup(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        errPtr)
    }
  }

  /// Destroy destroys the syncgroup. Previously synced data will
  /// continue to be available to all members.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  public func destroy() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbDestroySyncgroup(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        errPtr)
    }
  }

  /// Eject ejects a member from the syncgroup. The ejected member
  /// will not be able to sync further, but will retain any data it has already
  /// synced.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  public func eject(member: String) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbEjectFromSyncgroup(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        try member.toCgoString(),
        errPtr)
    }
  }

  /// GetSpec gets the syncgroup spec. version allows for atomic
  /// read-modify-write of the spec - see comment for SetSpec.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  public func getSpec() throws -> VersionedSpec {
    var spec = v23_syncbase_SyncgroupSpec()
    var version = v23_syncbase_String()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbGetSyncgroupSpec(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        &spec,
        &version,
        errPtr)
    }
    return VersionedSpec(
      spec: try spec.toSyncgroupSpec(),
      version: version.toString()!)
  }

  /// SetSpec sets the syncgroup spec. version may be either empty or
  /// the value from a previous Get. If not empty, Set will only succeed if the
  /// current version matches the specified one.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  public func setSpec(versionedSpec: VersionedSpec) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbSetSyncgroupSpec(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        try v23_syncbase_SyncgroupSpec(versionedSpec.spec),
        try versionedSpec.version.toCgoString(),
        errPtr)
    }
  }

  /// GetMembers gets the info objects for members of the syncgroup.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  public func getMembers() throws -> [String: SyncgroupMemberInfo] {
    var members = v23_syncbase_SyncgroupMemberInfoMap()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbGetSyncgroupMembers(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Id(syncgroupId),
        &members,
        errPtr)
    }
    return members.toSyncgroupMemberInfoMap()
  }
}

/// SyncgroupMemberInfo contains per-member metadata.
public struct SyncgroupMemberInfo {
  public let syncPriority: UInt8
  public let blobDevType: BlobDevType /// See BlobDevType* constants.

  public init(syncPriority: UInt8, blobDevType: BlobDevType) {
    self.syncPriority = syncPriority
    self.blobDevType = blobDevType
  }
}

public struct SyncgroupSpec {
  /// Human-readable description of this syncgroup.
  public let description: String

  // Data (set of collectionIds) covered by this syncgroup.
  public let collections: [Identifier]

  /// Permissions governing access to this syncgroup.
  public let permissions: Permissions

  // Optional. If present then any syncbase that is the admin of this syncgroup
  // is responsible for ensuring that the syncgroup is published to this syncbase instance.
  public let publishSyncbaseName: String?

  /// Mount tables at which to advertise this syncgroup, for rendezvous purposes.
  /// (Note that in addition to these mount tables, Syncbase also uses
  /// network-neighborhood-based discovery for rendezvous.)
  /// We expect most clients to specify a single mount table, but we accept an
  /// array of mount tables to permit the mount table to be changed over time
  /// without disruption.
  public let mountTables: [String]

  /// Specifies the privacy of this syncgroup. More specifically, specifies
  /// whether blobs in this syncgroup can be served to clients presenting
  /// blobrefs obtained from other syncgroups.
  public let isPrivate: Bool

  public init(
    description: String,
    collections: [Identifier],
    permissions: Permissions,
    publishSyncbaseName: String?,
    mountTables: [String],
    isPrivate: Bool) {
      self.description = description
      self.collections = collections
      self.permissions = permissions
      self.publishSyncbaseName = publishSyncbaseName
      self.mountTables = mountTables
      self.isPrivate = isPrivate
  }
}
