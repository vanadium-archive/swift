// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// CollectionRowPattern contains SQL LIKE-style glob patterns ('%' and '_'
/// wildcards, '\' as escape character) for matching rows and collections by
/// name components. It is used by the Database.watch API.
public struct CollectionRowPattern {
  /// WildCard matches everything.
  public static var Everything = CollectionRowPattern(
    collectionName: Wildcard, collectionBlessing: Wildcard, rowKey: Wildcard)

  public static var Wildcard = "%"

  /// collectionName is a SQL LIKE-style glob pattern ('%' and '_' wildcards, '\' as escape
  /// character) for matching collections. May not be empty.
  public let collectionName: String

  /// The blessing for collections.
  public let collectionBlessing: String

  /// rowKey is a SQL LIKE-style glob pattern ('%' and '_' wildcards, '\' as escape character)
  /// for matching rows. If empty then only the collectionId pattern is matched and NO row events
  /// are returned.
  public let rowKey: String?

  public init(collectionName: String = Wildcard, collectionBlessing: String = Wildcard, rowKey: String? = Wildcard) {
    self.collectionName = collectionName
    self.collectionBlessing = collectionBlessing
    self.rowKey = rowKey
  }

  public init(collectionId: Identifier, rowKey: String? = Wildcard) {
    self.collectionName = collectionId.name
    self.collectionBlessing = collectionId.blessing
    self.rowKey = rowKey
  }

  func toCore() -> SyncbaseCore.CollectionRowPattern {
    return SyncbaseCore.CollectionRowPattern(
      collectionName: collectionName,
      collectionBlessing: collectionBlessing,
      rowKey: rowKey)
  }
}

/// ResumeMarker provides a compact representation of all the messages that
/// have been received by the caller for the given Watch call. It is not
/// something that you would ever generate; it is always provided to you
/// in a WatchChange.
public typealias ResumeMarker = NSData

/// Describes a change to a database.
public class WatchChange: CustomStringConvertible {
  public enum EntityType: Int {
    case Root
    case Collection
    case Row
  }

  public enum ChangeType: Int {
    case Put
    case Delete
  }

  /// EntityType is the type of the entity - Root, Collection, or Row.
  public let entityType: EntityType

  /// Collection is the id of the collection that was changed or contains the
  /// changed row. Is nil if EntityType is not Collection or Row.
  public let collectionId: Identifier?

  /// Row is the key of the changed row. Nil if EntityType is not Row.
  public let row: String?

  /// ChangeType describes the type of the change, depending on the EntityType:
  ///
  /// **EntityRow:**
  ///
  /// - PutChange: the row exists in the collection, and Value can be called to
  /// obtain the new value for this row.
  ///
  /// - DeleteChange: the row was removed from the collection.
  ///
  /// **EntityCollection:**
  ///
  /// - PutChange: the collection exists, and CollectionInfo can be called to
  /// obtain the collection info.
  ///
  /// - DeleteChange: the collection was destroyed.
  ///
  /// **EntityRoot:**
  ///
  /// - PutChange: appears as the first (possibly only) change in the initial
  /// state batch, only if watching from an empty ResumeMarker. This is the
  /// only situation where an EntityRoot appears.
  public let changeType: ChangeType

  /// value is the new value for the row for EntityRow PutChanges, an encoded
  /// StoreChangeCollectionInfo value for EntityCollection PutChanges, or nil
  /// otherwise.
  public let value: NSData?

  /// ResumeMarker provides a compact representation of all the messages that
  /// have been received by the caller for the given Watch call.
  /// This marker can be provided in the Request message to allow the caller
  /// to resume the stream watching at a specific point without fetching the
  /// initial state.
  public let resumeMarker: ResumeMarker?

  /// FromSync indicates whether the change came from sync. If FromSync is false,
  /// then the change originated from the local device.
  public let isFromSync: Bool

  /// If true, this WatchChange is followed by more WatchChanges that are in the
  /// same batch as this WatchChange.
  public let isContinued: Bool

  init(coreChange: SyncbaseCore.WatchChange) {
    self.entityType = EntityType(rawValue: coreChange.entityType.rawValue)!
    if let coreCollectionId = coreChange.collectionId {
      self.collectionId = Identifier(coreId: coreCollectionId)
    } else {
      self.collectionId = nil
    }
    self.row = coreChange.row
    self.changeType = ChangeType(rawValue: coreChange.changeType.rawValue)!
    self.value = coreChange.value
    self.resumeMarker = coreChange.resumeMarker
    self.isFromSync = coreChange.isFromSync
    self.isContinued = coreChange.isContinued
  }

  public var description: String {
    var valueDesc = "<nil>"
    if let v = value {
      if v.length > 1024 {
        valueDesc = "<\(v.length) bytes>"
      } else if let str = String(data: v, encoding: NSUTF8StringEncoding) {
        valueDesc = str
      } else {
        valueDesc = v.description
      }
    }
    return "[Syncbase.WatchChange entityType=\(entityType) changeType=\(changeType) " +
      "collectionId=\(collectionId) row=\(row) isFromSync=\(isFromSync) isContinued=\(isContinued) " +
      "value=\(valueDesc) ]"
  }
}