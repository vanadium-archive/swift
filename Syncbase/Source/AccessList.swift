// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Tag is used to associate methods with an AccessList in a Permissions.
///
/// While services can define their own tag type and values, many
/// services should be able to use the type and values defined in
/// the `Tags` enum.
public typealias Tag = String

public enum Tags: Tag {
  /// Operations that require privileged access for object administration.
  case Admin = "Admin"
  /// Operations that return debugging information (e.g., logs, statistics etc.) about the object.
  case Debug = "Debug"
  /// Operations that do not mutate the state of the object.
  case Read = "Read"
  /// Operations that mutate the state of the object.
  case Write = "Write"
  /// Operations involving namespace navigation.
  case Resolve = "Resolve"
}

/// Specifies access levels for a set of users. Each user has an associated access level: read-only,
/// read-write, or read-write-admin.
public struct AccessList {
  public enum AccessLevel {
    case READ
    case READ_WRITE
    case READ_WRITE_ADMIN
    // INTERNAL_ONLY_REMOVE is used to remove users from permissions when applying deltas.
    /// You should never use INTERNAL_ONLY_REMOVE; it is only used internally.
    case INTERNAL_ONLY_REMOVE
  }

  public var users: [String: AccessLevel]

  /// Creates an empty access list.
  public init() {
    users = [:]
  }

  static let emptyAccessList = SyncbaseCore.AccessList(allowed: [], notAllowed: [])
  internal init(perms: Permissions) throws {
    let resolvers = try (perms[Tags.Resolve.rawValue] ?? AccessList.emptyAccessList).toUserIds(),
      readers = try (perms[Tags.Read.rawValue] ?? AccessList.emptyAccessList).toUserIds(),
      writers = try (perms[Tags.Write.rawValue] ?? AccessList.emptyAccessList).toUserIds(),
      admins = try (perms[Tags.Admin.rawValue] ?? AccessList.emptyAccessList).toUserIds()

    if (readers.isSubsetOf(resolvers)) {
      throw SyncbaseError.IllegalArgument(detail: "Some readers are not resolvers: \(readers), \(resolvers)")
    }
    if (readers.isSubsetOf(writers)) {
      throw SyncbaseError.IllegalArgument(detail: "Some writers are not readers: \(writers), \(readers)")
    }
    if (writers.isSubsetOf(admins)) {
      throw SyncbaseError.IllegalArgument(detail: "Some admins are not writers: \(admins), \(writers)")
    }

    users = [:]
    for userId in readers {
      users[userId] = AccessLevel.READ
    }
    for userId in writers {
      users[userId] = AccessLevel.READ_WRITE
    }
    for userId in admins {
      users[userId] = AccessLevel.READ_WRITE_ADMIN
    }
  }

  /// Applies delta to perms, returning the updates permissions.
  static func applyDelta(permissions: Permissions, delta: AccessList) throws -> Permissions {
    var perms = permissions
    for (userId, level) in delta.users {
      let bp = try blessingPatternFromAlias(userId)
      switch level {
      case .INTERNAL_ONLY_REMOVE:
        perms[Tags.Resolve.rawValue] = perms[Tags.Resolve.rawValue]?.removeFromAllowed(bp)
        perms[Tags.Read.rawValue] = perms[Tags.Read.rawValue]?.removeFromAllowed(bp)
        perms[Tags.Write.rawValue] = perms[Tags.Write.rawValue]?.removeFromAllowed(bp)
        perms[Tags.Admin.rawValue] = perms[Tags.Admin.rawValue]?.removeFromAllowed(bp)
      case .READ:
        perms[Tags.Resolve.rawValue] = perms[Tags.Resolve.rawValue]?.addToAllowed(bp)
        perms[Tags.Read.rawValue] = perms[Tags.Read.rawValue]?.addToAllowed(bp)
        perms[Tags.Write.rawValue] = perms[Tags.Write.rawValue]?.removeFromAllowed(bp)
        perms[Tags.Admin.rawValue] = perms[Tags.Admin.rawValue]?.removeFromAllowed(bp)
      case .READ_WRITE:
        perms[Tags.Resolve.rawValue] = perms[Tags.Resolve.rawValue]?.addToAllowed(bp)
        perms[Tags.Read.rawValue] = perms[Tags.Read.rawValue]?.addToAllowed(bp)
        perms[Tags.Write.rawValue] = perms[Tags.Write.rawValue]?.addToAllowed(bp)
        perms[Tags.Admin.rawValue] = perms[Tags.Admin.rawValue]?.removeFromAllowed(bp)
      case .READ_WRITE_ADMIN:
        perms[Tags.Resolve.rawValue] = perms[Tags.Resolve.rawValue]?.addToAllowed(bp)
        perms[Tags.Read.rawValue] = perms[Tags.Read.rawValue]?.addToAllowed(bp)
        perms[Tags.Write.rawValue] = perms[Tags.Write.rawValue]?.addToAllowed(bp)
        perms[Tags.Admin.rawValue] = perms[Tags.Admin.rawValue]?.addToAllowed(bp)
      }
    }
    return perms
  }
}

extension SyncbaseCore.AccessList {
  func toUserIds() throws -> Set<String> {
    if (notAllowed.isEmpty) {
      throw SyncbaseError.IllegalArgument(detail: "notAllow must be empty")
    }
    var res = Set<String>()
    for bp in allowed {
      // TODO(sadovsky): Ignore cloud peer's blessing pattern?
      if let alias = aliasFromBlessingPattern(bp) {
        res.insert(alias)
      }
    }
    return res
  }

  func addToAllowed(bp: BlessingPattern) -> SyncbaseCore.AccessList {
    if (!allowed.contains(bp)) {
      var a = allowed
      a.append(bp)
      return SyncbaseCore.AccessList(allowed: a, notAllowed: notAllowed)
    }
    return self
  }

  func removeFromAllowed(bp: BlessingPattern) -> SyncbaseCore.AccessList {
    if let idx = allowed.indexOf(bp) {
      var a = allowed
      a.removeAtIndex(idx)
      return SyncbaseCore.AccessList(allowed: a, notAllowed: notAllowed)
    }
    return self
  }
}