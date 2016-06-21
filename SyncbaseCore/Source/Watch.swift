// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// CollectionRowPattern contains SQL LIKE-style glob patterns ('%' and '_'
/// wildcards, '\' as escape character) for matching rows and collections by
/// name components. It is used by the Database.watch API.
public struct CollectionRowPattern {
  /// collectionName is a SQL LIKE-style glob pattern ('%' and '_' wildcards, '\' as escape
  /// character) for matching collections. May not be empty.
  public let collectionName: String

  /// The blessing for collections.
  public let collectionBlessing: String

  /// rowKey is a SQL LIKE-style glob pattern ('%' and '_' wildcards, '\' as escape character)
  /// for matching rows. If empty then only the collectionId pattern is matched.
  public let rowKey: String?

  public init(collectionName: String, collectionBlessing: String, rowKey: String?) {
    self.collectionName = collectionName
    self.collectionBlessing = collectionBlessing
    self.rowKey = rowKey
  }
}

public typealias ResumeMarker = NSData

public struct WatchChange {
  public enum ChangeType: Int {
    case Put
    case Delete
  }

  /// Collection is the id of the collection that contains the changed row.
  public let collectionId: Identifier

  /// Row is the key of the changed row.
  public let row: String

  /// ChangeType describes the type of the change. If ChangeType is PutChange,
  /// then the row exists in the collection, and Value can be called to obtain
  /// the new value for this row. If ChangeType is DeleteChange, then the row was
  /// removed from the collection.
  public let changeType: ChangeType

  /// value is the new value for the row if the ChangeType is PutChange, or nil
  /// otherwise.
  public let value: NSData?

  /// ResumeMarker provides a compact representation of all the messages that
  /// have been received by the caller for the given Watch call.
  /// This marker can be provided in the Request message to allow the caller
  /// to resume the stream watching at a specific point without fetching the
  /// initial state.
  public let resumeMarker: ResumeMarker

  /// FromSync indicates whether the change came from sync. If FromSync is false,
  /// then the change originated from the local device.
  public let isFromSync: Bool

  /// If true, this WatchChange is followed by more WatchChanges that are in the
  /// same batch as this WatchChange.
  public let isContinued: Bool
}

public typealias WatchStream = AnonymousStream<WatchChange>

/// Internal namespace for the watch API -- end-users will access this through Database.watch
/// instead. This is simply here to allow all watch-related code to be located in Watch.swift.
enum Watch {
  private class Handle {
    // Watch works by having Go call Swift as encounters each watch change.
    // This is a bit of a mismatch for the Swift GeneratorType which is pull instead of push-based.
    // Similar to collection.Scan, we create a push-pull adapter by blocking on either side using
    // condition variables until both are ready for the next data handoff. See collection.Scan
    // for more information.
    let condition = NSCondition()
    var data: WatchChange? = nil
    var streamErr: ErrorType? = nil
    var updateAvailable = false

    // The anonymous function that gets called from the Swift. It blocks until there's an update
    // available from Go.
    func fetchNext(timeout: NSTimeInterval?) -> (WatchChange?, ErrorType?) {
      condition.lock()
      while !updateAvailable {
        if let timeout = timeout {
          if !condition.waitUntilDate(NSDate(timeIntervalSinceNow: timeout)) {
            condition.unlock()
            return (nil, nil)
          }
        } else {
          condition.wait()
        }
      }
      // Grab the data from this update and reset for the next update.
      let fetchedData = data
      data = nil
      // We don't need to locally capture doneErr because, unlike data, errors can only come in
      // once at the very end of the stream (after which no more callbacks will get called).
      updateAvailable = false
      // Signal that we've fetched the data to Go.
      condition.signal()
      condition.unlock()
      return (fetchedData, streamErr)
    }

    // The callback from Go when there's a new Row (key-value) scanned.
    func onChange(change: WatchChange) {
      condition.lock()
      // Wait until any existing update has been received by the fetch so we don't just blow
      // past it.
      while updateAvailable {
        condition.wait()
      }
      // Set the new data.
      data = change
      updateAvailable = true
      // Wake up any blocked fetch.
      condition.signal()
      condition.unlock()
    }

    // The callback from Go when there's been an error in the watch stream. The stream will then
    // be closed and no new changes will ever come in from this request.
    func onError(err: ErrorType) {
      condition.lock()
      // Wait until any existing update has been received by the fetch so we don't just blow
      // past it.
      while updateAvailable {
        condition.wait()
      }
      // Marks the end of data by clearing it and saving the error from Syncbase.
      data = nil
      streamErr = err
      updateAvailable = true
      // Wake up any blocked fetch.
      condition.signal()
      condition.unlock()
    }
  }

  static func watch(
    encodedDatabaseName encodedDatabaseName: String,
    patterns: [CollectionRowPattern],
    resumeMarker: ResumeMarker? = nil) throws -> WatchStream {
      let handle = Watch.Handle()
      try VError.maybeThrow { errPtr in
        let oHandle = UnsafeMutablePointer<Void>(Unmanaged.passRetained(handle).toOpaque())
        let cPatterns = try v23_syncbase_CollectionRowPatterns(patterns)
        let cResumeMarker = v23_syncbase_Bytes(resumeMarker)
        let callbacks = v23_syncbase_DbWatchPatternsCallbacks(
          handle: v23_syncbase_Handle(oHandle),
          onChange: { Watch.onWatchChange($0, change: $1) },
          onError: { Watch.onWatchError($0, err: $1) })
        v23_syncbase_DbWatchPatterns(
          try encodedDatabaseName.toCgoString(),
          cResumeMarker,
          cPatterns,
          callbacks,
          errPtr)
      }

      return AnonymousStream(
        fetchNextFunction: handle.fetchNext,
        cancelFunction: { preconditionFailure("stub") })
  }

  // Callback handlers that convert the Cgo bridge types to native Swift types and pass them to
  // the functions inside the passed handle.
  private static func onWatchChange(handle: v23_syncbase_Handle, change: v23_syncbase_WatchChange) {
    let change = change.toWatchChange()
    let handle = Unmanaged<Watch.Handle>.fromOpaque(COpaquePointer(handle)).takeUnretainedValue()
    handle.onChange(change)
  }

  private static func onWatchError(handle: v23_syncbase_Handle, err: v23_syncbase_VError) {
    let e: ErrorType = err.toVError() ?? SyncbaseError.InvalidOperation(reason: "A watch error occurred")
    let handle = Unmanaged<Watch.Handle>.fromOpaque(COpaquePointer(handle)).takeRetainedValue()
    handle.onError(e)
  }
}