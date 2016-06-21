// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// ResumeMarker provides a compact representation of all the messages that
/// have been received by the caller for the given Watch call. It is not
/// something that you would ever generate; it is always provided to you
/// in a WatchChange.
public typealias ResumeMarker = NSData

/// Describes a change to a database.
public class WatchChange {
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

  init(coreChange: SyncbaseCore.WatchChange) {
    self.collectionId = Identifier(coreId: coreChange.collectionId)
    self.row = coreChange.row
    self.changeType = ChangeType(rawValue: coreChange.changeType.rawValue)!
    self.value = coreChange.value
    self.resumeMarker = coreChange.resumeMarker
    self.isFromSync = coreChange.isFromSync
    self.isContinued = coreChange.isContinued
  }
}