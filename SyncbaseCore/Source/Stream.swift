// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Base protocol for iterating through elements of unknown length.
public protocol Stream: GeneratorType {
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
public struct AnonymousStream<T>: Stream {
  public typealias Element = T
  public typealias FetchNextFunction = Void -> (T?, SyncbaseError?)
  let fetchNextFunction: FetchNextFunction
  public typealias CancelFunction = Void -> Void
  let cancelFunction: CancelFunction
  private var lastErr: SyncbaseError?
  private var isCancelled: Bool = false
  init(fetchNextFunction: FetchNextFunction, cancelFunction: CancelFunction) {
    self.fetchNextFunction = fetchNextFunction
    self.cancelFunction = cancelFunction
  }

  /// Advance to the next element and return it, or `nil` if no next
  /// element exists.
  ///
  /// - Requires: `next()` has not been applied to a copy of `self`
  /// since the copy was made, and no preceding call to `self.next()`
  /// has returned `nil`.  Specific implementations of this protocol
  /// are encouraged to respond to violations of this requirement by
  /// calling `preconditionFailure("...")`.
  public mutating func next() -> T? {
    guard !isCancelled else {
      return nil
    }
    let (result, err) = fetchNextFunction()
    if let ret = result {
      return ret
    }
    lastErr = err
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
  public mutating func cancel() {
    if !isCancelled {
      cancelFunction()
      isCancelled = true
    }
  }
}
