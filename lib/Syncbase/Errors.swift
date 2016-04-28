// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum SyncbaseError: ErrorType, CustomStringConvertible {
  case NotInDevMode
  case UnknownBatch
  case NotBoundToBatch
  case ReadOnlyBatch
  case ConcurrentBatch
  case BlobNotCommitted
  case SyncgroupJoinFailed
  case BadExecStreamHeader
  case InvalidName(name: String)
  case CorruptDatabase(path: String)

  public var description: String {
    switch (self) {
    case NotInDevMode: return "not running with --dev=true"
    case UnknownBatch: return "unknown batch, perhaps the server restarted"
    case NotBoundToBatch: return "not bound to batch"
    case ReadOnlyBatch: return "batch is read-only"
    case ConcurrentBatch: return "concurrent batch"
    case BlobNotCommitted: return "blob is not yet committed"
    case SyncgroupJoinFailed: return "syncgroup join failed"
    case BadExecStreamHeader: return "Exec stream header improperly formatted"
    case InvalidName(let name): return "invalid name: \(name)"
    case CorruptDatabase(let path):
      return "database corrupt, moved to path \(path); client must create a new database"
    }
  }
}