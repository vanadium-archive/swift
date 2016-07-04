// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

// Counter to allow SyncgroupInviteHandler and WatchChangeHandler structs to be unique and hashable.
var uniqueIdCounter: Int32 = 0

/// Handles discovered syncgroup invites.
public struct SyncgroupInviteHandler: Hashable, Equatable {
  /// Called when a syncgroup invitation is discovered. Clients typically handle invites by
  /// calling `acceptSyncgroupInvite` or `ignoreSyncgroupInvite`.
  public let onInvite: SyncgroupInvite -> Void

  /// Called when an error occurs while scanning for syncgroup invitations. Once
  /// `onError` is called, no other methods will be called on this handler.
  public let onError: ErrorType -> Void

  // This internal-only variable allows us to test SyncgroupInviteHandler structs for equality.
  // This cannot be done otherwise as function calls cannot be tested for equality.
  // Equality is important to facilitate the add/remove APIs in Database where
  // handlers are directly passed for removal instead of other indirect identifier.
  let uniqueId = OSAtomicIncrement32(&uniqueIdCounter)

  public var hashValue: Int {
    return uniqueId.hashValue
  }
}

public func == (lhs: SyncgroupInviteHandler, rhs: SyncgroupInviteHandler) -> Bool {
  return lhs.uniqueId == rhs.uniqueId
}

/// Handles observed changes to the database.
public struct WatchChangeHandler: Hashable, Equatable {
  /// Called once, when a watch change handler is added, to provide the initial state of the
  /// values being watched.
  public let onInitialState: [WatchChange] -> Void

  /// Called whenever a batch of changes is committed to the database. Individual puts/deletes
  /// surface as a single-change batch.
  public let onChangeBatch: [WatchChange] -> Void

  /// Called when an error occurs while watching for changes. Once `onError` is called,
  /// no other methods will be called on this handler.
  public let onError: ErrorType -> Void

  public init(
    onInitialState: [WatchChange] -> Void,
    onChangeBatch: [WatchChange] -> Void,
    onError: ErrorType -> Void) {
      self.onInitialState = onInitialState
      self.onChangeBatch = onChangeBatch
      self.onError = onError
  }

  // This internal-only variable allows us to test WatchChangeHandler structs for equality.
  // This cannot be done otherwise as function calls cannot be tested for equality.
  // Equality is important to facilitate the add/remove APIs in Database where
  // handlers are directly passed for removal instead of other indirect identifier.
  let uniqueId = OSAtomicIncrement32(&uniqueIdCounter)

  public var hashValue: Int {
    return uniqueId.hashValue
  }
}

public func == (lhs: WatchChangeHandler, rhs: WatchChangeHandler) -> Bool {
  return lhs.uniqueId == rhs.uniqueId
}

struct HandlerOperation {
  let databaseId: SyncbaseCore.Identifier
  let queue: dispatch_queue_t
  let cancel: Void -> Void
}

/// A set of collections and syncgroups.
/// To get a Database handle, call `Syncbase.database`.
public class Database: DatabaseHandle, CustomStringConvertible {
  let coreDatabase: SyncbaseCore.Database

  // These are all static because we might have active handlers to a database while it goes
  // out of scope (e.g. the user gets the database, then adds a watch handler, but doesn't retain
  // the original reference to Database). Instead, we store the databaseId to make sure that any two
  // Database instances generated from Syncbase.database behave the same with respect to
  // adding/removing watch handlers.
  private static let syncgroupInviteHandlersMu = NSLock()
  private static let watchChangeHandlersMu = NSLock()
  private static var syncgroupInviteHandlers: [SyncgroupInviteHandler: HandlerOperation] = [:]
  private static var watchChangeHandlers: [WatchChangeHandler: HandlerOperation] = [:]

  func createIfMissing() throws {
    do {
      try SyncbaseError.wrap {
        try self.coreDatabase.create(try defaultDatabasePerms())
      }
    } catch SyncbaseError.Exist {
      // Database already exists, presumably from a previous run of the app.
    }
  }

  init(coreDatabase: SyncbaseCore.Database) {
    self.coreDatabase = coreDatabase
  }

  public var databaseId: Identifier {
    return Identifier(coreId: coreDatabase.databaseId)
  }

  public func collection(name: String, withoutSyncgroup: Bool = false) throws -> Collection {
    let res = try collection(Identifier(name: name, blessing: personalBlessingString()))
    try res.createIfMissing()
    // TODO(sadovsky): Unwind collection creation on syncgroup creation failure? It would be
    // nice if we could create the collection and syncgroup in a batch.
    if (!withoutSyncgroup) {
      try syncgroup(name, collections: [res])
    }
    return res
  }

