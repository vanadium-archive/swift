// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Base protocol for iterating through elements of unknown length.
public protocol Stream: SequenceType, GeneratorType {
  /// Err returns a non-nil error iff the stream encountered any errors. Err does
  /// not block.
  func err() -> SyncbaseError?

  /// Cancel notifies the stream provider that it can stop producing elements.
  /// The client must call Cancel if it does not iterate through all elements
  /// (i.e. until Advance returns false). Cancel is idempotent and can be called
  /// concurrently with a goroutine that is iterating via Advance.
  /// Cancel causes Advance to subsequently return false. Cancel does not block.
  mutating func cancel()
}

/// Typed-stream backed by anonymous callbacks
public class AnonymousStream<T>: Stream {
  public typealias Element = T
  public typealias FetchNextFunction = NSTimeInterval? -> (T?, SyncbaseError?)
  let fetchNextFunction: FetchNextFunction
  public typealias CancelFunction = Void -> Void
  let cancelFunction: CancelFunction
  private var lastErr: SyncbaseError?
  private var isDone: Bool = false
  init(fetchNextFunction: FetchNextFunction, cancelFunction: CancelFunction) {
    self.fetchNextFunction = fetchNextFunction
    self.cancelFunction = cancelFunction
  }

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists. If the stream has not been canceled, this call
  /// will block until data is available or an error has occured.
  public func next() -> T? {
    return next(nil)
  }

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists. If the stream has not been canceled, this call
  /// will block until data is available, an error has occured, or
  /// `timeout` seconds have elapsed. If a timeout occurs then the
  /// return value will be nil.
  public func next(timeout timeout: NSTimeInterval) -> T? {
    return next(timeout)
  }

  private func next(timeout: NSTimeInterval?) -> T? {
    guard !isDone else {
      return nil
    }
    let (result, err) = fetchNextFunction(timeout)
    if let ret = result {
      return ret
    }
    lastErr = err
    isDone = true
    return nil
  }

  /// Err returns a non-nil error iff the stream encountered any errors. Err does
  /// not block.
  public func err() -> SyncbaseError? {
    return lastErr
  }

  /// Cancel notifies the stream provider that it can stop producing elements.
  /// The client must call Cancel if it does not iterate through all elements
  /// (i.e. until Advance returns false). Cancel is idempotent and can be called
  /// concurrently with a goroutine that is iterating via Advance.
  /// Cancel causes Advance to subsequently return false. Cancel does not block.
  public func cancel() {
    if !isDone {
      cancelFunction()
      isDone = true
    }
  }
}
