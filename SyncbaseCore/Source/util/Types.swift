// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: Imported C structs have a default initializer in Swift that zero-initializes all fields.
// https://developer.apple.com/library/ios/releasenotes/DeveloperTools/RN-Xcode/Chapters/xc6_release_notes.html

import Foundation

func mallocOrDie<T>(length: Int) -> UnsafeMutablePointer<T> {
  let p = malloc(length)
  if p == nil {
    fatalError("Couldn't allocate \(length) bytes")
  }
  return unsafeBitCast(p, UnsafeMutablePointer<T>.self)
}

public extension v23_syncbase_AppPeer {
  func extract() -> NeighborhoodPeer {
    return NeighborhoodPeer(
      appName: appName.extract() ?? "",
      blessings: blessings.extract() ?? "",
      isLost: isLost)
  }
}

public extension v23_syncbase_BatchOptions {
  init (_ opts: BatchOptions?) throws {
    guard let o = opts else {
      hint = v23_syncbase_String()
      readOnly = false
      return
    }
    hint = try o.hint?.toCgoString() ?? v23_syncbase_String()
    readOnly = o.readOnly
  }
}

public extension v23_syncbase_Bytes {
  init(_ data: NSData?) {
    guard let data = data else {
      n = 0
      p = nil
      return
    }
    p = mallocOrDie(data.length)
    data.getBytes(p, length: data.length)
    n = Int32(data.length)
  }

  // Return value takes ownership of the memory associated with this object.
  func extract() -> NSData? {
    if p == nil {
      return nil
    }
    return NSData(bytesNoCopy: UnsafeMutablePointer<Void>(p), length: Int(n), freeWhenDone: true)
  }
}

public extension v23_syncbase_ChangeType {
  func extract() -> WatchChange.ChangeType? {
    return WatchChange.ChangeType(rawValue: Int(rawValue))
  }
}

public extension v23_syncbase_CollectionRowPattern {
  init(_ pattern: CollectionRowPattern) throws {
    collectionBlessing = try pattern.collectionBlessing.toCgoString()
    collectionName = try pattern.collectionName.toCgoString()
    rowKey = try (pattern.rowKey ?? "").toCgoString()
  }
}

public extension v23_syncbase_CollectionRowPatterns {
  init(_ patterns: [CollectionRowPattern]) throws {
    if (patterns.isEmpty) {
      n = 0
      p = nil
      return
    }
    p = mallocOrDie(patterns.count * sizeof(v23_syncbase_CollectionRowPattern))
    n = Int32(patterns.count)
    var i = 0
    do {
      for pattern in patterns {
        p.advancedBy(i).memory = try v23_syncbase_CollectionRowPattern(pattern)
        i += 1
      }
    } catch {
      free(p)
      p = nil
      n = 0
      throw error
    }
  }
}

public extension v23_syncbase_EntityType {
  func extract() -> WatchChange.EntityType? {
    return WatchChange.EntityType(rawValue: Int(rawValue))
  }
}

public extension v23_syncbase_Id {
  init(_ id: Identifier) throws {
    name = try id.name.toCgoString()
    blessing = try id.blessing.toCgoString()
  }

  func extract() -> Identifier? {
    guard let name = name.extract(),
      blessing = blessing.extract() else {
        return nil
    }
    return Identifier(name: name, blessing: blessing)
  }
}

public extension v23_syncbase_Ids {
  init(_ ids: [Identifier]) throws {
    p = mallocOrDie(ids.count * sizeof(v23_syncbase_Id))
    n = Int32(ids.count)
    for i in 0 ..< ids.count {
      do {
        p.advancedBy(i).memory = try v23_syncbase_Id(ids[i])
      } catch (let e) {
        for j in 0 ..< i {
          free(p.advancedBy(j).memory.blessing.p)
          free(p.advancedBy(j).memory.name.p)
        }
        free(p)
        throw e
      }
    }
  }

  func extract() -> [Identifier] {
    var ids: [Identifier] = []
    for i in 0 ..< n {
      let idStruct = p.advancedBy(Int(i)).memory
      if let id = idStruct.extract() {
        ids.append(id)
      }
    }
    if p != nil {
      free(p)
    }
    return ids
  }
}

public extension v23_syncbase_Invite {
  func extract() -> SyncgroupInvite? {
    guard let id = syncgroup.extract() else {
      return nil
    }
    return SyncgroupInvite(
      syncgroupId: id,
      addresses: addresses.extract(),
      blessingNames: blessingNames.extract())
  }
}

public extension v23_syncbase_Permissions {
  init(_ permissions: Permissions?) throws {
    guard let p = permissions where !p.isEmpty else {
      // Zero-value constructor.
      json = v23_syncbase_Bytes()
      return
    }
    var m = [String: AnyObject]()
    for (key, value) in p {
      m[key as String] = (value as AccessList).toJsonable()
    }
    let serialized = try NSJSONSerialization.serialize(m)
    let bytes = v23_syncbase_Bytes(serialized)
    json = bytes
  }

  func extract() throws -> Permissions? {
    guard let data = json.extract(),
      map = try NSJSONSerialization.deserialize(data) as? NSDictionary else {
        return nil
    }
    var p = Permissions()
    for (k, v) in map {
      guard let key = k as? String,
        jsonAcessList = v as? [String: AnyObject] else {
          throw SyncbaseError.CastError(obj: v)
      }
      p[key] = AccessList.fromJsonable(jsonAcessList)
    }
    return p
  }
}

