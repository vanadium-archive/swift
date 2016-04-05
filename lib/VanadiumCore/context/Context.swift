// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct Context {
  internal var handle:ContextHandle {
    didSet {
      log.debug("Updated context \(self)")
    }
  }
  private var _isCancelled:Bool = false
  private var _isCancellable:Bool = false
  private var dirty:ContextFeatures = []
  public var userInfo:[String: Any] = [:]
  
  internal init(handle:ContextHandle) {
    self.handle = handle
  }
  
  internal init(handle:ContextHandle, existingDeadline:NSDate?, isCancellable:Bool) {
    self.handle = handle
    self.deadline = existingDeadline
    self._isCancellable = isCancellable
  }
  
  public mutating func client() throws -> Client {
    try updateHandleIfNeeded()
    return Client(defaultContext: self)
  }
  
  public var deadline:NSDate? {
    didSet {
      guard oldValue != deadline else { return }
      guard deadline != nil else {
        log.warning("Cannot undo a deadline once one has been set. Instead mutate the root context. This will no-op.")
        deadline = oldValue // TODO Verify that the following didSet won't be a problem
        return
      }
      //      guard oldValue == nil || deadline!.isBefore(oldValue!) else {
      //        log.warning("Cannot set a deadline that is after the old value. Instead mutate the root context. This will no-op.")
      //        deadline = oldValue // TODO Verify that the following didSet won't be a problem
      //        return
      //      }
      dirty.insert(ContextFeatures.Deadline)
    }
  }
  
  public var isCancelled:Bool { return _isCancelled }
  
  public var isCancellable:Bool {
    get {
      return !_isCancelled && (_isCancellable || dirty.contains(ContextFeatures.Cancellable))
    }
    set {
      guard _isCancellable != newValue else { return }
      guard newValue == true else {
        log.warning("Cannot set something as not cancellable once it already is marked as such. No-op.")
        return
      }
      // This shouldn't be possible given we were marked as not cancellable previously.
      guard !_isCancelled else {
        log.warning("Already cancelled, so this is a no-op.")
        return
      }
      dirty.insert(ContextFeatures.Cancellable)
    }
  }
  
  /// Cancels all associated RPC with this context and renders it unusable. Call newContext afterwards
  /// to get a similar context that is workable.
  ///
  /// If this context is not cancellable (it has already been cancelled, or a deadline/timeout
  /// was never set), then this will throw a ContextError.
  ///
  /// If it does not throw right away, the promise will never fail.
  private static let outstandingCancels = GoPromises<Void>(timeout: nil)
  public mutating func cancel() throws -> Promise<Void> {
    guard !_isCancelled else { throw ContextError.ContextIsAlreadyCancelled }
    guard _isCancellable else { throw ContextError.ContextNotCancellable }
    _isCancelled = true
    let (asyncId, p) = Context.outstandingCancels.newPromise()
    swift_io_v_v23_context_CancelableVContext_nativeCancelAsync(handle.goHandle, asyncId, { asyncId in
      if let p = Context.outstandingCancels.getAndDeleteRef(asyncId) {
        RunOnMain {
          do {
            try p.resolve()
          } catch let e {
            log.warning("Unable to resolve cancel async promise: \(e)")
          }
        }
      }
    })
    return p
  }
  
  internal mutating func updateHandleIfNeeded() throws {
    if (_isCancelled) {
      throw ContextError.ContextIsAlreadyCancelled
    }
    
    if dirty.contains(ContextFeatures.Deadline) {
      try updateHandleForDeadline()
    }
    
    if dirty.contains(ContextFeatures.Cancellable) {
      try updateHandleForCancellable()
    }
  }
  
  private mutating func updateHandleForDeadline() throws {
    guard let deadline = deadline else {
      fatalError("Deadline was assumed to not be nil here, yet was marked as dirty")
    }
    let goHandle = try SwiftVError.catchAndThrowError { errPtr in
      return swift_io_v_v23_context_VContext_nativeWithDeadline(
        self.handle.goHandle, deadline.timeIntervalSince1970, errPtr)
    }
    _isCancellable = true
    dirty.remove(ContextFeatures.Deadline)
    handle = ContextHandle(goHandle)
  }
  
  private mutating func updateHandleForCancellable() throws {
    let goHandle = try SwiftVError.catchAndThrowError { errPtr in
      return swift_io_v_v23_context_VContext_nativeWithCancel(
        self.handle.goHandle, errPtr)
    }
    _isCancellable = true
    dirty.remove(ContextFeatures.Cancellable)
    handle = ContextHandle(goHandle)
  }
  
  internal mutating func run<T>(@autoclosure block: () throws ->T) throws -> T {
    guard !_isCancelled else { throw ContextError.ContextIsAlreadyCancelled }
    try updateHandleIfNeeded()
    return try block()
  }
}

public class ContextHandle: CustomStringConvertible, CustomDebugStringConvertible {
  internal let goHandle:GoContextHandle
  
  internal init(_ goHandle:GoContextHandle) {
    self.goHandle = goHandle
  }

  deinit {
    if goHandle != 0 {
      swift_io_v_v23_context_VContext_nativeFinalize(goHandle)
    }
  }
  
  public var description: String { return "[ContextHandle \(goHandle)]" }
  public var debugDescription: String { return "[ContextHandle handle=\(goHandle)]" }
}

struct ContextFeatures: OptionSetType {
  let rawValue: Int
  static let Deadline = ContextFeatures(rawValue: 1 << 1)
  static let Cancellable = ContextFeatures(rawValue: 1 << 2)
  // Make sure to add any new ones to updateHandleIfNeeded
  // Unforutnately Swift doesn't yet give us a good enum-style way to iterate on this and prevent
  // future bugs.
}

enum ContextError: ErrorType {
  case ContextNotCancellable
  case ContextIsAlreadyCancelled
}