  public func collection(collectionId: Identifier) throws -> Collection {
    // TODO(sadovsky): Consider throwing an exception or returning null if the collection does
    // not exist. But note, a collection can get destroyed via sync after a client obtains a
    // handle for it, so perhaps we should instead add an 'exists' method.
    return try SyncbaseError.wrap {
      return try Collection(
        coreCollection: self.coreDatabase.collection(collectionId.toCore()),
        databaseHandle: self)
    }
  }

  /// Returns all collections in the database.
  public func collections() throws -> [Collection] {
    return try SyncbaseError.wrap {
      let coreIds = try self.coreDatabase.listCollections().filter({ return $0.name != Syncbase.USERDATA_SYNCGROUP_NAME })
      return try coreIds.map { coreId in
        return Collection(
          coreCollection: try self.coreDatabase.collection(coreId),
          databaseHandle: self)
      }
    }
  }

  /// **FOR ADVANCED USERS**. Creates syncgroup and adds it to the user's "userdata" collection, as
  /// needed. Idempotent. The id of the new syncgroup will include the creator's user id and the
  /// given syncgroup name. Requires that all collections were created by the current user.
  ///
  /// - parameter name:        Name of the syncgroup.
  /// - parameter collections: Collections in the syncgroup.
  ///
  /// - returns: The created syncgroup.
  public func syncgroup(name: String, collections: [Collection]) throws -> Syncgroup {
    if (collections.isEmpty) {
      throw SyncbaseError.IllegalArgument(detail: "No collections specified")
    }
    let id = Identifier(name: name, blessing: collections[0].collectionId.blessing)
    for cx in collections {
      if (cx.collectionId.blessing != id.blessing) {
        throw SyncbaseError.BlessingError(detail: "Collections must all have the same creator")
      }
    }
    return try SyncbaseError.wrap {
      let res = Syncgroup(coreSyncgroup: self.coreDatabase.syncgroup(id.toCore()), database: self)
      try res.createIfMissing(collections)
      // Remember this syncgroup in the userdata collection. The value doesn't matter, so we use
      // empty data.
      // Note: We may eventually want to use the value to deal with rejected invitations.
      try Syncbase.userDataCollection!.put(try id.encode(), value: NSData())
      return res
    }
  }

  /// Returns the syncgroup with the given id.
  public func syncgroup(syncgroupId: Identifier) -> Syncgroup {
    // TODO(sadovsky): Consider throwing an exception or returning null if the syncgroup does
    // not exist. But note, a syncgroup can get destroyed via sync after a client obtains a
    // handle for it, so perhaps we should instead add an 'exists' method.
    return Syncgroup(
      coreSyncgroup: coreDatabase.syncgroup(syncgroupId.toCore()),
      database: self)
  }

  /// Returns all syncgroups in the database.
  public func syncgroups() throws -> [Syncgroup] {
    return try SyncbaseError.wrap {
      let coreIds = try self.coreDatabase.listSyncgroups().filter({ return $0.name != Syncbase.USERDATA_SYNCGROUP_NAME })
      return coreIds.map { coreId in
        return Syncgroup(coreSyncgroup: self.coreDatabase.syncgroup(coreId), database: self)
      }
    }
  }

  /// Notifies `handler` of any existing syncgroup invites, and of all subsequent new invites.
  public func addSyncgroupInviteHandler(handler: SyncgroupInviteHandler) {
    Database.syncgroupInviteHandlersMu.lock()
    defer { Database.syncgroupInviteHandlersMu.unlock() }
    preconditionFailure("Not implemented")
  }

  /// Makes it so `handler` stops receiving notifications.
  public func removeSyncgroupInviteHandler(handler: SyncgroupInviteHandler) {
    Database.syncgroupInviteHandlersMu.lock()
    let op = Database.syncgroupInviteHandlers[handler]
    Database.syncgroupInviteHandlersMu.unlock()
    if let op = op {
      op.cancel()
    }
  }

  /// Makes it so all syncgroup invite handlers stop receiving notifications.
  public func removeAllSyncgroupInviteHandlers() {
    // Grab a local copy by value so we don't need to worry about concurrency or deadlocking
    // on the main mutex.
    Database.syncgroupInviteHandlersMu.lock()
    let handlers = Database.syncgroupInviteHandlers
    Database.syncgroupInviteHandlersMu.unlock()
    for op in handlers.values {
      if op.databaseId == coreDatabase.databaseId {
        op.cancel()
      }
    }
  }

