/// Copyright 2016 The Vanadium Authors. All rights reserved.
/// Use of this source code is governed by a BSD-style
/// license that can be found in the LICENSE file.

import Foundation

/// Collection represents a set of Rows.
///
/// TODO(sadovsky): Currently we provide Get/Put/Delete methods on both
/// Collection and Row, because we're not sure which will feel more natural.
/// Eventually, we'll need to pick one.
public class Collection {
  /// Id returns the id of this Collection.
  public let collectionId: Identifier
  let batchHandle: String?
  let encodedCollectionName: String

  init(databaseId: Identifier, collectionId: Identifier, batchHandle: String?) throws {
    self.collectionId = collectionId
    self.batchHandle = batchHandle
    self.encodedCollectionName = try Collection.encodedName(databaseId, collectionId: collectionId)
  }

  /// Exists returns true only if this Collection exists. Insufficient
  /// permissions cause Exists to return false instead of an throws.
  /// TODO(ivanpi): Exists may fail with an throws if higher levels of hierarchy
  /// do not exist.
  public func exists() throws -> Bool {
    return try VError.maybeThrow { errPtr in
      var exists = v23_syncbase_Bool(false)
      v23_syncbase_CollectionExists(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        &exists,
        errPtr)
      return exists.toBool()
    }
  }

