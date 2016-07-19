// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import Syncbase

final class TodoList: Jsonable {
  // This is set in Syncbase.swift when the TodoList is originally deserialized.
  var collection: Collection? = nil
  var name: String = ""
  var updatedAt: NSDate = NSDate()
  var members: [Person] = []
  var tasks: [Task] = []

  init(name: String, updatedAt: NSDate = NSDate()) {
    self.name = name
    self.updatedAt = updatedAt
  }

  func isComplete() -> Bool {
    return !tasks.isEmpty && tasks.filter { task in
      return !task.done
    }.count == 0
  }

  func numberTasksComplete() -> Int {
    return tasks.filter { task in
      return task.done
    }.count
  }

  func toJsonable() -> [String: AnyObject] {
    return [
      "name": name,
      "updatedAt": updatedAt.timeIntervalSince1970]
  }

  static func fromJsonable(data: [String: AnyObject]) -> TodoList? {
    guard let name = data["name"] as? String,
      updatedAt = data["updatedAt"] as? NSTimeInterval else {
        return nil
    }
    return TodoList(name: name, updatedAt: NSDate(timeIntervalSince1970: updatedAt))
  }
}
