// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// All of this is trash to be replaced by syncbase model
class TodoList {
  var name: String = ""
  var updatedAt: NSDate = NSDate()
  var members: [Person] = []
  var tasks: [Task] = []

  convenience init (name: String) {
    self.init()
    self.name = name
  }

  func isComplete() -> Bool {
    return tasks.filter { task in
      return !task.done
    }.count == 0
  }

  func numberTasksComplete() -> Int {
    return tasks.filter { task in
      return task.done
    }.count
  }
}