// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore

/// Represents an invitation to join a syncgroup.
public struct SyncgroupInvite {
  public let syncgroupId: Identifier
  public let remoteSyncbaseName: String
  public let expectedSyncbaseBlessings: [String]

  public init(syncgroupId: Identifier, remoteSyncbaseName: String, expectedSyncbaseBlessings: [String]) {
    self.syncgroupId = syncgroupId
    self.remoteSyncbaseName = remoteSyncbaseName
    self.expectedSyncbaseBlessings = expectedSyncbaseBlessings
  }
}