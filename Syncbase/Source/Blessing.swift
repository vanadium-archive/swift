// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

// TODO(zinman): This whole file needs to get updated with a consistent strategy for all cgo
// bridges. In general this code should be moved to go.

func aliasFromBlessingPattern(pattern: BlessingPattern) -> String? {
  return aliasFromBlessingString(pattern)
}

private func aliasFromBlessingString(blessingStr: String) -> String? {
  guard blessingStr.containsString(":") else {
    return nil
  }
  let parts = blessingStr.componentsSeparatedByString(":")
  return parts[parts.count - 1]
}

private func blessingStringFromAlias(alias: String) throws -> String {
  return try Principal.appBlessing() + ":" + alias
}

func blessingPatternFromAlias(alias: String) throws -> BlessingPattern {
  return BlessingPattern(try blessingStringFromAlias(alias))
}

func personalBlessingString() throws -> String {
  return try SyncbaseCore.Principal.userBlessing()
}

func selfAndCloudAL() throws -> SyncbaseCore.AccessList {
  return SyncbaseCore.AccessList(allowed:
      [BlessingPattern(try personalBlessingString()), BlessingPattern(Syncbase.cloudBlessing)])
}

func defaultDatabasePerms() throws -> SyncbaseCore.Permissions {
  let anyone = SyncbaseCore.AccessList(allowed: [BlessingPattern("...")])
  let selfAndCloud = try selfAndCloudAL()
  return [
    Tags.Resolve.rawValue: anyone,
    Tags.Read.rawValue: selfAndCloud,
    Tags.Write.rawValue: selfAndCloud,
    Tags.Admin.rawValue: selfAndCloud]
}

func defaultCollectionPerms() throws -> SyncbaseCore.Permissions {
  let selfAndCloud = try selfAndCloudAL()
  return [
    Tags.Read.rawValue: selfAndCloud,
    Tags.Write.rawValue: selfAndCloud,
    Tags.Admin.rawValue: selfAndCloud]
}

func defaultSyncgroupPerms() throws -> SyncbaseCore.Permissions {
  let selfAndCloud = try selfAndCloudAL()
  return [
    Tags.Read.rawValue: selfAndCloud,
    Tags.Admin.rawValue: selfAndCloud]
}
