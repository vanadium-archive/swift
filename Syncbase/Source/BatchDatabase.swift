// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

public typealias BatchOperation = BatchDatabase throws -> Void

/// Provides a way to perform a set of operations atomically on a database. See
/// `Database.beginBatch` for concurrency semantics.
public class BatchDatabase: DatabaseHandle {
  private let coreBatchDatabase: SyncbaseCore.BatchDatabase

  init(coreBatchDatabase: SyncbaseCore.BatchDatabase) {
    self.coreBatchDatabase = coreBatchDatabase
  }

  public var databaseId: Identifier {
    return Identifier(coreId: coreBatchDatabase.databaseId)
  }

  public func collection(name: String, withoutSyncgroup: Bool = false) throws -> Collection {
    if (!withoutSyncgroup) {
      throw SyncbaseError.BatchError(detail: "Cannot create syncgroup in a batch")
    }
    let res = try collection(Identifier(name: name, blessing: personalBlessingString()))
    try res.createIfMissing()
    return res
  }

  public func collection(collectionId: Identifier) throws -> Collection {
    // TODO(sadovsky): Consider throwing an exception or returning null if the collection does
    // not exist. But note, a collection can get destroyed via sync after a client obtains a
    // handle for it, so perhaps we should instead add an 'exists' method.
    return try SyncbaseError.wrap {
      return try Collection(
        coreCollection: self.coreBatchDatabase.collection(collectionId.toCore()),
        databaseHandle: self)
    }
  }

  /// Returns all collections in the database.
  public func collections() throws -> [Collection] {
    return try SyncbaseError.wrap {
      let coreIds = try self.coreBatchDatabase.listCollections()
      return try coreIds.map { coreId in
        return Collection(
          coreCollection: try self.coreBatchDatabase.collection(coreId),
          databaseHandle: self)
      }
    }
  }

  /// Persists the pending changes to Syncbase. If the batch is read-only, `commit` will
  /// throw `ConcurrentBatchException`; abort should be used instead.
  public func commit() throws {
    // TODO(sadovsky): Throw ConcurrentBatchException where appropriate.
    try SyncbaseError.wrap { try self.coreBatchDatabase.commit() }
  }

  /// Notifies Syncbase that any pending changes can be discarded. Calling `abort` is not
  /// strictly required, but may allow Syncbase to release locks or other resources sooner than if
  /// `abort` was not called.
  public func abort() throws {
    try SyncbaseError.wrap { try self.coreBatchDatabase.abort() }
  }
}
