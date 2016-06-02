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
  let collectionName: String

  /// The blessing for collections.
  let collectionBlessing: String

  /// rowKey is a SQL LIKE-style glob pattern ('%' and '_' wildcards, '\' as escape character)
  /// for matching rows. If empty then only the collectionId pattern is matched.
  let rowKey: String?
}

public struct ResumeMarker {
  let data: NSData
}

public struct WatchChange {
  public enum ChangeType: Int {
    case Put
    case Delete
  }

  /// Collection is the id of the collection that contains the changed row.
  let collectionId: Identifier

  /// Row is the key of the changed row.
  let row: String

  /// ChangeType describes the type of the change. If ChangeType is PutChange,
  /// then the row exists in the collection, and Value can be called to obtain
  /// the new value for this row. If ChangeType is DeleteChange, then the row was
  /// removed from the collection.
  let changeType: ChangeType

  /// value is the new value for the row if the ChangeType is PutChange, or nil
  /// otherwise.
  let value: NSData?

  /// ResumeMarker provides a compact representation of all the messages that
  /// have been received by the caller for the given Watch call.
  /// This marker can be provided in the Request message to allow the caller
  /// to resume the stream watching at a specific point without fetching the
  /// initial state.
  let resumeMarker: ResumeMarker

  /// FromSync indicates whether the change came from sync. If FromSync is false,
  /// then the change originated from the local device.
  let isFromSync: Bool

  /// If true, this WatchChange is followed by more WatchChanges that are in the
  /// same batch as this WatchChange.
  let isContinued: Bool
}

public typealias WatchStream = AnonymousStream<WatchChange>

/// Internal namespace for the watch API -- end-users will access this through Database.watch
/// instead. This is simply here to allow all watch-related code to be located in Watch.swift.
enum Watch {
  static func watch(
    encodedDatabaseName encodedDatabaseName: String,
    patterns: [CollectionRowPattern],
    resumeMarker: ResumeMarker? = nil) throws -> WatchStream {
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
      let fetchNext = { (timeout: NSTimeInterval?) -> (WatchChange?, ErrorType?) in
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
      let onChange = { (change: WatchChange) in
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
      let onError = { (err: ErrorType) in
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

      try VError.maybeThrow { errPtr in
        let cPatterns = try v23_syncbase_CollectionRowPatterns(patterns)
        let cResumeMarker = v23_syncbase_Bytes(resumeMarker?.data)
        let callbacks = v23_syncbase_DbWatchPatternsCallbacks(
          hOnChange: onWatchChangeClosures.ref(onChange),
          hOnError: onWatchErrorClosures.ref(onError),
          onChange: { Watch.onWatchChange(AsyncId($0), change: $1) },
          onError: { Watch.onWatchError(AsyncId($0), errorHandle: AsyncId($1), err: $2) })
        v23_syncbase_DbWatchPatterns(
          try encodedDatabaseName.toCgoString(),
          cResumeMarker,
          cPatterns,
          callbacks,
          errPtr)
      }

      return AnonymousStream(
        fetchNextFunction: fetchNext,
        cancelFunction: { preconditionFailure("stub") })
  }

  // Reference maps between closured functions and handles passed back/forth with Go.
  private static var onWatchChangeClosures = RefMap < WatchChange -> Void > ()
  private static var onWatchErrorClosures = RefMap < ErrorType -> Void > ()

  // Callback handlers that convert the Cgo bridge types to native Swift types and pass them to
  // the closured functions reference by the passed handle.
  private static func onWatchChange(changeHandle: AsyncId, change: v23_syncbase_WatchChange) {
    let change = change.toWatchChange()
    guard let callback = onWatchChangeClosures.get(changeHandle) else {
      fatalError("Could not find closure for watch onChange handle")
    }
    callback(change)
  }

  private static func onWatchError(changeHandle: AsyncId, errorHandle: AsyncId, err: v23_syncbase_VError) {
    let e: ErrorType = err.toVError() ?? SyncbaseError.InvalidOperation(reason: "A watch error occurred")
    if onWatchChangeClosures.unref(changeHandle) == nil {
      fatalError("Could not find closure for watch onChange handle (via onWatchError callback)")
    }
    guard let callback = onWatchErrorClosures.unref(errorHandle) else {
      fatalError("Could not find closure for watch onError handle")
    }
    callback(e)
  }
}