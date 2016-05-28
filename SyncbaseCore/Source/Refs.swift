// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/// RefMap holds onto objs that get referenced by AsyncId between Go and Swift.
/// The larger motivation is closures that get passed as function pointers have to be 'context-free'
/// so we can't closure on a reference to a given future. By allowing the end user to hold onto
/// this in various places (strongly typed to the appropriate T) then we can pass a handle
/// back and forth safely.
typealias AsyncId = Int32

class RefMap<T>: Lockable {
  private (set) var lastId: AsyncId = 0
  private var refs = [AsyncId: T]()

  /// Stores an object and returns the associated asyncId. If the object is already in the map
  /// it will be stored twice -- ref does not actually perform reference counting.
  func ref(obj: T) -> AsyncId {
    let asyncId = OSAtomicIncrement32(&lastId)
    lock { self.refs[asyncId] = obj }
    return asyncId
  }

  /// Gets the associated value for a given asyncId.
  func get(asyncId: AsyncId) -> T? {
    return refs[asyncId]
  }

  /// Get and deletes any associated asyncId, returning the associated value.
  func unref(asyncId: AsyncId) -> T? {
    guard let p = refs[asyncId] else { return nil }
    lock { self.refs[asyncId] = nil }
    return p
  }
}