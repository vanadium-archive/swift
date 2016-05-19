// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Service represents a Vanadium Syncbase service.
public protocol Service: AccessController {
  /// DatabaseForId returns the Database with the given app blessing and name (from the Id struct).
  func database(databaseId: Identifier) throws -> Database

  /// DatabaseForId returns the Database with the given relative name and default app blessing.
  func database(name: String) throws -> Database

  /// ListDatabases returns a list of all Database ids that the caller is allowed to see.
  /// The list is sorted by blessing, then by name.
  func listDatabases() throws -> [Identifier]
}
