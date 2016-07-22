// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum Batch {
  public typealias BatchCompletionHandler = ErrorType? -> Void
  public typealias Operation = BatchDatabase throws -> Void

  /**
   Runs the given batch operation, managing retries and BatchDatabase's commit() and abort()s.

   This is run in a background thread and calls back on main.

   - Parameter retries:      number of retries attempted before giving up. defaults to 3
   - Parameter db:           database on which the batch operation is to be performed
   - Parameter opts:         batch configuration
   - Parameter op:           batch operation
   - Parameter completionHandler:      future result called when runInBatch finishes
   */
  public static func runInBatch(retries: Int = 3,
    db: Database,
    opts: BatchOptions?,
    op: Operation,
    completionHandler: BatchCompletionHandler) {
      dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
        for _ in 0 ... retries {
          // TODO(sadovsky): Commit() can fail for a number of reasons, e.g. RPC
          // failure or ErrConcurrentTransaction. Depending on the cause of failure,
          // it may be desirable to retry the Commit() and/or to call Abort().
          var err: ErrorType? = nil
          do {
            try attemptBatch(db, opts: opts, op: op)
            err = nil
          } catch SyncbaseError.ConcurrentBatch {
            continue
          } catch {
            log.warning("Unable to complete batch operation: \(error)")
            err = error
          }
          dispatch_async(Syncbase.queue) {
            completionHandler(err)
          }
          return
        }
        // We never were able to do it without error
        dispatch_async(Syncbase.queue) {
          completionHandler(SyncbaseError.ConcurrentBatch)
        }
      }
  }

  /**
   Runs the given batch operation, managing retries and BatchDatabase's commit() and abort()s.

   This is run in a background thread and calls back on main.

   - Parameter retries:      number of retries attempted before giving up. defaults to 3
   - Parameter db:           database on which the batch operation is to be performed
   - Parameter opts:         batch configuration
   - Parameter op:           batch operation
   - Parameter completionHandler:      future result called when runInBatch finishes
   */
  public static func runInBatchSync(retries: Int = 3,
    db: Database,
    opts: BatchOptions?,
    op: Operation) throws {
      for _ in 0 ... retries {
        // TODO(sadovsky): Commit() can fail for a number of reasons, e.g. RPC
        // failure or ErrConcurrentTransaction. Depending on the cause of failure,
        // it may be desirable to retry the Commit() and/or to call Abort().
        do {
          try attemptBatch(db, opts: opts, op: op)
          return
        } catch SyncbaseError.ConcurrentBatch {
          continue
        } catch {
          log.warning("Unable to complete batch operation: \(error)")
          throw error
        }
      }
      // We never were able to do it without error.
      throw SyncbaseError.ConcurrentBatch
  }

  private static func attemptBatch(db: Database, opts: BatchOptions?, op: Operation) throws {
    let batchDb = try db.beginBatch(opts)
    // Use defer for abort to make sure it gets called in case op throws.
    var commitCalled = false
    defer {
      if !commitCalled {
        do {
          try batchDb.abort()
        } catch {
          log.warning("Unable abort the non-comitted batch: \(error)")
        }
      }
    }
    // Attempt operation
    try op(batchDb)
    // A readonly batch should be Aborted; Commit would fail.
    if opts?.readOnly ?? false {
      return
    }
    // Commit is about to be called, do not call Abort.
    commitCalled = true
    do {
      try batchDb.commit()
    } catch SyncbaseError.UnknownBatch {
      // Occurs if op called batchDb.abort() or batchDb.commit() -- ignore the unknown batch
      // at this point.
    }
  }
}

public struct BatchOptions {
  /// Arbitrary string, typically used to describe the intent behind a batch.
  /// Hints are surfaced to clients during conflict resolution.
  /// TODO(sadovsky): Use "any" here?
  public let hint: String?

  /// ReadOnly specifies whether the batch should allow writes.
  /// If ReadOnly is set to true, Abort() should be used to release any resources
  /// associated with this batch (though it is not strictly required), and
  /// Commit() will always fail.
  public let readOnly: Bool

  public init(hint: String? = nil, readOnly: Bool = false) {
    self.hint = hint
    self.readOnly = readOnly
  }
}

public class BatchDatabase: Database {
  /// Commit persists the pending changes to the database.
  /// If the batch is readonly, Commit() will fail with ErrReadOnlyBatch; Abort()
  /// should be used instead.
  public func commit() throws {
    guard let cHandle = try batchHandle?.toCgoString() else {
      throw SyncbaseError.UnknownBatch
    }
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbCommit(
        try encodedDatabaseName.toCgoString(),
        cHandle,
        errPtr)
    }
  }

  /// Abort notifies the server that any pending changes can be discarded.
  /// It is not strictly required, but it may allow the server to release locks
  /// or other resources sooner than if it was not called.
  public func abort() throws {
    guard let cHandle = try batchHandle?.toCgoString() else {
      throw SyncbaseError.UnknownBatch
    }
    try VError.maybeThrow { errPtr in
      v23_syncbase_DbAbort(
        try encodedDatabaseName.toCgoString(),
        cHandle,
        errPtr)
    }
  }
}
