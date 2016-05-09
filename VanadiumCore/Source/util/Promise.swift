// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public enum PromiseErrors<ResolveType>: ErrorType {
  case AlreadyResolved(existingObj:ResolveType)
  case AlreadyRejected(existingErr:ErrorType?)
  case Timeout
}

public enum PromiseResolution<ResolveType> {
  case Pending
  case Resolved(obj:ResolveType)
  case Rejected(err:ErrorType?)
}

public class Promise<ResolveType> : Lockable {

  private var resolveCallbacks:[(dispatch_queue_t?, ResolveType->())]? = nil
  private var rejectCallbacks:[(dispatch_queue_t?, ErrorType?->())]? = nil
  private var alwaysCallbacks:[(dispatch_queue_t?, PromiseResolution<ResolveType>->())]? = nil
  private let resolutionSemaphore = dispatch_semaphore_create(0)

  internal var status: PromiseResolution<ResolveType> = PromiseResolution.Pending {
    didSet {
      updatedStatus()
    }
  }

  public init() { }

  public convenience init(resolved obj: ResolveType) {
    self.init()
    status = PromiseResolution<ResolveType>.Resolved(obj: obj)
  }

  public convenience init(rejected err: ErrorType?) {
    self.init()
    status = PromiseResolution<ResolveType>.Rejected(err: err)
  }

  // Resolve/reject
  public func resolve(obj:ResolveType) throws {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    switch (status) {
    case .Rejected(let err): throw PromiseErrors<ResolveType>.AlreadyRejected(existingErr: err)
    case .Resolved(let obj): throw PromiseErrors<ResolveType>.AlreadyResolved(existingObj: obj)
    case .Pending: status = PromiseResolution.Resolved(obj: obj)
    }
  }

  public func reject(err:ErrorType?) throws {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    switch (status) {
    case .Rejected(let err): throw PromiseErrors<ResolveType>.AlreadyRejected(existingErr: err)
    case .Resolved(let obj): throw PromiseErrors<ResolveType>.AlreadyResolved(existingObj: obj)
    case .Pending: status = PromiseResolution.Rejected(err: err)
    }
  }

  // Chain/handle state
  public func onResolve(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
                        _ callback:ResolveType->()) -> Promise<ResolveType> {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    switch(status) {
    case .Resolved(let obj): dispatch_maybe_async(queue, block: { callback(obj) })
    case .Rejected: break
    case .Pending:
      if resolveCallbacks == nil {
        resolveCallbacks = []
      }
      resolveCallbacks!.append((queue, callback))
    }

    return self
  }

  public func onReject(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
                       _ callback:ErrorType?->()) -> Promise<ResolveType> {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    switch(status) {
    case .Resolved: break
    case .Rejected(let err): dispatch_maybe_async(queue, block: { callback(err) })
    case .Pending:
      if rejectCallbacks == nil {
        rejectCallbacks = []
      }
      rejectCallbacks!.append((queue, callback))
    }
    return self
  }

  public func always(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
                     _ callback:PromiseResolution<ResolveType>->()) -> Promise<ResolveType> {
    objc_sync_enter(self)
    defer { objc_sync_exit(self) }
    let s = status
    switch(s) {
    case .Pending:
      if alwaysCallbacks == nil {
        alwaysCallbacks = []
      }
      alwaysCallbacks!.append((queue, callback))
    default: dispatch_maybe_async(queue, block: { callback(s) })
    }
    return self
  }

  public func await(timeout: NSTimeInterval?=nil) throws -> PromiseResolution<ResolveType> {
    switch (status) {
    case .Pending:
      if let timeout = timeout {
        if dispatch_semaphore_wait(resolutionSemaphore, dispatch_time_t.fromNSTimeInterval(timeout)) != 0 {
          throw PromiseErrors<ResolveType>.Timeout
        }
      } else {
        dispatch_semaphore_wait(resolutionSemaphore, DISPATCH_TIME_FOREVER)
      }
    default: break
    }
    return status
  }

  // Changing states
  internal func updatedStatus() {
    // Do reject/resolve callbacks, then always callbacks
    let s = status
    switch (s) {
    case .Pending: return // Don't do anything, but this shouldn't happen
    case .Rejected(let err):
      guard let callbacks = rejectCallbacks else { break }
      for (queue, callback) in callbacks {
        dispatch_maybe_async(queue) {
          callback(err)
        }
      }
    case .Resolved(let obj):
      guard let callbacks = resolveCallbacks else { break }
      for (queue, callback) in callbacks {
        dispatch_maybe_async(queue) {
          callback(obj)
        }
      }
    }

    defer { dispatch_semaphore_signal(resolutionSemaphore) }
    guard let callbacks = alwaysCallbacks else { return }
    for (queue, callback) in callbacks {
      dispatch_maybe_async(queue) {
        callback(s)
      }
    }
  }
}

