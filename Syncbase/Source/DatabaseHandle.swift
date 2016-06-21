// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents a handle to a database, possibly in a batch.
public protocol DatabaseHandle {
  /// The id of this database.
  var databaseId: Identifier { get }

  /// Creates a collection and an associated syncgroup, as needed. Idempotent. The id of the new
  /// collection will include the creator's user id and the given collection name. Upon creation,
  /// both the collection and syncgroup are `READ_WRITE` for the creator. Setting
  /// `opts.withoutSyncgroup` prevents syncgroup creation. May only be called within a batch
  /// if `opts.withoutSyncgroup` is set.
  ///
  /// - parameter name: Name of the collection.
  /// - parameter withoutSyncgroup: If true, don't create an associated syncgroup. Defaults to false.
  ///
  /// - throws: SyncbaseError on unicode errors, or if there was a problem creating the database.
  ///
  /// - returns: The collection handle.
  func collection(name: String, withoutSyncgroup: Bool) throws -> Collection

  /// Returns the collection with the given id.
  func collection(collectionId: Identifier) throws -> Collection

  /// Returns all collections in the database.
  func collections() throws -> [Collection]
}