public extension v23_syncbase_String {
  init(_ string: String) throws {
    // TODO: If possible, make one copy instead of two, e.g. using s.getCString.
    guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: string)
    }
    p = mallocOrDie(data.length)
    data.getBytes(p, length: data.length)
    n = Int32(data.length)
  }

  // Return value takes ownership of the memory associated with this object.
  func extract() -> String? {
    if p == nil {
      return nil
    }
    return String(bytesNoCopy: UnsafeMutablePointer<Void>(p),
      length: Int(n),
      encoding: NSUTF8StringEncoding,
      freeWhenDone: true)
  }
}

public extension v23_syncbase_Strings {
  init(_ strings: [String]) throws {
    p = mallocOrDie(strings.count * sizeof(v23_syncbase_String))
    n = Int32(strings.count)
    for i in 0 ..< strings.count {
      do {
        p.advancedBy(i).memory = try v23_syncbase_String(strings[i])
      } catch (let e) {
        for j in 0 ..< i {
          free(p.advancedBy(j).memory.p)
        }
        free(p)
        throw e
      }
    }
  }

  init(_ strings: [v23_syncbase_String]) {
    p = mallocOrDie(strings.count * sizeof(v23_syncbase_String))
    n = Int32(strings.count)
    var i = 0
    for string in strings {
      p.advancedBy(i).memory = string
      i += 1
    }
  }

  // Return value takes ownership of the memory associated with this object.
  func extract() -> [String] {
    if p == nil {
      return []
    }
    var ret = [String]()
    for i in 0 ..< n {
      ret.append(p.advancedBy(Int(i)).memory.extract() ?? "")
    }
    free(p)
    return ret
  }
}

public extension String {
  /// Create a Cgo-passable string struct forceably (will crash if the string cannot be created).
  func toCgoString() throws -> v23_syncbase_String {
    return try v23_syncbase_String(self)
  }
}

public extension v23_syncbase_SyncgroupMemberInfo {
  init(_ info: SyncgroupMemberInfo) {
    syncPriority = info.syncPriority
    blobDevType = UInt8(info.blobDevType.rawValue)
  }

  func extract() -> SyncgroupMemberInfo {
    return SyncgroupMemberInfo(
      syncPriority: syncPriority,
      blobDevType: BlobDevType(rawValue: Int(blobDevType))!)
  }
}

public extension v23_syncbase_SyncgroupMemberInfoMap {
  func extract() -> [String: SyncgroupMemberInfo] {
    var ret = [String: SyncgroupMemberInfo]()
    for i in 0 ..< Int(n) {
      let key = keys.advancedBy(i).memory.extract() ?? ""
      let value = values.advancedBy(i).memory.extract()
      ret[key] = value
    }
    free(keys)
    free(values)
    return ret
  }
}

public extension v23_syncbase_SyncgroupSpec {
  init(_ spec: SyncgroupSpec) throws {
    collections = try v23_syncbase_Ids(spec.collections)
    description = try spec.description.toCgoString()
    isPrivate = spec.isPrivate
    mountTables = try v23_syncbase_Strings(spec.mountTables)
    perms = try v23_syncbase_Permissions(spec.permissions)
    publishSyncbaseName = try spec.publishSyncbaseName?.toCgoString() ?? v23_syncbase_String()
  }

  func extract() throws -> SyncgroupSpec {
    return SyncgroupSpec(
      description: description.extract() ?? "",
      collections: collections.extract(),
      permissions: try perms.extract() ?? [:],
      publishSyncbaseName: publishSyncbaseName.extract(),
      mountTables: mountTables.extract(),
      isPrivate: isPrivate)
  }
}

public extension v23_syncbase_WatchChange {
  func extract() -> WatchChange {
    let resumeMarkerData = v23_syncbase_Bytes(
      p: unsafeBitCast(resumeMarker.p, UnsafeMutablePointer<UInt8>.self),
      n: resumeMarker.n).extract()
    // Turn row & collectionId zero-values into nil.
    var row = self.row.extract()
    if row == "" {
      row = nil
    }
    var collectionId = collection.extract()
    if collectionId?.name == "" && collectionId?.blessing == "" {
      collectionId = nil
    }
    // Zero-valued Value does not get turned into a nil on put -- if it's a put then we know
    // it cannot be nil. This allows us to store empty arrays (an esoteric use case but one that
    // is supported nevertheless).
    var value = self.value.extract()
    if value == nil && changeType == v23_syncbase_ChangeTypePut {
      value = NSData()
    }
    return WatchChange(
      entityType: entityType.extract()!,
      collectionId: collectionId,
      row: row,
      changeType: changeType.extract()!,
      value: value,
      resumeMarker: resumeMarkerData,
      isFromSync: fromSync,
      isContinued: continued)
  }
}

// Note, we don't define init(VError) since we never pass Swift VError objects to Go.
public extension v23_syncbase_VError {
  // Return value takes ownership of the memory associated with this object.
  func extract() -> VError? {
    if id.p == nil {
      return nil
    }
    // Take ownership of all memory before checking optionals.
    let vId = id.extract(), vMsg = msg.extract(), vStack = stack.extract()
    // TODO: Stop requiring id, msg, and stack to be valid UTF-8?
    return VError(id: vId!, actionCode: actionCode, msg: vMsg ?? "", stack: vStack!)
  }
}

public struct VError: ErrorType {
  public let id: String
  public let actionCode: UInt32
  public let msg: String
  public let stack: String

  static func maybeThrow<T>(@noescape f: UnsafeMutablePointer<v23_syncbase_VError> throws -> T) throws -> T {
    var e = v23_syncbase_VError()
    let res = try f(&e)
    if let err = e.extract() {
      throw SyncbaseError(err)
    }
    return res
  }
}

