// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// All of this is trash to be replaced by syncbase model
final class Task: Jsonable {
  var key: NSUUID = NSUUID()
  var text: String = ""
  var addedAt: NSDate = NSDate()
  var done: Bool = false

  init(key: NSUUID = NSUUID(), text: String, addedAt: NSDate = NSDate(), done: Bool = false) {
    self.key = key
    self.text = text
    self.addedAt = addedAt
    self.done = done
  }

  func toJsonable() -> [String: AnyObject] {
    return ["text": text, "addedAt": addedAt.timeIntervalSince1970, "done": done]
  }

  static func fromJsonable(data: [String: AnyObject]) -> Task? {
    guard let text = data["text"] as? String,
      addedAt = data["addedAt"] as? NSTimeInterval,
      done = data["done"] as? Bool else {
        return nil
    }
    return Task(text: text, addedAt: NSDate(timeIntervalSince1970: addedAt), done: done)
  }
}