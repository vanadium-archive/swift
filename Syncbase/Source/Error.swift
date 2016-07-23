// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

public enum SyncbaseError: ErrorType {
  case AlreadyConfigured
  case NotConfigured
  case NotLoggedIn
  case BatchError(detail: String)
  case BlessingError(detail: String)
  case UnknownError(err: ErrorType)
  // From SyncbaseCore
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

  init(coreError: SyncbaseCore.SyncbaseError) {
    switch coreError {
    case .AlreadyConfigured: self = .AlreadyConfigured
    case .NotConfigured: self = .NotConfigured
    case .NotLoggedIn: self = .NotLoggedIn
    case .NotAuthorized: self = .NotAuthorized
    case .NotInDevMode: self = .NotInDevMode
    case .UnknownBatch: self = .UnknownBatch
    case .NotBoundToBatch: self = .NotBoundToBatch
    case .ReadOnlyBatch: self = .ReadOnlyBatch
    case .ConcurrentBatch: self = .ConcurrentBatch
    case .BlobNotCommitted: self = .BlobNotCommitted
    case .SyncgroupJoinFailed(let detail): self = .SyncgroupJoinFailed(detail: detail)
    case .BadExecStreamHeader: self = .BadExecStreamHeader
    case .InvalidPermissionsChange: self = .InvalidPermissionsChange
    case .Exist: self = .Exist
    case .NoExist: self = .NoExist
    case .InvalidName(let name): self = .InvalidName(name: name)
    case .CorruptDatabase(let path): self = .CorruptDatabase(path: path)
    case .InvalidOperation(let reason): self = .InvalidOperation(reason: reason)
    case .InvalidUTF8(let invalidUtf8): self = .InvalidUTF8(invalidUtf8: invalidUtf8)
    case .CastError(let obj): self = .CastError(obj: obj)
    case .IllegalArgument(let detail): self = .IllegalArgument(detail: detail)
    case .NoAccess(let detail): self = .NoAccess(detail: detail)
    case .SerializationError(let detail): self = .SerializationError(detail: detail)
    case .DeserializationError(let detail): self = .DeserializationError(detail: detail)
    case .UnknownVError(let err): self = .UnknownVError(err: err)
    }
  }

  static func wrap<T>(block: Void throws -> T) throws -> T {
    do {
      return try block()
    } catch let e as SyncbaseCore.SyncbaseError {
      throw SyncbaseError(coreError: e)
    } catch let e as VError {
      throw SyncbaseError.UnknownVError(err: e)
    } catch {
      throw SyncbaseError.UnknownError(err: error)
    }
  }
}

extension SyncbaseError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .BatchError(let detail): return "Batch error: \(detail)"
    case .BlessingError(let detail): return "Blessing error: \(detail)"
    case .UnknownError(let err): return "Unknown error: \(err)"
      // From SyncbaseCore
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
    case .Exist: return "Already exists"
    case .NoExist: return "Does not exist"
    case .InvalidName(let name): return "Invalid name: \(name)"
    case .CorruptDatabase(let path):
      return "Database corrupt, moved to path \(path); client must create a new database"
    case .InvalidOperation(let reason): return "Invalid operation: \(reason)"
    case .InvalidUTF8(let invalidUtf8): return "Unable to convert to utf8: \(invalidUtf8)"
    case .CastError(let obj): return "Unable to convert to cast: \(obj)"
    case .IllegalArgument(let detail): return "Illegal argument: \(detail)"
    case .NoAccess(let detail): return "Access Denied: \(detail)"
    case .SerializationError(let detail): return "Serialization Error: \(detail)"
    case .DeserializationError(let detail): return "Deserialization Error: \(detail)"
    case .UnknownVError(let err): return "Unknown error: \(err)"
    }
  }
}
