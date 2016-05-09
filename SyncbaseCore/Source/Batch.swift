// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

internal class BatchHandle {
}

public enum Batch {
  public typealias BatchCompletionHandler = SyncbaseError? -> Void
  public typealias Operation = Void -> BatchCompletionHandler

  /**
   Runs the given batch operation, managing retries and BatchDatabase's commit() and abort()s.

   - Parameter db:      database on which the batch operation is to be performed
   - Parameter opts:    batch configuration
   - Parameter op:      batch operation
   - Parameter completionHandler:      future result called when runInBatch finishes
   */
  public static func runInBatch(db: Database, opts: BatchOptions, op: Operation, completionHandler: BatchCompletionHandler) {
    preconditionFailure("stub")
  }
}

public struct BatchOptions {
  /// Arbitrary string, typically used to describe the intent behind a batch.
  /// Hints are surfaced to clients during conflict resolution.
  /// TODO(sadovsky): Use "any" here?
  public let hint: String? = nil

  /// ReadOnly specifies whether the batch should allow writes.
  /// If ReadOnly is set to true, Abort() should be used to release any resources
  /// associated with this batch (though it is not strictly required), and
  /// Commit() will always fail.
  public let readOnly: Bool = false
}

public protocol BatchDatabase: DatabaseHandle {
  /// Commit persists the pending changes to the database.
  /// If the batch is readonly, Commit() will fail with ErrReadOnlyBatch; Abort()
  /// should be used instead.
  func commit() throws

  /// Abort notifies the server that any pending changes can be discarded.
  /// It is not strictly required, but it may allow the server to release locks
  /// or other resources sooner than if it was not called.
  func abort() throws
}
