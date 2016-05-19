// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum SyncbaseError: ErrorType, CustomStringConvertible {
  case NotAuthorized
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
  case InvalidOperation(reason: String)
  case PermissionsSerializationError(permissions: Permissions?)
  case InvalidUTF8(invalidUtf8: String)

  public var description: String {
    switch (self) {
    case .NotAuthorized: return "no valid blessings; create new blessings using oauth"
    case .NotInDevMode: return "not running with --dev=true"
    case .UnknownBatch: return "unknown batch, perhaps the server restarted"
    case .NotBoundToBatch: return "not bound to batch"
    case .ReadOnlyBatch: return "batch is read-only"
    case .ConcurrentBatch: return "concurrent batch"
    case .BlobNotCommitted: return "blob is not yet committed"
    case .SyncgroupJoinFailed: return "syncgroup join failed"
    case .BadExecStreamHeader: return "Exec stream header improperly formatted"
    case .InvalidName(let name): return "invalid name: \(name)"
    case .CorruptDatabase(let path):
      return "database corrupt, moved to path \(path); client must create a new database"
    case .InvalidOperation(let reason): return "invalid operation: \(reason)"
    case .PermissionsSerializationError(let permissions): return "unable to serialize permissions: \(permissions)"
    case .InvalidUTF8(let invalidUtf8): return "unable to convert to utf8: \(invalidUtf8)"
    }
  }
}