  public typealias AcceptSyncgroupInviteCallback = (sg: Syncgroup?, err: ErrorType?) -> Void

  /// Joins the syncgroup associated with the given invite and adds it to the user's "userdata"
  /// collection, as needed.
  ///
  /// - parameter invite: The syncgroup invite.
  /// - parameter callback: The callback run on Syncbase.`queue` with either the accepted Syncgroup
  /// or an error.
  public func acceptSyncgroupInvite(invite: SyncgroupInvite, callback: AcceptSyncgroupInviteCallback) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
      do {
        try SyncbaseError.wrap {
          let coreSyncgroup = self.coreDatabase.syncgroup(invite.syncgroupId.toCore())
          let syncgroup = Syncgroup(coreSyncgroup: coreSyncgroup, database: self)
          try coreSyncgroup.join(invite.remoteSyncbaseName,
            expectedSyncbaseBlessings: invite.expectedSyncbaseBlessings,
            myInfo: Syncgroup.syncgroupMemberInfo)
          dispatch_async(Syncbase.queue) {
            callback(sg: syncgroup, err: nil)
          }
        }
      } catch let e {
        dispatch_async(Syncbase.queue) {
          callback(sg: nil, err: e)
        }
      }
    }
  }

  /// Records that the user has ignored this invite, such that it's never surfaced again.
  public func ignoreSyncgroupInvite(invite: SyncgroupInvite) {
    preconditionFailure("Not implemented")
  }

  /// Runs the given operation in a batch, managing retries and commit/abort. Writable batches are
  /// committed, retrying if commit fails due to a concurrent batch. Read-only batches are aborted.
  ///
  /// - parameter readOnly: Run batch in read-only mode.
  /// - parameter op:       The operation to run.
  public func runInBatch(readOnly: Bool = false, op: BatchOperation) throws {
    // TODO(zinman): Is this suppose to be async?
    try SyncbaseError.wrap {
      try SyncbaseCore.Batch.runInBatchSync(
        db: self.coreDatabase,
        opts: SyncbaseCore.BatchOptions(readOnly: readOnly),
        op: { coreDb in try op(BatchDatabase(coreBatchDatabase: coreDb)) })
    }
  }

  /// Creates a new batch. Instead of calling this function directly, clients are encouraged to use
  /// the `runInBatch` helper function, which detects "concurrent batch" errors and handles
  /// retries internally.
  ///
  /// Default concurrency semantics:
  /// - Reads (e.g. gets, scans) inside a batch operate over a consistent snapshot taken during
  /// `beginBatch`, and will see the effects of prior writes performed inside the batch.
  /// - `commit` may fail with `ConcurrentBatch` exception, indicating that after
  /// `beginBatch` but before `commit`, some concurrent routine wrote to a key that
  /// matches a key or row-range read inside this batch.
  /// - Other methods will never fail with error `ConcurrentBatch`, even if it is
  /// known that `commit` will fail with this error.
  ///
  /// Once a batch has been committed or aborted, subsequent method calls will fail with no
  /// effect.
  ///
  /// Concurrency semantics can be configured using the optional parameters.
  ///
  /// - parameter readOnly: If true, set the transaction to read-only.
  ///
  /// - returns: The BatchDatabase object representing the transaction.
  public func beginBatch(readOnly: Bool = false) throws -> BatchDatabase {
    return try SyncbaseError.wrap {
      return BatchDatabase(coreBatchDatabase:
          try self.coreDatabase.beginBatch(BatchOptions(readOnly: readOnly)))
    }
  }

  /// Notifies `handler` of initial state, and of all subsequent changes to this database. If this
  /// handler is canceled by `removeWatchChangeHandler` then no subsequent calls will be made. Note
  /// that there may be WatchChanges queued up for a `OnChangeBatch` that will be ignored.
  /// Callbacks to `handler` occur on Syncbase.queue, which defaults to main.
  public func addWatchChangeHandler(
    pattern pattern: CollectionRowPattern = CollectionRowPattern.Everything,
    resumeMarker: ResumeMarker? = nil,
    handler: WatchChangeHandler) throws {
      try addWatchChangeHandler(
        pattern: pattern,
        resumeMarker: resumeMarker,
        isWatchingUserdata: false,
        handler: handler)
  }

  /// Internal function to watch only the userData collection which normally gets filtered out.
  func addUserDataWatchChangeHandler(
    resumeMarker: ResumeMarker? = nil,
    handler: WatchChangeHandler) throws {
      try addWatchChangeHandler(
        pattern: CollectionRowPattern(collectionName: Syncbase.USERDATA_SYNCGROUP_NAME),
        resumeMarker: resumeMarker,
        isWatchingUserdata: true,
        handler: handler)
  }

  private func addWatchChangeHandler(
    pattern pattern: CollectionRowPattern,
    resumeMarker: ResumeMarker?,
    isWatchingUserdata: Bool,
    handler: WatchChangeHandler) throws {
      // Note: Eventually we'll add a watch variant that takes a query, where the query can be
      // constructed using some sort of query builder API.
      // TODO(sadovsky): Support specifying resumeMarker. Note, watch-from-resumeMarker may be
      // problematic in that we don't track the governing ACL for changes in the watch log.
      if let resumeMarker = resumeMarker where resumeMarker.length != 0 {
        throw SyncbaseError.IllegalArgument(detail: "Specifying resumeMarker is not yet supported")
      }
      return try SyncbaseError.wrap {
        let stream = try self.coreDatabase.watch([pattern.toCore()], resumeMarker: resumeMarker)
        // Create a serial queue to immediately run this watch operation on via SyncbaseCore's
        // blocking stream.
        let watchQueue = dispatch_queue_create(
          "Syncbase WatchChangeHandler \(handler.uniqueId)",
          DISPATCH_QUEUE_SERIAL)
        var isCanceled = false
        Database.watchChangeHandlersMu.lock()
        defer { Database.watchChangeHandlersMu.unlock() }
        Database.watchChangeHandlers[handler] = HandlerOperation(
          databaseId: self.coreDatabase.databaseId,
          queue: watchQueue,
          cancel: {
            isCanceled = true
            stream.cancel()
        })
        dispatch_async(watchQueue) {
          var gotFirstBatch = false
          var batch = [WatchChange]()
          for coreChange in stream {
            if isCanceled {
              break
            }
            // Don't pass root entity to end-user.
            if coreChange.entityType != .Root {
              let change = WatchChange(coreChange: coreChange)
              // Ignore changes to userdata collection unless we're explicitly looking for it, and
              if (isWatchingUserdata || change.collectionId?.name != Syncbase.USERDATA_SYNCGROUP_NAME) {
                batch.append(change)
              }
            }
            if (!coreChange.isContinued) {
              if (!gotFirstBatch) {
                gotFirstBatch = true
                // We synchronously run on Syncbase.queue to facilitate flow control. Go blocks
                // until each callback is consumed before it calls with another WatchChange event.
                // Backpressure in Swift is achieved by blocking until the WatchChange event is
                // consumed by the app on Syncbase.queue using dispatch_sync. If we used
                // dispatch_async, we could potentially queue up events faster than the
                // ability for the app to consume them. By using dispatch_sync we also help the user
                // mitigate against out-of-order events should Syncbase.queue be a concurrent queue
                // rather than a serial queue.
                dispatch_sync(Syncbase.queue, {
                  handler.onInitialState(batch)
                })
              } else {
                dispatch_sync(Syncbase.queue, {
                  handler.onChangeBatch(batch)
                })
              }
              batch.removeAll()
            }
          }
          // Notify of error if we're permitted (not canceled).
          if let err = stream.err() where !isCanceled {
            dispatch_sync(Syncbase.queue, {
              handler.onError(err)
            })
          }
          // Cleanup
          Database.watchChangeHandlersMu.lock()
          defer { Database.watchChangeHandlersMu.unlock() }
          Database.watchChangeHandlers[handler] = nil
        }
      }
  }

  /// Makes it so `handler` stops receiving notifications. Note there may be queued WatchChanges
  /// queued up for a `OnChangeBatch` that will be ignored.
  public func removeWatchChangeHandler(handler: WatchChangeHandler) {
    Database.watchChangeHandlersMu.lock()
    let op = Database.watchChangeHandlers[handler]
    Database.watchChangeHandlersMu.unlock()
    if let op = op {
      op.cancel()
    }
  }

  /// Makes it so all watch change handlers stop receiving notifications attached to this database.
  public func removeAllWatchChangeHandlers() {
    // Grab a local copy by value so we don't need to worry about concurrency or deadlocking
    // on the main mutex.
    Database.watchChangeHandlersMu.lock()
    let handlers = Database.watchChangeHandlers
    Database.watchChangeHandlersMu.unlock()
    for op in handlers.values {
      // Because Database.watchChangeHandlers is static, we must make sure the database ids
      // are the same before we cancel it.
      if op.databaseId == self.coreDatabase.databaseId {
        op.cancel()
      }
    }
  }

  public var description: String {
    return "[Syncbase.Database id=\(databaseId)]"
  }
}