public class ResolvedPromise<ResolveType>: Promise<ResolveType> {
  var resolvedObj:ResolveType

  override private init() {
    fatalError("Cannot init this way")
  }

  public convenience init(_ resolved: ResolveType) {
    self.init(resolved: resolved)
    self.resolvedObj = resolved
    dispatch_semaphore_signal(resolutionSemaphore)
  }

  override public func onResolve(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
    _ callback:ResolveType->()) -> Promise<ResolveType> {
      dispatch_maybe_async(queue, block: { callback(self.resolvedObj) })
      return self
  }

  override public func always(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
    _ callback:PromiseResolution<ResolveType>->()) -> Promise<ResolveType> {
      dispatch_maybe_async(queue, block: { callback(self.status) })
      return self
  }

  override public func resolve(obj:ResolveType) throws {
    throw PromiseErrors<ResolveType>.AlreadyResolved(existingObj: resolvedObj)
  }

  override public func reject(err:ErrorType?) throws {
    throw PromiseErrors<ResolveType>.AlreadyResolved(existingObj: resolvedObj)
  }
}

public class RejectedPromise: Promise<Void> {
  var err:ErrorType?

  override private init() {
    fatalError("Cannot init this way")
  }

  public convenience init(_ error: ErrorType?) {
    self.init(rejected: error)
    self.err = error
    dispatch_semaphore_signal(resolutionSemaphore)
  }

  override public func onReject(on queue: dispatch_queue_t?, _ callback: ErrorType? -> ()) -> Promise<Void> {
    dispatch_maybe_async(queue, block: { callback(self.err) })
    return self
  }

  override public func always(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
    _ callback:PromiseResolution<Void>->()) -> Promise<Void> {
    dispatch_maybe_async(queue, block: { callback(self.status) })
    return self
  }

  override public func resolve(obj:Void) throws {
    throw PromiseErrors<Void>.AlreadyRejected(existingErr: self.err)
  }

  override public func reject(err:ErrorType?) throws {
    throw PromiseErrors<Void>.AlreadyRejected(existingErr: self.err)
  }
}

/// Quick initializers for already resolved/rejected constructors
public extension Promise {
  public static func resolved() -> Promise<Void> { return Promise<Void>(resolved: ()) }
  public static func resolved(obj:ResolveType) -> Promise<ResolveType> { return ResolvedPromise(obj) }
  public static func rejected(err:ErrorType? = nil) -> Promise<Void> { return RejectedPromise(err) }
}

/// Chaining API
public extension Promise {
  func then<T>(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
               _ callback:ResolveType throws ->T) -> Promise<T> {
    let p = Promise<T>()
    onResolve(on: queue) { obj in
      do {
        let transformed = try callback(obj)
        try p.resolve(transformed)
      } catch let e {
        try! p.reject(e)
      }
    }
    onReject(on: queue) { err in
      try! p.reject(err)
    }
    return p
  }

  /// Specialize then for when it returns another Promise to hook onto that automatically
  func then<T>(on queue: dispatch_queue_t?=dispatch_get_main_queue(),
               _ callback:ResolveType throws ->Promise<T>) -> Promise<T> {
    let p = Promise<T>()

    onResolve(on: queue) { obj in
      do {
        let newPromise = try callback(obj)
        newPromise.onResolve(on: queue) { obj in
          do {
            try p.resolve(obj)
          } catch let e {
            try! p.reject(e)
          }
        }
        newPromise.onReject(on: queue) { err in
          try! p.reject(err)
        }
      } catch let e {
        try! p.reject(e)
      }
    }

    onReject(on: queue) { err in
      try! p.reject(err)
    }
    return p
  }

  func thenInBackground<T>(callback:ResolveType throws ->T) -> Promise<T> {
    return then(on: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), callback)
  }

  func thenOnSameThread<T>(callback:ResolveType throws ->T) -> Promise<T> {
    return then(on: nil, callback)
  }
}

/// Visibility into status
public extension Promise {
  public func isPending() -> Bool {
    switch (status) {
    case .Pending: return true
    default: return false
    }
  }

  public func isResolved() -> Bool {
    switch (status) {
    case .Resolved: return true
    default: return false
    }
  }

  public func isRejected() -> Bool {
    switch (status) {
    case .Rejected: return true
    default: return false
    }
  }
}

/// Utilities for timeout functionality
public extension Promise {
  /// Timeout (reject) if not resolved or rejected within a given timeframe
  public func rejectAfterDelay(on queue:dispatch_queue_t=dispatch_get_main_queue(), delay:NSTimeInterval) {
    dispatch_after_delay(delay, queue: queue, block: {
      switch (self.status) {
      case .Pending:
        do { try self.reject(PromiseErrors<ResolveType>.Timeout) }
        catch { }
      default: break
      }
    })
  }
}