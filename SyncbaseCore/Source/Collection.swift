/// Copyright 2016 The Vanadium Authors. All rights reserved.
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file.

import Foundation

/// CollectionRow encapsulates a collection id and row key or row prefix.
public struct CollectionRow {
  let collectionId: Identifier
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
public class Collection {
  /// Id returns the id of this Collection.
  public let collectionId: Identifier
  let batchHandle: String?
  let encodedCollectionName: String

  init?(databaseId: Identifier, collectionId: Identifier, batchHandle: String?) {
    self.collectionId = collectionId
    self.batchHandle = batchHandle
    do {
      self.encodedCollectionName = try Collection.encodedName(databaseId, collectionId: collectionId)
    } catch {
      // UTF8 encoding error.
      return nil
    }
  }

  /// Exists returns true only if this Collection exists. Insufficient
  /// permissions cause Exists to return false instead of an throws.
  /// TODO(ivanpi): Exists may fail with an throws if higher levels of hierarchy
  /// do not exist.
  public func exists() throws -> Bool {
    return try VError.maybeThrow { errPtr in
      var exists = v23_syncbase_Bool(false)
      v23_syncbase_CollectionExists(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        &exists,
        errPtr)
      return exists.toBool()
    }
  }

  /// Create creates this Collection.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  public func create(permissions: Permissions?) throws {
    try VError.maybeThrow { errPtr in
      guard let cPermissions = v23_syncbase_Permissions(permissions) else {
        throw SyncbaseError.PermissionsSerializationError(permissions: permissions)
      }
      v23_syncbase_CollectionCreate(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        cPermissions,
        errPtr)
    }
  }

  /// Destroy destroys this Collection, permanently removing all of its data.
  /// TODO(sadovsky): Specify what happens to syncgroups.
  public func destroy() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_CollectionDestroy(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        errPtr)
    }
  }

  /// GetPermissions returns the current Permissions for the Collection.
  /// The Read bit on the ACL does not affect who this Collection's rows are
  /// synced to; all members of syncgroups that include this Collection will
  /// receive the rows in this Collection. It only determines which clients
  /// are allowed to retrieve the value using a Syncbase RPC.
  public func getPermissions() throws -> Permissions {
    preconditionFailure("stub")
  }

  /// SetPermissions replaces the current Permissions for the Collection.
  public func setPermissions(permissions: Permissions) throws {
    preconditionFailure("stub")
  }

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
  public func get<T: SyncbaseJsonConvertible>(key: String, inout value: T?) throws {
    // TODO(zinman): We should probably kill this variant unless it provides .dynamicType benefits
    // with VOM support and custom class serialization/deserialization.
    value = try get(key)
  }

  /// Get loads the value stored under the given key.
  public func get<T: SyncbaseJsonConvertible>(key: String) throws -> T? {
    guard let jsonData = try getRawBytes(key) else {
      return nil
    }
    let value: T = try T.fromSyncbaseJson(jsonData)
    return value
  }

  func getRawBytes(key: String) throws -> NSData? {
    var cBytes = v23_syncbase_Bytes()
    try VError.maybeThrow { errPtr in
      v23_syncbase_RowGet(try encodedRowName(key),
        try cBatchHandle(),
        &cBytes,
        errPtr)
    }
    return cBytes.toNSData()
  }

  /// Put writes the given value to this Collection under the given key.
  public func put(key: String, value: SyncbaseJsonConvertible) throws {
    let (data, _) = try value.toSyncbaseJson()
    try VError.maybeThrow { errPtr in
      v23_syncbase_RowPut(try encodedRowName(key),
        try cBatchHandle(),
        v23_syncbase_Bytes(data),
        errPtr)
    }
  }

  /// Delete deletes the row for the given key.
  public func delete(key: String) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_RowDelete(try encodedRowName(key),
        try cBatchHandle(),
        errPtr)
    }
  }

  /// DeleteRange deletes all rows in the given half-open range [start, limit).
  /// If limit is "", all rows with keys >= start are included.
  /// TODO(sadovsky): Document how this deletion is considered during conflict
  /// detection: is it considered as a range deletion, or as a bunch of point
  /// deletions?
  /// See helpers Prefix(), Range(), SingleRow().
  public func deleteRange(r: RowRange) throws {
    preconditionFailure("stub")
  }

  /// Scan returns all rows in the given half-open range [start, limit). If limit
  /// is "", all rows with keys >= start are included.
  /// Concurrency semantics: It is legal to perform writes concurrently with
  /// Scan. The returned stream reads from a consistent snapshot taken at the
  /// time of the RPC (or at the time of BeginBatch, if in a batch), and will not
  /// reflect subsequent writes to keys not yet reached by the stream.
  /// See helpers Prefix(), Range(), SingleRow().
  public func scan(r: RowRange) -> ScanStream {
    preconditionFailure("stub")
  }

  // MARK: Internal helpers

  private func cBatchHandle() throws -> v23_syncbase_String {
    return try batchHandle?.toCgoString() ?? v23_syncbase_String()
  }

  private static func encodedName(databaseId: Identifier, collectionId: Identifier) throws -> String {
    var cStr = v23_syncbase_String()
    v23_syncbase_NamingJoin(
      v23_syncbase_Strings([try databaseId.encodeId(), try collectionId.encodeId()]),
      &cStr)
    return cStr.toString()!
  }

  private func encodedRowName(key: String) throws -> v23_syncbase_String {
    var encodedRowName = v23_syncbase_String()
    var encodedRowKey = v23_syncbase_String()
    v23_syncbase_Encode(try key.toCgoString(), &encodedRowKey)
    v23_syncbase_NamingJoin(
      v23_syncbase_Strings([try encodedCollectionName.toCgoString(), encodedRowKey]),
      &encodedRowName)
    return encodedRowName
  }
}

/// Returns the decoded value, or throws an error if the value could not be decoded.
public typealias GetValueFromScanStream = () throws -> SyncbaseJsonConvertible

/// Stream resulting from a scan on a scollection for a given row range.
public typealias ScanStream = AnonymousStream<(String, GetValueFromScanStream)>
