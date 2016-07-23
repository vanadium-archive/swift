// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum SyncbaseError: ErrorType, CustomStringConvertible {
  case AlreadyConfigured
  case NotConfigured
  case NotLoggedIn
  case NotAuthorized
  case NotInDevMode
  case UnknownBatch
  case NotBoundToBatch
  case ReadOnlyBatch
  case ConcurrentBatch
  case BlobNotCommitted
  case SyncgroupJoinFailed(detail: String)
  case BadExecStreamHeader
  case InvalidPermissionsChange
  case Exist
  case NoExist
  case SerializationError(detail: String)
  case DeserializationError(detail: String)
  case InvalidName(name: String)
  case CorruptDatabase(path: String)
  case InvalidOperation(reason: String)
  case InvalidUTF8(invalidUtf8: String)
  case CastError(obj: Any)
  case IllegalArgument(detail: String)
  case NoAccess(detail: String)
  case UnknownVError(err: VError)

  init(_ err: VError) {
    // TODO(zinman): Make VError better by having the proper arguments transmitted across
    // so we don't have to use err.msg to repeat our messages.
    switch err.id {
    case "v.io/v23/services/syncbase.NotInDevMode": self = SyncbaseError.NotInDevMode
    case "v.io/v23/services/syncbase.InvalidName": self = SyncbaseError.InvalidName(name: err.msg)
    case "v.io/v23/services/syncbase.CorruptDatabase": self = SyncbaseError.CorruptDatabase(path: err.msg)
    case "v.io/v23/services/syncbase.UnknownBatch": self = SyncbaseError.UnknownBatch
    case "v.io/v23/services/syncbase.NotBoundToBatch": self = SyncbaseError.NotBoundToBatch
    case "v.io/v23/services/syncbase.ReadOnlyBatch": self = SyncbaseError.ReadOnlyBatch
    case "v.io/v23/services/syncbase.ConcurrentBatch": self = SyncbaseError.ConcurrentBatch
    case "v.io/v23/services/syncbase.BlobNotCommitted": self = SyncbaseError.BlobNotCommitted
    case "v.io/v23/services/syncbase.SyncgroupJoinFailed": self = SyncbaseError.SyncgroupJoinFailed(detail: err.msg)
    case "v.io/v23/services/syncbase.BadExecStreamHeader": self = SyncbaseError.BadExecStreamHeader
    case "v.io/v23/services/syncbase.InvalidPermissionsChange": self = SyncbaseError.InvalidPermissionsChange
    case "v.io/v23/verror.Exist": self = SyncbaseError.Exist
    case "v.io/v23/verror.NoExist": self = SyncbaseError.NoExist
    case "v.io/v23/verror.NoAccess": self = SyncbaseError.NoAccess(detail: err.msg)
    default: self = SyncbaseError.UnknownVError(err: err)
    }
  }

  public var description: String {
    switch (self) {
    case .AlreadyConfigured: return "Already configured"
    case .NotConfigured: return "Not configured (via Syncbase.configure)"
    case .NotLoggedIn: return "Not logged in (via Syncbase.login)"
    case .NotAuthorized: return "No valid blessings; create new blessings using oauth"
    case .NotInDevMode: return "Not running with --dev=true"
    case .UnknownBatch: return "Unknown batch, perhaps the server restarted"
    case .NotBoundToBatch: return "Not bound to batch"
    case .ReadOnlyBatch: return "Batch is read-only"
    case .ConcurrentBatch: return "Concurrent batch"
    case .BlobNotCommitted: return "Blob is not yet committed"
    case .SyncgroupJoinFailed(let detail): return "Syncgroup join failed: \(detail)"
    case .BadExecStreamHeader: return "Exec stream header improperly formatted"
    case .InvalidPermissionsChange: return "The sequence of permission changes is invalid"
    case .NoExist: return "Does not exist"
    case .Exist: return "Already exists"
    case .InvalidName(let name): return "Invalid name: \(name)"
    case .CorruptDatabase(let path):
      return "Database corrupt, moved to path \(path); client must create a new database"
    case .InvalidOperation(let reason): return "Invalid operation: \(reason)"
    case .InvalidUTF8(let invalidUtf8): return "Unable to convert to UTF-8: \(invalidUtf8)"
    case .CastError(let obj): return "Unable to convert to cast: \(obj)"
    case .IllegalArgument(let detail): return "Illegal argument: \(detail)"
    case .NoAccess(let detail): return "Access Denied: \(detail)"
    case .SerializationError(let detail): return "Serialization Error: \(detail)"
    case .DeserializationError(let detail): return "Deserialization Error: \(detail)"
    case .UnknownVError(let err): return "Unknown error: \(err)"
    }
  }
}
