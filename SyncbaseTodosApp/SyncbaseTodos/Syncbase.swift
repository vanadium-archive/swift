// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// The Todo app's model uses the Syncbase key-value store using the following data types:
//
// type TodoList struct {
//   Name string
//   UpdatedAt timestamp
// }
//
// type Task struct {
//   Text string
//   AddedAt timestamp
//   Done bool
// }
//
// These data types are currently serialized using JSON until VOM has been ported to Swift, at which
// point we'll use the generated VDL / VOM structs. Until then, we do not have cross-platform
// compatibility with Android, which uses VOM.
//
// Each Todo List is stored in its own collection in the Syncbase database, where its rows represent
// the individual tasks. The collection is named with a unique UUID (that UUID is generated
// automatically by the API's Database.createCollection method). The metadata on this list, that is
// to say the serialized TodoList struct, is stored in a special row in these collections with
// the key `todoListKey`. All other rows are the serialized `Task` structs.
//
// This file provides the CRUD (create, read, update, delete) APIs to manipulate todo lists and
// structs in their high-level Swift representations. It also contains the logic that "watches" the
// Syncbase database in order to replicate these lists and todos in-memory as Swift structs as
// the data changes (either from the user invoking the CRUD APIs or from other users). As the watch
// logic determines the exact change, the related `ModelEvent` notifies any listeners to these
// changes, which are the TodosViewController or the TasksViewController.
//
// Note that the data model is "unidirectional," which is to say that when the user press a button,
// that button only will call the appropriate data model API call. It does not update the UI itself.
// Instead, the running watch will receive the change the same way regardless if it originated on
// this device or another, and update the UI accordingly. This is the principal intended design of
// Syncbase.

import Foundation
import Syncbase

let todoListKey = "list"
let todoListCollectionPrefix = "lists"
let userProfilePhotoURLKey = "userProfilePhotoURL"

var todoLists: [TodoList] = []

// MARK: Watch high level events

enum ModelEvent {
  case ReloadLists(lists: [TodoList])
  case AddList(list: TodoList, index: Int)
  case UpdateList(list: TodoList, index: Int)
  case DeleteList(list: TodoList, index: Int)
  case AddTask(list: TodoList, listIndex: Int, task: Task, taskIndex: Int)
  case UpdateTask(list: TodoList, listIndex: Int, task: Task, taskIndex: Int)
  case DeleteTask(list: TodoList, listIndex: Int, task: Task, taskIndex: Int)
}

// Struct to hold the callbacks for WatchEvents. It is hashable to support adding/removing callbacks
// which otherwise cannot be equated.

private let dispatch = Dispatch<ModelEvent>()

final class ModelEventHandler: DispatchHandler<ModelEvent> {
  required init(onEvents: [ModelEvent] -> ()) {
    super.init(onEvents: onEvents)
  }
}

/// Used by the ViewControllers to subscribe to model events.
func startWatchModelEvents(eventHandler: ModelEventHandler) {
  dispatch.watch(eventHandler)
}

/// Used by the ViewControllers to unsubscribe to model events.
func stopWatchingModelEvents(eventHandler: ModelEventHandler) {
  dispatch.unwatch(eventHandler)
}

// MARK: Watch low-level events
private var watchHandler: WatchChangeHandler?

func startWatching() throws {
  if let handler = watchHandler {
    try Syncbase.database().removeWatchChangeHandler(handler)
    watchHandler = nil
  }
  let handler = WatchChangeHandler(
    onInitialState: onInitialState,
    onChangeBatch: onChangeBatch,
    onError: { err in
      // No more calls to watch will occur.
      print("Unexpected error watching model: \(err)")
  })
  try Syncbase.database().addWatchChangeHandler(handler: handler)
  watchHandler = handler
}

