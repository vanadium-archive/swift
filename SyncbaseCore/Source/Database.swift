// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// DatabaseHandle is the set of methods that work both with and without a batch.
/// It allows clients to pass the handle to helper methods that are batch-agnostic.
public protocol DatabaseHandle {
  /// Id returns the id of this DatabaseHandle..
  var databaseId: Identifier { get }

  /// Collection returns the Collection with the given relative name.
  /// The user blessing is derived from the context.
  /// Throws if the name is invalid, or the blessings are invalid.
  func collection(name: String) throws -> Collection

  /// CollectionForId returns the Collection with the given user blessing and name.
  /// Throws if the id cannot be encoded into UTF8.
  func collection(collectionId: Identifier) throws -> Collection

  /// ListCollections returns a list of all Collection ids that the caller is
  /// allowed to see. The list is sorted by blessing, then by name.
  func listCollections() throws -> [Identifier]

  /// Returns a ResumeMarker that points to the current end of the event log.
  func getResumeMarker() throws -> ResumeMarker
}

public class Database {
  public let databaseId: Identifier
  let batchHandle: String?
  let encodedDatabaseName: String

  init?(databaseId: Identifier, batchHandle: String?) {
    self.databaseId = databaseId
    self.batchHandle = batchHandle
    do {
      self.encodedDatabaseName = try databaseId.encodeId().toString()!
    } catch {
      // UTF8 encoding error.
      return nil
    }
  }

  /// Create creates this Database.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  public func create(permissions: Permissions?) throws {
    try VError.maybeThrow { errPtr in
      guard let cPermissions = v23_syncbase_Permissions(permissions) else {
        throw SyncbaseError.PermissionsSerializationError(permissions: permissions)
      }
      v23_syncbase_DbCreate(try encodedDatabaseName.toCgoString(), cPermissions, errPtr)
    }
  }

  /// Destroy destroys this Database, permanently removing all of its data.
  /// TODO(sadovsky): Specify what happens to syncgroups.
  public func destroy() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbDestroy(try encodedDatabaseName.toCgoString(), errPtr)
    }
  }

  // Exists returns true only if this Database exists. Insufficient permissions
  // cause Exists to return false instead of an error.
  public func exists() throws -> Bool {
    return try VError.maybeThrow { errPtr in
      var exists = v23_syncbase_Bool(false)
      v23_syncbase_DbExists(try encodedDatabaseName.toCgoString(), &exists, errPtr)
      return exists.toBool()
    }
  }

  /** BeginBatch creates a new batch. Instead of calling this function directly,
   clients are encouraged to use the RunInBatch() helper function, which
   detects "concurrent batch" errors and handles retries internally.

   Default concurrency semantics:

   - Reads (e.g. gets, scans) inside a batch operate over a consistent
   snapshot taken during BeginBatch(), and will see the effects of prior
   writes performed inside the batch.

   - Commit() may fail with ErrConcurrentBatch, indicating that after
   BeginBatch() but before Commit(), some concurrent routine wrote to a key
   that matches a key or row-range read inside this batch.

   - Other methods will never fail with error ErrConcurrentBatch, even if it
   is known that Commit() will fail with this error.

   Once a batch has been committed or aborted, subsequent method calls will
   fail with no effect.

   Concurrency semantics can be configured using BatchOptions.
   TODO(sadovsky): Use varargs for options.
   */
  public func beginBatch(options: BatchOptions?) throws -> BatchDatabase {
    preconditionFailure("stub")
  }

  /// Watch allows a client to watch for updates to the database. For each watch
  /// request, the client will receive a reliable stream of watch events without
  /// reordering. See watch.GlobWatcher for a detailed explanation of the
  /// behavior.
  ///
  /// If a nil ResumeMarker is provided, the WatchStream will begin with a Change
  /// batch containing the initial state. Otherwise, the WatchStream will contain
  /// only changes since the provided ResumeMarker.
  ///
  /// TODO(sadovsky): Watch should return just a WatchStream, similar to how Scan
  /// returns just a ScanStream.
  public func watch(collectionId: Identifier, prefix: String, resumeMarker: ResumeMarker?) throws -> WatchStream {
    preconditionFailure("stub")
  }

  /// Syncgroup returns a handle to the syncgroup with the given name.
  public func syncgroup(sgName: String) -> Syncgroup {
    preconditionFailure("stub")
  }

  /// GetSyncgroupNames returns the names of all syncgroups attached to this
  /// database.
  /// TODO(sadovsky): Rename to ListSyncgroups, for parity with ListDatabases.
  public func getSyncgroupNames() throws -> [String] {
    preconditionFailure("stub")
  }

  /// CreateBlob creates a new blob and returns a handle to it.
  public func createBlob() throws -> Blob {
    preconditionFailure("stub")
  }

  /// Blob returns a handle to the blob with the given BlobRef.
  public func blob(blobRef: BlobRef) -> Blob {
    preconditionFailure("stub")
  }

  /// PauseSync pauses sync for this database. Incoming sync, as well as outgoing
  /// sync of subsequent writes, will be disabled until ResumeSync is called.
  /// PauseSync is idempotent.
  public func pauseSync() throws {
    preconditionFailure("stub")
  }

  /// ResumeSync resumes sync for this database. ResumeSync is idempotent.
  public func resumeSync() throws {
    preconditionFailure("stub")
  }

  /// Close cleans up any state associated with this database handle, including
  /// closing the conflict resolution stream (if open).
  public func close() {
    preconditionFailure("stub")
  }
}

extension Database: DatabaseHandle {
  public func collection(name: String) throws -> Collection {
    return try collection(Identifier(name: name, blessing: try Principal.userBlessing()))
  }

  public func collection(collectionId: Identifier) throws -> Collection {
    guard let collection = Collection(
      databaseId: databaseId,
      collectionId: collectionId,
      batchHandle: batchHandle) else {
        throw SyncbaseError.InvalidUTF8(invalidUtf8: "\(collectionId)")
    }
    return collection
  }

  public func listCollections() throws -> [Identifier] {
    return try VError.maybeThrow { errPtr in
      var ids = v23_syncbase_Ids()
      v23_syncbase_DbListCollections(try encodedDatabaseName.toCgoString(),
        try batchHandle?.toCgoString() ?? v23_syncbase_String(),
        &ids,
        errPtr)
      return ids.toIdentifiers()
    }
  }

  public func getResumeMarker() throws -> ResumeMarker {
    preconditionFailure("stub")
  }
}

extension Database: AccessController {
  public func setPermissions(perms: Permissions, version: PermissionsVersion) throws {
    preconditionFailure("stub")
  }

  public func getPermissions() throws -> (Permissions, PermissionsVersion) {
    preconditionFailure("stub")
  }
}
