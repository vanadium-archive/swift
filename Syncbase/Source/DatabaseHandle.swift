// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents a handle to a database, possibly in a batch.
public protocol DatabaseHandle {
  /// The id of this database.
  var databaseId: Identifier { get }

  /// Creates a new collection and an associated syncgroup, as needed. The id of the new
  /// collection will include the creator's user id and its name will be a UUID, optionally starting
  /// with `prefix`. Upon creation, the collection is set to AccessLevel `READ_WRITE` for the
  /// creator. If `withoutSyncgroup` is false, then a syncgroup will also be created with
  /// AccessLevel `READ_WRITE` and can be accessed by calling `syncgroup()` on the returned
  /// collection. If a syncgroup is created, then this collection will sync with the user's other
  /// devices when they're nearby (and discovered via BLE or mDNS) or conected by any network path.
  /// If a syncgroup is not created, then this collection will be local only.
  ///
  /// May only be called within a batch if `withoutSyncgroup` is set to true.
  ///
  /// - parameter prefix: A prefix that will preface the randomly generated UUID. Defaults to 'cx'.
  /// - parameter withoutSyncgroup: If true, don't create an associated syncgroup. Defaults to false.
  ///
  /// - throws: SyncbaseError on unicode errors, or if there was a problem creating the database.
  ///
  /// - returns: The collection handle.
  func createCollection(prefix prefix: String, withoutSyncgroup: Bool) throws -> Collection

  /// Returns the collection with the given id.
  func collection(collectionId: Identifier) throws -> Collection

  /// Returns all collections in the database.
  func collections() throws -> [Collection]
}