private func onInitialState(changes: [WatchChange]) {
  // As the changes can come in any order (e.g. a task after the TodoList serialized), we bucket
  // by collectionId and keep the serialized todoList row first. That way we can re-construct all
  // of the data properly.

  // Now that we have it all bucketed and properly ordered, reconstruct the data.
  todoLists.removeAll()
  for (collectionId, changes) in groupListChangesByCollectionId(changes) {
    // TOD(zinman): How can this fail? How to better handle than crashing?
    let collection = try! Syncbase.database().collection(collectionId)
    // groupListChangesByCollectionId puts the serialized TodoList first.
    guard let list = changes.first?.toTodoList(collection) else {
      continue
    }
    for change in changes.dropFirst() {
      if let task = change.toTask() {
        list.tasks.append(task)
      }
    }
    todoLists.append(list)
  }

  dispatch.notify([ModelEvent.ReloadLists(lists: todoLists)])
}

func onChangeBatch(changes: [WatchChange]) {
  var events: [ModelEvent] = []
  for (collectionId, var changes) in groupListChangesByCollectionId(changes) {
    // TOD(zinman): How can this fail? How to better handle than crashing?
    let collection = try! Syncbase.database().collection(collectionId)
    var list: TodoList!
    // This is a O(N) search, but it's ok since this is after the initial state we expeect few of
    // these callbacks AND n to be small. If either of these assumptions change we'll need to
    // use a map or an alternative approach to loading all into memory.
    var listIdx = todoLists.indexOf({ $0.collection?.collectionId == collectionId })
    if let idx = listIdx {
      list = todoLists[idx]
    }

    // The first change will always be a TodoList (row == todoListKey) IF this batch is adding
    // updating, or deleting a TodoList. Otherwise, the changes are to tasks in the TodoList.
    let firstChange = changes.first!
    if let newList = firstChange.toTodoList(collection) {
      changes = Array(changes.dropFirst(1))
      // First change is a Put that contains a TodoList. It's either an insert or an update.
      if listIdx != nil {
        // It's an update of the TodoList. We can recycle its tasks knowing any updates to its
        // tasks will be in a separate change.
        newList.tasks = list.tasks
        // TODO(zinman): Confirm this later on.
        newList.members = list.members
        list = newList
        todoLists[listIdx!] = list
        events.append(ModelEvent.UpdateList(list: list, index: listIdx!))
      } else {
        // Inserting a new TodoList.
        list = newList
        listIdx = todoLists.count
        todoLists.append(list)
        events.append(ModelEvent.AddList(list: list, index: listIdx!))
      }
    } else if firstChange.changeType == .Delete &&
    (firstChange.row == todoListKey || firstChange.entityType == .Collection) {
      changes = Array(changes.dropFirst(1))
      // Deleting this collection -- since it's already grouped by this collectionId we can
      // continue after deleting the TodoList.
      if listIdx != nil {
        todoLists.removeAtIndex(listIdx!)
        events.append(ModelEvent.DeleteList(list: list, index: listIdx!))
      }
      continue
    } else if listIdx == nil {
      // Don't have list existing or incoming to process the changes.
      continue
    }

    // Process task changes
    for change in changes {
      assert(firstChange.row != todoListKey)
      if let task = change.toTask() {
        // Is it an update or an insert?
        if let taskIdx = list.tasks.indexOf({ $0.key == task.key }) {
          list.tasks[taskIdx] = task
          events.append(ModelEvent.UpdateTask(list: list, listIndex: listIdx!, task: task, taskIndex: taskIdx))
        } else {
          list.tasks.append(task)
          events.append(ModelEvent.UpdateTask(list: list, listIndex: listIdx!, task: task, taskIndex: list.tasks.count - 1))
        }
      } else if change.changeType == .Delete,
        let row = change.row,
        key = NSUUID(UUIDString: row) {
          if let taskIdx = list.tasks.indexOf({ $0.key == key }) {
            let task = list.tasks.removeAtIndex(taskIdx)
            events.append(ModelEvent.DeleteTask(list: list, listIndex: listIdx!, task: task, taskIndex: taskIdx))
          }
      }
    }
  }
  dispatch.notify(events)
}

// MARK: MODEL API

func addList(list: TodoList) throws {
  let data = try NSJSONSerialization.dataWithJSONObject(list.toJsonable(), options: [])
  list.collection = try Syncbase.database().createCollection(prefix: todoListCollectionPrefix)
  try list.collection!.put(todoListKey, value: data)
  // No need to update the local data ourselves -- that will happen in the watch handler.
}

