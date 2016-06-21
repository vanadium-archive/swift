// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// Permissions maps string tags to access lists specifying the blessings
/// required to invoke methods with that tag.
///
/// These tags are meant to add a layer of interposition between the set of
/// users (blessings, specifically) and the set of methods, much like "Roles" do
/// in Role Based Access Control.
/// (http://en.wikipedia.org/wiki/Role-based_access_control)
public typealias Permissions = [String: AccessList]

/// BlessingPattern is a pattern that is matched by specific blessings.
///
/// A pattern can either be a blessing (slash-separated human-readable string)
/// or a blessing ending in "/$". A pattern ending in "/$" is matched exactly
/// by the blessing specified by the pattern string with the "/$" suffix stripped
/// out. For example, the pattern "a/b/c/$" is matched by exactly by the blessing
/// "a/b/c".
///
/// A pattern not ending in "/$" is more permissive, and is also matched by blessings
/// that are extensions of the pattern (including the pattern itself). For example, the
/// pattern "a/b/c" is matched by the blessings "a/b/c", "a/b/c/x", "a/b/c/x/y", etc.
public typealias BlessingPattern = String

public typealias PermissionsVersion = String

/// AccessList represents a set of blessings that should be granted access.
///
/// See also: https://vanadium.github.io/glossary.html#access-list
public struct AccessList {
  /// allowed denotes the set of blessings (represented as BlessingPatterns) that
  /// should be granted access, unless blacklisted by an entry in notAllowed.
  ///
  /// For example:
  /// allowed: {"alice:family"}
  /// grants access to a principal that presents at least one of
  /// "alice:family", "alice:family:friend", "alice:family:friend:spouse" etc.
  /// as a blessing.
  public let allowed: [BlessingPattern]

  /// notAllowed denotes the set of blessings (and their delegates) that
  /// have been explicitly blacklisted from the allowed set.
  ///
  /// For example:
  /// allowed: {"alice:friend"}, notAllowed: {"alice:friend:bob"}
  /// grants access to principals that present "alice:friend",
  /// "alice:friend:carol" etc. but NOT to a principal that presents
  /// "alice:friend:bob" or "alice:friend:bob:spouse" etc.
  public let notAllowed: [BlessingPattern]

  public init(allowed: [BlessingPattern] = [], notAllowed: [BlessingPattern] = []) {
    self.allowed = allowed
    self.notAllowed = notAllowed
  }

  func toJsonable() -> [String: AnyObject] {
    return ["In": allowed, "NotIn": notAllowed]
  }

  static func fromJsonable(jsonable: [String: AnyObject]) -> AccessList? {
    guard let castIn = jsonable["In"] as? [String],
      castNotIn = jsonable["NotIn"] as? [String] else {
        return nil
    }
    return AccessList(
      allowed: castIn as [BlessingPattern],
      notAllowed: castNotIn as [BlessingPattern])
  }
}

/// AccessController provides access control for various syncbase objects.
public protocol AccessController {
  /// getPermissions returns the current Permissions for an object.
  func getPermissions() throws -> (Permissions, PermissionsVersion)

  /// setPermissions replaces the current Permissions for an object.
  func setPermissions(perms: Permissions, version: PermissionsVersion) throws
}
