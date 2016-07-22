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
  /// Throws if the id cannot be encoded into UTF-8.
  func collection(collectionId: Identifier) throws -> Collection

  /// ListCollections returns a list of all Collection ids that the caller is
  /// allowed to see. The list is sorted by blessing, then by name.
  func listCollections() throws -> [Identifier]

  /// Returns a ResumeMarker that points to the current end of the event log.
  func getResumeMarker() throws -> ResumeMarker
}

public class SyncgroupInvitesScanHandler {
  public let onInvite: SyncgroupInvite -> Void
  var isStopped: Bool = false
  let isStoppedMu: NSLock = NSLock()

  public init(onInvite: SyncgroupInvite -> Void) {
    self.onInvite = onInvite
  }
}

public class Database {
  public let databaseId: Identifier
  let batchHandle: String?
  let encodedDatabaseName: String

  init(databaseId: Identifier, batchHandle: String?) throws {
    self.databaseId = databaseId
    self.batchHandle = batchHandle
    self.encodedDatabaseName = try databaseId.encode().toString()!
  }

  /// Create creates this Database.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  public func create(permissions: Permissions?) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbCreate(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Permissions(permissions),
        errPtr)
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
      var exists = false
      v23_syncbase_DbExists(try encodedDatabaseName.toCgoString(), &exists, errPtr)
      return exists
    }
  }

  /**
   BeginBatch creates a new batch. Instead of calling this function directly,
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
    var cHandle = v23_syncbase_String()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbBeginBatch(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_BatchOptions(options),
        &cHandle,
        errPtr)
    }
    guard let handle = cHandle.toString() else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: "\(cHandle)")
    }
    return try BatchDatabase(databaseId: databaseId, batchHandle: handle)
  }

  /// Watch allows a client to watch for updates to the database. At least one
  /// pattern must be specified. For each watch request, the client will receive
  /// a reliable stream of watch events without reordering. Only rows matching at
  /// least one of the patterns are returned. Rows in collections with no Read
  /// access are also filtered out.
  ///
  /// If a nil ResumeMarker is provided, the WatchStream will begin with a Change
  /// batch containing the initial state. Otherwise, the WatchStream will contain
  /// only changes since the provided ResumeMarker.
  ///
  /// The response stream consists of a sequence of Change messages. Each
  /// Change message contains an optional continued bit
  /// (default=false). A sub-sequence of Change messages with
  /// continued=true followed by a Change message with continued=false
  /// forms an "atomic group". We expect that most callers will ignore the
  /// notion of atomic delivery and the continued bit, i.e., they will just process
  /// each Change message as it is received.
  public func watch(patterns: [CollectionRowPattern], resumeMarker: ResumeMarker? = nil) throws -> WatchStream {
    return try Watch.watch(encodedDatabaseName: encodedDatabaseName, patterns: patterns, resumeMarker: resumeMarker)
  }

  /// Syncgroup returns a handle to the syncgroup with the given name.
  public func syncgroup(name: String) throws -> Syncgroup {
    return Syncgroup(
      encodedDatabaseName: encodedDatabaseName,
      syncgroupId: Identifier(name: name, blessing: try Principal.userBlessing()))
  }

  /// Syncgroup returns a handle to the syncgroup with the given identifier.
  public func syncgroup(syncgroupId: Identifier) -> Syncgroup {
    return Syncgroup(encodedDatabaseName: encodedDatabaseName, syncgroupId: syncgroupId)
  }

  /// ListSyncgroups returns the identifiers of all syncgroups attached to this database.
  public func listSyncgroups() throws -> [Identifier] {
    var ids = v23_syncbase_Ids()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbListSyncgroups(
        try encodedDatabaseName.toCgoString(),
        &ids,
        errPtr)
    }
    return ids.toIdentifiers()
  }

  public func scanForSyncgroupInvites(name: String, handler: SyncgroupInvitesScanHandler) throws {
    let unmanaged = Unmanaged.passRetained(handler)
    let oHandle = UnsafeMutablePointer<Void>(unmanaged.toOpaque())
    do {
      try VError.maybeThrow { errPtr in
        v23_syncbase_DbSyncgroupInvitesNewScan(
          try encodedDatabaseName.toCgoString(),
          v23_syncbase_DbSyncgroupInvitesCallbacks(
            handle: v23_syncbase_Handle(unsafeBitCast(oHandle, UInt.self)),
            onInvite: { Database.onInvite($0, invite: $1) }
          ),
          errPtr)
      }
    } catch let e {
      unmanaged.release()
      throw e
    }
  }

  // Callback handlers that convert the Cgo bridge types to native Swift types and pass them to
  // the functions inside the passed handle.
  private static func onInvite(handle: v23_syncbase_Handle, invite: v23_syncbase_Invite) {
    let invite = invite.toSyncgroupInvite()!
    let handle = Unmanaged<SyncgroupInvitesScanHandler>.fromOpaque(
      COpaquePointer(bitPattern: handle)).takeUnretainedValue()
    dispatch_async(Syncbase.queue) {
      handle.onInvite(invite)
    }
  }

  public func stopSyncgroupInvitesScan(handler: SyncgroupInvitesScanHandler) {
    handler.isStoppedMu.lock()
    defer { handler.isStoppedMu.unlock() }
    if handler.isStopped {
      // Prevent double-free.
      return
    }
    let unmanaged = Unmanaged.passRetained(handler)
    let oHandle = UnsafeMutablePointer<Void>(unmanaged.toOpaque())
    v23_syncbase_DbSyncgroupInvitesStopScan(unsafeBitCast(oHandle, UInt.self))
    unmanaged.release()
    handler.isStopped = true
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
    return try Collection(
      databaseId: databaseId,
      collectionId: collectionId,
      batchHandle: batchHandle)
  }

  public func listCollections() throws -> [Identifier] {
    return try VError.maybeThrow { errPtr in
      var ids = v23_syncbase_Ids()
      v23_syncbase_DbListCollections(
        try encodedDatabaseName.toCgoString(),
        try batchHandle?.toCgoString() ?? v23_syncbase_String(),
        &ids,
        errPtr)
      return ids.toIdentifiers()
    }
  }

  public func getResumeMarker() throws -> ResumeMarker {
    var cMarker = v23_syncbase_Bytes()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbGetResumeMarker(
        try encodedDatabaseName.toCgoString(),
        try batchHandle?.toCgoString() ?? v23_syncbase_String(),
        &cMarker,
        errPtr)
    }
    return ResumeMarker(data: cMarker.toNSData() ?? NSData())
  }
}

extension Database: AccessController {
  public func getPermissions() throws -> (Permissions, PermissionsVersion) {
    var cPermissions = v23_syncbase_Permissions()
    var cVersion = v23_syncbase_String()
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbGetPermissions(
        try encodedDatabaseName.toCgoString(),
        &cPermissions,
        &cVersion,
        errPtr)
    }
    // TODO(zinman): Verify that permissions defaulting to zero-value is correct for Permissions.
    // We force cast of cVersion because we know it can be UTF-8 converted.
    return (try cPermissions.toPermissions() ?? Permissions(), cVersion.toString()!)
  }

  public func setPermissions(permissions: Permissions, version: PermissionsVersion) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbSetPermissions(
        try encodedDatabaseName.toCgoString(),
        try v23_syncbase_Permissions(permissions),
        try version.toCgoString(),
        errPtr)
    }
  }
}
