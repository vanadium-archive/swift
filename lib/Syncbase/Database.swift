// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// DatabaseHandle is the set of methods that work both with and without a batch.
/// It allows clients to pass the handle to helper methods that are batch-agnostic.
public protocol DatabaseHandle {
  /// Id returns the id of this DatabaseHandle..
  var databaseId: DatabaseId { get }

  /// FullName returns the object name (encoded) of this DatabaseHandle.
  var fullName: String { get }

  /// Collection returns the Collection with the given relative name.
  /// The user blessing is derived from the context.
  func collection(name: String) -> Collection?

  /// CollectionForId returns the Collection with the given user blessing and name.
  func collection(collectionId: CollectionId) -> Collection?

  /// ListCollections returns a list of all Collection ids that the caller is
  /// allowed to see. The list is sorted by blessing, then by name.
  func listCollections() throws -> [CollectionId]

  /// Returns a ResumeMarker that points to the current end of the event log.
  func getResumeMarker() throws -> ResumeMarker
}

public protocol Database: DatabaseHandle, AccessController {
  /// Create creates this Database.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  func create(permissions: Permissions?) throws

  /// Destroy destroys this Database, permanently removing all of its data.
  /// TODO(sadovsky): Specify what happens to syncgroups.
  func destroy() throws

  // Exists returns true only if this Database exists. Insufficient permissions
  // cause Exists to return false instead of an error.
  func exists() throws -> Bool

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
  func beginBatch(options: BatchOptions?) throws -> BatchDatabase

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
  func watch(collection: CollectionId, prefix: String, resumeMarker: ResumeMarker?) throws -> WatchStream

  /// Syncgroup returns a handle to the syncgroup with the given name.
  func syncgroup(sgName: String) -> Syncgroup

  /// GetSyncgroupNames returns the names of all syncgroups attached to this
  /// database.
  /// TODO(sadovsky): Rename to ListSyncgroups, for parity with ListDatabases.
  func getSyncgroupNames() throws -> [String]

  /// CreateBlob creates a new blob and returns a handle to it.
  func createBlob() throws -> Blob

  /// Blob returns a handle to the blob with the given BlobRef.
  func blob(blobRef: BlobRef) -> Blob

  /// PauseSync pauses sync for this database. Incoming sync, as well as outgoing
  /// sync of subsequent writes, will be disabled until ResumeSync is called.
  /// PauseSync is idempotent.
  func pauseSync() throws

  /// ResumeSync resumes sync for this database. ResumeSync is idempotent.
  func resumeSync() throws

  /// Close cleans up any state associated with this database handle, including
  /// closing the conflict resolution stream (if open).
  func close()
}
