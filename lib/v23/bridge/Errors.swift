// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct VError : ErrorType {
  public let identity:String
  public let action:ErrorAction
  public let msg:String?
  public let stacktrace:String?
  public static var _delegate:_VErrorHandler = DefaultVErrorHandler()
}

public protocol _VErrorHandler {
  func lookupErr(err:VError) -> ErrorType
  func doThrow(err:VError) throws
}

public struct DefaultVErrorHandler:  _VErrorHandler {
  public func lookupErr(err:VError) -> ErrorType {
    return err
  }
  
  public func doThrow(err:VError) throws {
    log.warning("Throwing low-level error without handler (did VDL generation fail?):\n\tIdentity: " +
      "\(err.identity)\n\tAction: \(err.action)\n\tMsg: \(err.msg ?? "")\n\tStacktrace: \(err.stacktrace ?? "")")
    throw err
  }
}

/// SwiftVError is the C struct that the go bridge uses to transfer an error to Swift.
internal extension SwiftVError {
  internal func isEmpty() -> Bool { return identity == nil || identity.memory == 0 }
 
  /// Helper to run a go-bridge method that might fill out this struct on error. In that scenario
  /// we translate that into a Swift-based error and throw it.
  /// VError's static _delegate slot is the actual function that throws a given converted VError
  /// into its apropriate enum-based error. That error will be generated from the VDL, which is why
  /// we need this hook here. A default handler just throws the VError itself, which is of ErrorType.
  internal static func catchAndThrowError<T>(@noescape block: UnsafeMutablePointer<SwiftVError>->T) throws -> T {
    let ptr = UnsafeMutablePointer<SwiftVError>.alloc(1)
    defer { ptr.dealloc(1) }
    ptr.initialize(SwiftVError())
    let ret = block(ptr)
    let verr = ptr.memory
    if !verr.isEmpty() {
      let err = verr.toSwift()
      try VError._delegate.doThrow(err)
    }
    return ret
  }

  /// Convert the C Struct into a Swift-based VError struct. 
  /// Go allocates the underlying strings, and swift must take control of them and free them when done
  internal func toSwift() -> VError {
    return VError(
      identity: String.fromCStringNoCopy(identity, freeWhenDone: true)!,
      action: ErrorAction.init(rawValue: UInt32(actionCode)) ?? ErrorAction.NoRetry,
      msg: String.fromCStringNoCopy(msg, freeWhenDone: true),
      stacktrace: String.fromCStringNoCopy(stacktrace, freeWhenDone: true))
  }
}

public enum ErrorAction: UInt32 {
  case NoRetry = 0 // Do not retry.
  case RetryConnection = 1 // Renew high-level connection/context.
  case RetryRefetch = 2 // Refetch and retry (e.g., out of date HTTP ETag)
  case RetryBackoff = 3 // Backoff and retry a finite number of times.
}
