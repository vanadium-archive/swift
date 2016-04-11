// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/// Class to hold onto promises that get referenced by AsyncId between Go and Swift.
/// The larger motivation is closures that get passed as function pointers have to be 'context-free'
/// so we can't closure on a reference to a given future. By allowing the end user to hold onto
/// this in various places (strongly typed to the appropriate ResolveType) then we can pass a handle
/// back and forth safely.
internal class GoPromises<ResolveType> : Lockable {
  typealias AsyncId = Int32
  private (set) var lastId:AsyncId = 0
  private var promises = [AsyncId:Promise<ResolveType>]()
  private let timeoutDelay:NSTimeInterval?
  internal init(timeout:NSTimeInterval?) {
    timeoutDelay = timeout
  }

  internal func newPromise() -> (AsyncId, Promise<ResolveType>) {
    let p = Promise<ResolveType>()
    if let timeout = timeoutDelay { p.rejectAfterDelay(delay: timeout) }
    let asyncId = OSAtomicIncrement32(&lastId)
    lock { self.promises[asyncId] = p }
    p.always { _ in
      // Guarantee we delete the ref on resolution
      // (can happen on delayed timeout that it wouldn't get cleaned)
      self.lock { self.promises[asyncId] = nil }
    }
    return (asyncId, p)
  }

  internal func getAndDeleteRef(asyncId:AsyncId) -> Promise<ResolveType>? {
    guard let p = promises[asyncId] else { return nil }
    lock { self.promises[asyncId] = nil }
    return p
  }
}