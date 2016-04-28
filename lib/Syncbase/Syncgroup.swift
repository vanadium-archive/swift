// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct VersionedSpec {
  let spec: SyncgroupSpec
  let version: String
}

public protocol Syncgroup {
  /// Create creates a new syncgroup with the given spec.
  ///
  /// Requires: Client must have at least Read access on the Database; all
  /// Collections specified in prefixes must exist; Client must have at least
  /// Read access on each of the Collection ACLs.
  func create(spec: SyncgroupSpec, myInfo: SyncgroupMemberInfo) throws

  /// Join joins a syncgroup.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  func join(myInfo: SyncgroupMemberInfo) throws -> SyncgroupSpec

  /// Leave leaves the syncgroup. Previously synced data will continue
  /// to be available.
  ///
  /// Requires: Client must have at least Read access on the Database.
  func leave() throws

  /// Destroy destroys the syncgroup. Previously synced data will
  /// continue to be available to all members.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  func destroy() throws

  /// Eject ejects a member from the syncgroup. The ejected member
  /// will not be able to sync further, but will retain any data it has already
  /// synced.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  func eject(member: String) throws

  /// GetSpec gets the syncgroup spec. version allows for atomic
  /// read-modify-write of the spec - see comment for SetSpec.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  func getSpec() throws -> VersionedSpec

  /// SetSpec sets the syncgroup spec. version may be either empty or
  /// the value from a previous Get. If not empty, Set will only succeed if the
  /// current version matches the specified one.
  ///
  /// Requires: Client must have at least Read access on the Database, and must
  /// have Admin access on the syncgroup ACL.
  func setSpec(versionedSpec: VersionedSpec) throws

  /// GetMembers gets the info objects for members of the syncgroup.
  ///
  /// Requires: Client must have at least Read access on the Database and on the
  /// syncgroup ACL.
  func getMembers() throws -> [String: SyncgroupMemberInfo]
}

public struct SyncgroupSpec {
  /// Human-readable description of this syncgroup.
  let description: String
  /// Permissions governing access to this syncgroup.
  let permissions: Permissions
  /// Data (collectionId-rowPrefix pairs) covered by this syncgroup.
  let prefixes: [CollectionRow]
  /// Mount tables at which to advertise this syncgroup, for rendezvous purposes.
  /// (Note that in addition to these mount tables, Syncbase also uses
  /// network-neighborhood-based discovery for rendezvous.)
  /// We expect most clients to specify a single mount table, but we accept an
  /// array of mount tables to permit the mount table to be changed over time
  /// without disruption.
  /// TODO(hpucha): Figure out a convention for advertising syncgroups in the
  /// mount table.
  let mountTables: [String]
  /// Specifies the privacy of this syncgroup. More specifically, specifies
  /// whether blobs in this syncgroup can be served to clients presenting
  /// blobrefs obtained from other syncgroups.
  let isPrivate: Bool
}
