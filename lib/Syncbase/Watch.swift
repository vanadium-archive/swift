// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public struct ResumeMarker {
  internal let data: [UInt8]
}

public struct WatchChange {
  public enum ChangeType: Int {
    case PutChange = 0, DeleteDelete
  }

  /// Collection is the id of the collection that contains the changed row.
  let collectionId: CollectionId

  /// Row is the key of the changed row.
  let row: String

  /// ChangeType describes the type of the change. If ChangeType is PutChange,
  /// then the row exists in the collection, and Value can be called to obtain
  /// the new value for this row. If ChangeType is DeleteChange, then the row was
  /// removed from the collection.
  let changeType: ChangeType

  /// value is the new value for the row if the ChangeType is PutChange, or nil
  /// otherwise.
  let value: VomRawBytes

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