func removeList(list: TodoList) throws {
  guard let collection = list.collection else {
    throw SyncbaseError.IllegalArgument(detail: "Missing collection from TodoList: \(list)")
  }
  try collection.destroy()
  // No need to update the local data ourselves -- that will happen in the watch handler.
}

func addTask(list: TodoList, task: Task) throws {
  let data = try NSJSONSerialization.dataWithJSONObject(task.toJsonable(), options: [])
  let key = task.key.UUIDString
  try list.collection!.put(key, value: data)
}

func removeTask(list: TodoList, task: Task) throws {
  let key = task.key.UUIDString
  try list.collection!.delete(key)
}

func setTaskIsDone(list: TodoList, task: Task, isDone: Bool) throws {
  task.done = isDone
  // This is the same operation as updating the row since we put the data.
  try addTask(list, task: task)
}

func setTasksAreDone(list: TodoList, tasks: [Task], isDone: Bool) throws {
  try Syncbase.database().runInBatch { bdb in
    for task in tasks {
      task.done = isDone
      let data = try NSJSONSerialization.dataWithJSONObject(task.toJsonable(), options: [])
      let key = task.key.UUIDString
      // We must get a reference via the batch database handle rather than the existing non-batch
      // cached collection.
      try bdb.collection(list.collection!.collectionId).put(key, value: data)
    }
  }
}

func setUserPhotoURL(url: NSURL) throws {
  let jsonable = [url.absoluteString]
  let json = try NSJSONSerialization.dataWithJSONObject(jsonable, options: [])
  try Syncbase.database().userdataCollection.put(userProfilePhotoURLKey, value: json)
}

func userProfileURL() throws -> NSURL? {
  let data: NSData? = try Syncbase.database().userdataCollection.get(userProfilePhotoURLKey)
  guard let json = data,
    jsonable = try NSJSONSerialization.JSONObjectWithData(json, options: []) as? [String],
    url = jsonable.first else {
      return nil
  }
  return NSURL(string: url)
}

// MARK: Helpers

private func groupListChangesByCollectionId(changes: [WatchChange]) -> [Identifier: [WatchChange]] {
  var changesByCollectionId: [Identifier: [WatchChange]] = [:]
  for change in changes {
    guard let collectionId = change.collectionId where collectionId.name.hasPrefix(todoListCollectionPrefix) else {
      continue
    }
    // Keep deletes on all entities (collections for lists, rows for tasks), but otherwise only keep
    // row changes for puts -- we don't use the collection put change.
    if change.changeType == .Put && change.entityType != .Row {
      continue
    }
    if var cxChanges = changesByCollectionId[collectionId] {
      if change.row == todoListKey {
        // This is the row that describes the whole TodoList. Keep it first.
        cxChanges.insert(change, atIndex: 0)
      } else {
        cxChanges.append(change)
      }
      changesByCollectionId[collectionId] = cxChanges
    } else {
      changesByCollectionId[collectionId] = [change]
    }
  }
  return changesByCollectionId
}

private extension WatchChange {
  func toTask() -> Task? {
    if changeType != .Put || entityType != .Row || row == todoListKey {
      return nil
    }
    guard let row = row,
      key = NSUUID(UUIDString: row),
      json = value,
      obj = try? NSJSONSerialization.JSONObjectWithData(json, options: []) as? [String: AnyObject],
      jsonable = obj,
      task = Task.fromJsonable(jsonable) else {
        return nil
    }
    task.key = key
    return task
  }

  func toTodoList(collection: Collection) -> TodoList? {
    if changeType != .Put || entityType != .Row || row != todoListKey {
      return nil
    }
    guard let json = value,
      obj = try? NSJSONSerialization.JSONObjectWithData(json, options: []) as? [String: AnyObject],
      jsonable = obj,
      list = TodoList.fromJsonable(jsonable) else {
        return nil
    }
    list.collection = collection
    return list
  }
}