  /// Create creates this Collection.
  /// TODO(sadovsky): Specify what happens if perms is nil.
  public func create(permissions: Permissions?) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_CollectionCreate(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        try v23_syncbase_Permissions(permissions),
        errPtr)
    }
  }

  /// Destroy destroys this Collection, permanently removing all of its data.
  /// TODO(sadovsky): Specify what happens to syncgroups.
  public func destroy() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_CollectionDestroy(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        errPtr)
    }
  }

  /// GetPermissions returns the current Permissions for the Collection.
  /// The Read bit on the ACL does not affect who this Collection's rows are
  /// synced to; all members of syncgroups that include this Collection will
  /// receive the rows in this Collection. It only determines which clients
  /// are allowed to retrieve the value using a Syncbase RPC.
  public func getPermissions() throws -> Permissions {
    var permissions = v23_syncbase_Permissions()
    try VError.maybeThrow { errPtr in
      v23_syncbase_CollectionGetPermissions(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        &permissions,
        errPtr)
    }
    // TODO(zinman): Verify that permissions defaulting to zero-value is correct.
    return try permissions.toPermissions() ?? Permissions()
  }

  /// SetPermissions replaces the current Permissions for the Collection.
  public func setPermissions(permissions: Permissions) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_CollectionSetPermissions(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        try v23_syncbase_Permissions(permissions),
        errPtr)
    }
  }

  /**
   Get loads the value stored under the given key into inout parameter value.

   Sets value to nil if nothing is stored undeder the given key.

   By passing the typed target output value using inout, get is able to cast the value to the
   desired type automatically. If the types do not match, an exception is thrown.

   For example:

   ```
   /// Using inout
   var isRed: Bool?
   try collection.get("isRed", &isRed)

   /// Using return value
   let isRed: Bool = try collection.get("isRed")
   ```
   */
  public func get<T: SyncbaseConvertible>(key: String, inout value: T?) throws {
    // TODO(zinman): We should probably kill this variant unless it provides .dynamicType benefits
    // with VOM support and custom class serialization/deserialization.
    value = try get(key)
  }

  /// Get loads the value stored under the given key.
  public func get<T: SyncbaseConvertible>(key: String) throws -> T? {
    guard let data = try getRawBytes(key) else {
      return nil
    }
    let value: T = try T.deserializeFromSyncbase(data)
    return value
  }

  func getRawBytes(key: String) throws -> NSData? {
    var cBytes = v23_syncbase_Bytes()
    do {
      try VError.maybeThrow { errPtr in
        v23_syncbase_RowGet(
          try encodedRowName(key),
          try cBatchHandle(),
          &cBytes,
          errPtr)
      }
    } catch let e as VError {
      if e.id == "v.io/v23/verror.NoExist" {
        return nil
      }
      throw e
    }
    // If we got here then we know that row exists, otherwise we would have gotten the NoExist
    // exception above. However, that row might also just be empty data. Because
    // cBytes.toNSData can't distinguish between the struct's zero-values and a nil array,
    // we must explicitly default to an empty NSData here since we know that it is not nil.
    return cBytes.toNSData() ?? NSData()
  }

  /// Put writes the given value to this Collection under the given key.
  public func put(key: String, value: SyncbaseConvertible) throws {
    let data = try value.serializeToSyncbase()
    try VError.maybeThrow { errPtr in
      v23_syncbase_RowPut(
        try encodedRowName(key),
        try cBatchHandle(),
        v23_syncbase_Bytes(data),
        errPtr)
    }
  }

  /// Delete deletes the row for the given key.
  public func delete(key: String) throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_RowDelete(
        try encodedRowName(key),
        try cBatchHandle(),
        errPtr)
    }
  }

  /// DeleteRange deletes all rows in the given half-open range [start, limit).
  /// If limit is "", all rows with keys >= start are included.
  /// TODO(sadovsky): Document how this deletion is considered during conflict
  /// detection: is it considered as a range deletion, or as a bunch of point
  /// deletions?
  /// See helpers Prefix(), Range(), SingleRow().
  public func deleteRange(r: RowRange) throws {
    try VError.maybeThrow { errPtr in
      let cStartStr = try r.start.toCgoString()
      let cLimitStr = try r.limit.toCgoString()
      let cStartBytes = v23_syncbase_Bytes(
        p: unsafeBitCast(cStartStr.p, UnsafeMutablePointer<UInt8>.self), n: cStartStr.n)
      let cLimitBytes = v23_syncbase_Bytes(
        p: unsafeBitCast(cLimitStr.p, UnsafeMutablePointer<UInt8>.self), n: cLimitStr.n)
      v23_syncbase_CollectionDeleteRange(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        cStartBytes,
        cLimitBytes,
        errPtr)
    }
  }

  private class ScanHandle {
    // Scan works by having Go call Swift as encounters each row. This is a bit of a mismatch
    // for the Swift GeneratorType which is pull instead of push-based. We create a push-pull
    // adapter by blocking on either side using condition variables until both are ready for the
    // next data handoff. Adding to the complexity is that Go has separate callbacks for when it has
    // data or is done, yet the GeneratorType uses a single fetch function that handles both
    // conditions (the data is nil when it's done). Thus we end up with 2 different callbacks from
    // Go with similar condition-variable logic.
    let condition = NSCondition()
    var data: (String, NSData)? = nil
    var doneErr: ErrorType? = nil
    var updateAvailable = false

    // The anonymous function that gets called from the Swift. It blocks until there's an update
    // available from Go.
    func fetchNext(timeout: NSTimeInterval?) -> ((String, GetValueFromScanStream)?, ErrorType?) {
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
      updateAvailable = false
      // Signal that we've fetched the data to Go.
      condition.signal()
      condition.unlock()
      // Default the ret to nil (valid for isDone).
      var ret: (String, GetValueFromScanStream)? = nil
      if let d = fetchedData {
        // Create the closured function that deserializes the data from Syncbase on demand.
        ret = (d.0, { () throws -> SyncbaseConvertible in
          // Let T be inferred by being explicit about NSData (the only conversion possible until
          // we have VOM support).
          let data: NSData = try NSData.deserializeFromSyncbase(d.1)
          return data
        })
      }
      return (ret, doneErr)
    }

    // The callback from Go when there's a new Row (key-value) scanned.
    func onKeyValue(key: String, valueBytes: NSData) {
      condition.lock()
      // Wait until any existing update has been received by the fetch so we don't just blow
      // past it.
      while updateAvailable {
        condition.wait()
      }
      // Set the new data.
      data = (key, valueBytes)
      updateAvailable = true
      // Wake up any blocked fetch.
      condition.signal()
      condition.unlock()
    }

    func onDone(err: ErrorType?) {
      condition.lock()
      // Wait until any existing update has been received by the fetch so we don't just blow
      // past it.
      while updateAvailable {
        condition.wait()
      }
      // Marks the end of data by clearing it and saving any associated error from Syncbase.
      data = nil
      doneErr = err
      updateAvailable = true
      // Wake up any blocked fetch.
      condition.signal()
      condition.unlock()
    }
  }

  /// Scan returns all rows in the given half-open range [start, limit). If limit
  /// is "", all rows with keys >= start are included.
  /// Concurrency semantics: It is legal to perform writes concurrently with
  /// Scan. The returned stream reads from a consistent snapshot taken at the
  /// time of the RPC (or at the time of BeginBatch, if in a batch), and will not
  /// reflect subsequent writes to keys not yet reached by the stream.
  /// See helpers Prefix(), Range(), SingleRow().
  public func scan(r: RowRange) throws -> ScanStream {
    let handle = ScanHandle()
    try VError.maybeThrow { errPtr in
      let oHandle = UnsafeMutablePointer<Void>(Unmanaged.passRetained(handle).toOpaque())
      let cStartStr = try r.start.toCgoString()
      let cLimitStr = try r.limit.toCgoString()
      let cStartBytes = v23_syncbase_Bytes(
        p: unsafeBitCast(cStartStr.p, UnsafeMutablePointer<UInt8>.self), n: cStartStr.n)
      let cLimitBytes = v23_syncbase_Bytes(
        p: unsafeBitCast(cLimitStr.p, UnsafeMutablePointer<UInt8>.self), n: cLimitStr.n)
      let callbacks = v23_syncbase_CollectionScanCallbacks(
        handle: v23_syncbase_Handle(oHandle),
        onKeyValue: { Collection.onScanKeyValue($0, kv: $1) },
        onDone: { Collection.onScanDone($0, err: $1) })
      v23_syncbase_CollectionScan(
        try encodedCollectionName.toCgoString(),
        try cBatchHandle(),
        cStartBytes,
        cLimitBytes,
        callbacks,
        errPtr)
    }
    return AnonymousStream(
      fetchNextFunction: handle.fetchNext,
      cancelFunction: { preconditionFailure("stub") })
  }

  // Callback handlers that convert the Cgo bridge types to native Swift types and pass them to
  // the functions inside the passed handle.
  private static func onScanKeyValue(handle: v23_syncbase_Handle, kv: v23_syncbase_KeyValue) {
    let key = kv.key.toString()!
    let valueBytes = kv.value.toNSData()!
    let handle = Unmanaged<ScanHandle>.fromOpaque(COpaquePointer(handle)).takeUnretainedValue()
    handle.onKeyValue(key, valueBytes: valueBytes)
  }

  private static func onScanDone(handle: v23_syncbase_Handle, err: v23_syncbase_VError) {
    let e = err.toVError()
    let handle = Unmanaged<ScanHandle>.fromOpaque(COpaquePointer(handle)).takeRetainedValue()
    handle.onDone(e)
  }

  // MARK: Internal helpers

  private func cBatchHandle() throws -> v23_syncbase_String {
    return try batchHandle?.toCgoString() ?? v23_syncbase_String()
  }

  private static func encodedName(databaseId: Identifier, collectionId: Identifier) throws -> String {
    var cStr = v23_syncbase_String()
    v23_syncbase_NamingJoin(
      v23_syncbase_Strings([try databaseId.encodeId(), try collectionId.encodeId()]),
      &cStr)
    return cStr.toString()!
  }

  private func encodedRowName(key: String) throws -> v23_syncbase_String {
    var encodedRowName = v23_syncbase_String()
    var encodedRowKey = v23_syncbase_String()
    v23_syncbase_Encode(try key.toCgoString(), &encodedRowKey)
    v23_syncbase_NamingJoin(
      v23_syncbase_Strings([try encodedCollectionName.toCgoString(), encodedRowKey]),
      &encodedRowName)
    return encodedRowName
  }
}

/// Returns the decoded value, or throws an error if the value could not be decoded.
public typealias GetValueFromScanStream = () throws -> SyncbaseConvertible

/// Stream resulting from a scan on a scollection for a given row range.
public typealias ScanStream = AnonymousStream<(String, GetValueFromScanStream)>
