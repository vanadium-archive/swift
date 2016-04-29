// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Service represents a Vanadium Syncbase service.
public protocol Service: AccessController {
  /// FullName returns the object name (encoded) of this Service.
  var fullName: String { get }

  /// DatabaseForId returns the Database with the given app blessing and name (from the Id struct).
  /// This is equivalent to calling database(id.name, id.blessing)
  func database(databaseId: DatabaseId) -> Database

  /// DatabaseForId returns the Database with the given name and app blessing.
  func database(name: String) throws -> Database

  /// ListDatabases returns a list of all Database ids that the caller is allowed to see.
  /// The list is sorted by blessing, then by name.
  func listDatabases() throws -> [DatabaseId]
}
