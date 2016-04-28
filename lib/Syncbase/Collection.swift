/// Copyright 2015 The Vanadium Authors. All rights reserved.
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file.

import Foundation

/// CollectionRow encapsulates a collection id and row key or row prefix.
public struct CollectionRow {
  let collectionId: CollectionId
  let row: String
}

/// SyncgroupMemberInfo contains per-member metadata.
public struct SyncgroupMemberInfo {
  let syncPriority: UInt8
  let blobDevType: BlobDevType /// See BlobDevType* constants.
}

/// Collection represents a set of Rows.
///
/// TODO(sadovsky): Currently we provide Get/Put/Delete methods on both
/// Collection and Row, because we're not sure which will feel more natural.
/// Eventually, we'll need to pick one.
public protocol Collection {
  /// Id returns the id of this Collection.
  var collectionId: CollectionId { get }

  /// FullName returns the object name (encoded) of this Collection.
  var fullName: String { get }

  /// Exists returns true only if this Collection exists. Insufficient
  /// permissions cause Exists to return false instead of an throws.
  /// TODO(ivanpi): Exists may fail with an throws if higher levels of hierarchy
  /// do not exist.
  func exists() throws -> Bool

  /// Create creates this Collection.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  func create(permissions: Permissions) throws

  /// Destroy destroys this Collection, permanently removing all of its data.
  /// TODO(sadovsky): Specify what happens to syncgroups.
  func destroy() throws

  /// GetPermissions returns the current Permissions for the Collection.
  /// The Read bit on the ACL does not affect who this Collection's rows are
  /// synced to; all members of syncgroups that include this Collection will
  /// receive the rows in this Collection. It only determines which clients
  /// are allowed to retrieve the value using a Syncbase RPC.
  func getPermissions() throws -> Permissions

  /// SetPermissions replaces the current Permissions for the Collection.
  func setPermissions(permissions: Permissions) throws

  /// Row returns the Row with the given key.
  func row(key: String) -> Row

  /**
   Get loads the value stored under the given key into inout parameter value.

   Sets value to nil if nothing is stored undeder the given key.

   By passing the typed target output value using inout, get is able to cast the value to the
   desired type automatically. If the types do not match, an exception is thrown.

   For example:

   ```
   /// Using inout
   var isRed: Bool?
   try collection.get("isRed", &isRed)

   /// Using return value
   let isRed: Bool = try collection.get("isRed")
   ```
   */
  func get<T: SyncbaseJsonConvertible>(key: String, inout value: T?) throws

  /// Get loads the value stored under the given key.
  func get<T: SyncbaseJsonConvertible>(key: String) throws -> T?

  /// Put writes the given value to this Collection under the given key.
  func put(key: String, value: SyncbaseJsonConvertible) throws

  /// Delete deletes the row for the given key.
  func delete(key: String) throws

  /// DeleteRange deletes all rows in the given half-open range [start, limit).
  /// If limit is "", all rows with keys >= start are included.
  /// TODO(sadovsky): Document how this deletion is considered during conflict
  /// detection: is it considered as a range deletion, or as a bunch of point
  /// deletions?
  /// See helpers Prefix(), Range(), SingleRow().
  func deleteRange(r: RowRange) throws

  /// Scan returns all rows in the given half-open range [start, limit). If limit
  /// is "", all rows with keys >= start are included.
  /// Concurrency semantics: It is legal to perform writes concurrently with
  /// Scan. The returned stream reads from a consistent snapshot taken at the
  /// time of the RPC (or at the time of BeginBatch, if in a batch), and will not
  /// reflect subsequent writes to keys not yet reached by the stream.
  /// See helpers Prefix(), Range(), SingleRow().
  func scan(r: RowRange) -> ScanStream
}

/// Returns the decoded value, or throws an error if the value could not be decoded.
public typealias GetValueFromScanStream = () throws -> SyncbaseJsonConvertible

/// Stream resulting from a scan on a scollection for a given row range.
public typealias ScanStream = AnonymousStream<(String, GetValueFromScanStream)>
