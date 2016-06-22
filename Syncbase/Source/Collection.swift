// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents an ordered set of key-value pairs.
/// To get a Collection handle, call `Database.collection`.
public class Collection: CustomStringConvertible {
  let coreCollection: SyncbaseCore.Collection
  let databaseHandle: DatabaseHandle

  func createIfMissing() throws {
    do {
      try SyncbaseError.wrap {
        try self.coreCollection.create(defaultCollectionPerms())
      }
    } catch SyncbaseError.Exist {
      // Collection already exists.
    }
  }

  init(coreCollection: SyncbaseCore.Collection, databaseHandle: DatabaseHandle) {
    self.coreCollection = coreCollection
    self.databaseHandle = databaseHandle
  }

  /// Returns the id of this collection.
  public var collectionId: Identifier {
    return Identifier(coreId: coreCollection.collectionId)
  }

  /// Shortcut for `Database.getSyncgroup(collection.collectionId)`, helpful for the common case
  /// of one syncgroup per collection.
  public func syncgroup() throws -> Syncgroup {
    switch databaseHandle {
    case is BatchDatabase: throw SyncbaseError.BatchError(detail: "Must not call getSyncgroup within batch")
    case let h as Database: return h.syncgroup(collectionId)
    default: fatalError("Unexpected type")
    }
  }

  /// Returns the value associated with `key`.
  public func get<T: SyncbaseCore.SyncbaseConvertible>(key: String) throws -> T? {
    return try SyncbaseError.wrap {
      let value: T? = try self.coreCollection.get(key)
      return value
    }
  }

  /// Returns true if there is a value associated with `key`.
  public func exists(key: String) throws -> Bool {
    return try SyncbaseError.wrap {
      return try self.coreCollection.exists(key)
    }
  }

  /// Puts `value` for `key`, overwriting any existing value. This call is idempotent, meaning
  /// you can safely call it multiple times in a row with the same values.
  public func put<T: SyncbaseCore.SyncbaseConvertible>(key: String, value: T) throws {
    try SyncbaseError.wrap {
      try self.coreCollection.put(key, value: value)
    }
  }

  /// Deletes the value associated with `key`. If the row does not exist for the associated key,
  /// this call is a no-op. That is to say, `delete` is idempotent.
  public func delete(key: String) throws {
    try SyncbaseError.wrap {
      try self.coreCollection.delete(key)
    }
  }

  /// **FOR ADVANCED USERS**. Returns the `AccessList` for this collection. Users should
  /// typically manipulate access lists via `collection.syncgroup()`.
  public func accessList() throws -> AccessList {
    return try SyncbaseError.wrap {
      return try AccessList(perms: try self.coreCollection.getPermissions())
    }
  }

  /// **FOR ADVANCED USERS**. Updates the `AccessList` for this collection. Users should
  /// typically manipulate access lists via `collection.syncgroup()`}.
  public func updateAccessList(delta: AccessList) throws {
    let op = { (db: BatchDatabase) in
      try SyncbaseError.wrap {
        let vCx = try db.collection(self.collectionId).coreCollection
        let perms = try vCx.getPermissions()
        AccessList.applyDelta(perms, delta: delta)
        try vCx.setPermissions(perms)
      }
    }
    // Create a batch if we're not already in a batch.
    if let batchDb = databaseHandle as? BatchDatabase {
      try op(batchDb)
    } else {
      try (databaseHandle as! Database).runInBatch(op: op)
    }
  }

  public var description: String {
    return "[Syncbase.Collection id=\(collectionId)]"
  }
}
