// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Syncbase
import UIKit

let deviceUUID = UIDevice.currentDevice().identifierForVendor ?? NSUUID()
let collectionName = "dice_\(deviceUUID.UUIDString.stringByReplacingOccurrencesOfString("-", withString: ""))"
let rowKey = "result"

class DiceViewController: UIViewController {
  @IBOutlet weak var numberLabel: UILabel!
  var collection: Collection?

  override func viewDidLoad() {
    super.viewDidLoad()

    do {
      collection = try Syncbase.database().collection(collectionName)
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    do {
      try Syncbase.database().addWatchChangeHandler(
        pattern: CollectionRowPattern(rowKey: rowKey),
        handler: WatchChangeHandler(
          onInitialState: onWatchChanges,
          onChangeBatch: onWatchChanges,
          onError: onWatchError))
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    do {
      try Syncbase.database().removeAllWatchChangeHandlers()
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  func onWatchChanges(changes: [WatchChange]) {
    let lastValue = changes
    // Only look at the prefix so that different devices (with different collection names)
    // are examined for their values.
    .filter { $0.collectionId?.name.hasPrefix("dice") ?? false }
      .filter { $0.entityType == .Row && $0.changeType == .Put }
      .last?
      .value
    if let value = lastValue {
      // Get the single byte out via typecasting to an array of UInt8. This will be unnecessary
      // when we have VOM support in Swift.
      let num = unsafeBitCast(value.bytes, UnsafePointer<UInt8>.self).memory
      numberLabel.text = num.description
    }
  }

  func onWatchError(err: ErrorType) {
    // Something went wrong. Watch is no longer active.
    print("Unexpected watch error: \(err)")
  }

  @IBAction func didPressRollDie(sender: UIButton) {
    var nextNum = UInt8(arc4random_uniform(6) + 1)
    // Right now we can only store NSData, so we have to serialize this number to store it.
    // Soon we will have VOM support and can just put the raw int as the value and expect
    // it to work properly.
    let value = NSData(bytes: &nextNum, length: 1)
    do {
      try collection?.put(rowKey, value: value)
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  @IBAction func didPressLogout(sender: UIBarButtonItem) {
    performSegueWithIdentifier("LogoutSegue", sender: self)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let loginVC = segue.destinationViewController as? LoginViewController {
      loginVC.doLogout = true
    }
  }
}

