// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents an invitation to join a syncgroup.
public struct SyncgroupInvite {
  public let syncgroupId: Identifier
  public let inviterBlessingNames: [String]

  public init(syncgroupId: Identifier, inviterBlessingNames: [String]) {
    self.syncgroupId = syncgroupId
    self.inviterBlessingNames = inviterBlessingNames
  }

  public var inviter: User? {
    guard !inviterBlessingNames.isEmpty,
    // TODO(zinman via alexfandrianto): This will normally work because inviter blessing names should
    // be just a single name. However, this will probably not work if it's the cloud's blessing.
    let alias = aliasFromBlessingPattern(inviterBlessingNames[0]) else {
      return nil
    }
    return User(alias: alias)
  }

  public var syncgroupCreator: User? {
    guard let alias = aliasFromBlessingPattern(syncgroupId.blessing) else {
      return nil
    }
    return User(alias: alias)
  }
}