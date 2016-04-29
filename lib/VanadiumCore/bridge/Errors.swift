// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// VError is the primary vehicle for errors in Vanadium. Errors can be defined and customized
/// in VDL which will get auto-generated to static instantiations of VError. Runtime errors
/// should contain all the context-sensitive information such as a stacktrace, messages, etc.
public struct VError : ErrorType, Equatable {
  public let identity:String
  public let action:ErrorAction
  public let msg:String?
  public let stacktrace:String?
}

/// Equality for VError is determined SOLELY by comparing identifiers. Identifiers are required
/// to be unique in VDL. Equality is defined this way as the primary use case is to compare
/// runtime VErrors against VDL-generated static errors. For example:
///
/// do { throw VError(identity: "syncbase.Error", action: ErrorAction.NoRetry,
///                   msg: "some msg", stacktrace: nil)
/// } catch let e as VError {
///   switch e {
///   case Syncbase.Error: print("Comparing only identity allowed this")
///   }
/// }
public func ==(lhs: VError, rhs: VError) -> Bool {
  return lhs.identity == rhs.identity
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
      throw err
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
