// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// BlobRef is a reference to a blob.
public typealias BlobRef = String

public enum BlobDevType: Int {
  /// Blobs migrate toward servers, which store them.  (example: server in cloud)
  case BlobDevTypeServer = 0
  /// Ordinary devices (example: laptop)
  case BlobDevTypeNormal = 1
  /// Blobs migrate from leaves, which have less storage (examples: a camera, phone)
  case BlobDevTypeLeaf = 2
}

let kNullBlobRef = BlobRef("")

/// Blob is the interface for a Blob in the store.
public protocol Blob {
  /// Ref returns Syncbase's BlobRef for this blob.
  func ref() -> BlobRef

  /// Put appends the byte stream to the blob.
  func put() throws -> BlobWriter

  /// Commit marks the blob as immutable.
  func commit() throws

  /// Size returns the count of bytes written as part of the blob
  /// (committed or uncommitted).
  func size() throws -> Int64

  /// Delete locally deletes the blob (committed or uncommitted).
  func delete() throws

  /// Get returns the byte stream from a committed blob starting at offset.
  func get(offset: Int64) throws -> BlobReader

  /// Fetch initiates fetching a blob if not locally found. priority
  /// controls the network priority of the blob. Higher priority blobs are
  /// fetched before the lower priority ones. However an ongoing blob
  /// transfer is not interrupted. Status updates are streamed back to the
  /// client as fetch is in progress.
  func fetch(priority: UInt64) throws -> BlobStatus

  /// Pin locally pins the blob so that it is not evicted.
  func pin() throws

  /// Unpin locally unpins the blob so that it can be evicted if needed.
  func unpin() throws

  /// Keep locally caches the blob with the specified rank. Lower
  /// ranked blobs are more eagerly evicted.
  func keep(rank: UInt64) throws
}

/// BlobWriter is an interface for putting a blob.
public protocol BlobWriter {
  /// Send places the bytes given by the client onto the output
  /// stream. Returns throwss encountered while sending. Blocks if there is
  /// no buffer space.
  func Send(data: NSData) throws

  /// Close indicates that no more bytes will be sent.
  func Close() throws
}

/// BlobReader is an interface for getting a blob.
public protocol BlobReader {
  /// Advance() stages bytes so that they may be retrieved via
  /// Value(). Returns true iff there are bytes to retrieve. Advance() must
  /// be called before Value() is called. The caller is expected to read
  /// until Advance() returns false, or to call Cancel().
  func advance() -> Bool

  /// Value() returns the bytes that were staged by Advance(). May panic if
  /// Advance() returned false or was not called. Never blocks.
  func value() -> NSData

  /// Err() returns any throws encountered by Advance. Never blocks.
  func err() throws

  /// Cancel notifies the stream provider that it can stop producing
  /// elements.  The client must call Cancel if it does not iterate through
  /// all elements (i.e. until Advance returns false). Cancel is idempotent
  /// and can be called concurrently with a goroutine that is iterating via
  /// Advance.  Cancel causes Advance to subsequently return false. Cancel
  /// does not block.
  func cancel()
}

/// BlobStatus is an interface for getting the status of a blob transfer.
public protocol BlobStatus {
  /// Advance() stages an item so that it may be retrieved via
  /// Value(). Returns true iff there are items to retrieve. Advance() must
  /// be called before Value() is called. The caller is expected to read
  /// until Advance() returns false, or to call Cancel().
  func advance() -> Bool

  /// Value() returns the item that was staged by Advance(). May panic if
  /// Advance() returned false or was not called. Never blocks.
  func value() -> BlobFetchStatus

  /// Err() returns any throws encountered by Advance. Never blocks.
  func err() -> SyncbaseError?

  /// Cancel notifies the stream provider that it can stop producing
  /// elements.  The client must call Cancel if it does not iterate through
  /// all elements (i.e. until Advance returns false). Cancel is idempotent
  /// and can be called concurrently with a goroutine that is iterating via
  /// Advance.  Cancel causes Advance to subsequently return false. Cancel
  /// does not block.
  func cancel()
}

//// BlobFetchStatus describes the progress of an asynchronous blob fetch.
public struct BlobFetchStatus {
  //// State of the blob fetch request.
  public let state: BlobFetchState
  //// Total number of bytes received.
  public let received: Int64
  //// Blob size.
  public let total: Int64
}

public enum BlobFetchState: Int {
  case BlobFetchStatePending = 0
  case BlobFetchStateLocating
  case BlobFetchStateFetching
  case BlobFetchStateDone
}

