// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import Syncbase
import enum Syncbase.Syncbase
import class Syncbase.Database
@testable import SyncbaseCore

let unitTestRootDir = NSFileManager.defaultManager()
  .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
  .URLByAppendingPathComponent("SyncbaseUnitTest")
  .path!

extension XCTestCase {
  class func configureDb(disableUserdataSyncgroup disableUserdataSyncgroup: Bool, disableSyncgroupPublishing: Bool) {
    SyncbaseCore.Syncbase.isUnitTest = true

    try! NSFileManager.defaultManager().removeItemAtPath(unitTestRootDir)

    // TODO(zinman): Once we have create-and-join implemented don't always set
    // disableUserdataSyncgroup to true.
    try! Syncbase.configure(
      adminUserId: "unittest@google.com",
      rootDir: unitTestRootDir,
      disableUserdataSyncgroup: disableUserdataSyncgroup,
      disableSyncgroupPublishing: disableSyncgroupPublishing,
      queue: testQueue)
    let semaphore = dispatch_semaphore_create(0)
    Syncbase.login(GoogleOAuthCredentials(token: ""), callback: { err in
      XCTAssertNil(err)
      dispatch_semaphore_signal(semaphore)
    })
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
  }

  func withDb(runBlock: Database throws -> Void) {
    do {
      let db = try Syncbase.database()
      try runBlock(db)
      try db.collections().forEach { try $0.destroy() }
      // TODO(zinman): Re-enable when supported in Syncbase
//      try db.syncgroups().forEach { try $0.coreSyncgroup.destroy() }
    } catch let e {
      XCTFail("Unexpected error: \(e)")
    }
  }
}
