// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import GoogleSignIn
import UIKit
import Syncbase

class TodosViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var addButton: UIBarButtonItem!
  // The menu toolbar is shown when the "edit" navigation bar is pressed.
  @IBOutlet weak var menuToolbar: UIToolbar!
  @IBOutlet weak var menuToolbarTopConstraint: NSLayoutConstraint!
  var handler: ModelEventHandler!
  static let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "MMM d"
    return dateFormatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Hide the bottom menu by default
    menuToolbarTopConstraint.constant = -menuToolbar.frame.size.height
    handler = ModelEventHandler(onEvents: onEvents)
    do {
      try startWatching()
    } catch {
      print("Unable to start watch: \(error)")
    }
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    startWatchModelEvents(handler)
    tableView.reloadData()
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    stopWatchingModelEvents(handler)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // When we tap on a todo list and segue into the tasks list.
    if let tvc = segue.destinationViewController as? TasksViewController,
      cell = sender as? TodoListCell,
      indexPath = tableView.indexPathForCell(cell) {
        tvc.todoList = todoLists[indexPath.row]
    }
  }

  func onEvents(events: [ModelEvent]) {
    print("got events: \(events)")
    tableView.reloadData()
  }
}

/// Handles tableview functionality, including rendering and swipe actions. Tap actions are
/// handled directly in Main.storyboard using segues.
extension TodosViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return todoLists.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    // TodoListCell is the prototype inside the Main.storyboard. Cannot fail.
    let cell = tableView.dequeueReusableCellWithIdentifier(
      TodoListCell.todoListCellId,
      forIndexPath: indexPath) as! TodoListCell
    cell.todoList = todoLists[indexPath.row]
    cell.updateView()
    return cell
  }

  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    switch editingStyle {
    case .Delete:
      deleteRow(indexPath)
    default: break
    }
  }

  func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
    let actions = [
      UITableViewRowAction(style: .Normal, title: "Check All", handler: { [weak self](action, indexPath) in
        self?.completeAllTasks(indexPath)
      }),
      UITableViewRowAction(style: .Default, title: "Delete", handler: { [weak self](action, indexPath) in
        self?.deleteRow(indexPath)
      })
    ]
    return actions
  }

  func deleteRow(indexPath: NSIndexPath) {
    do {
      try removeList(todoLists[indexPath.row])
    } catch {
      print("Unexpected error: \(error)")
      let ac = UIAlertController(
        title: "Oops!",
        message: "Error deleting list. Try again.",
        preferredStyle: .Alert)
      ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
      self.presentViewController(ac, animated: true, completion: nil)
    }
  }
}

/// IBActions and data modification functions.
extension TodosViewController {
  @IBAction func toggleEdit() {
    // Do this manually because we're a UIViewController not a UITableViewController, so we don't
    // get editing behavior for free.
    if tableView.editing {
      tableView.setEditing(false, animated: true)
      navigationItem.leftBarButtonItem?.title = "Edit"
      menuToolbarTopConstraint.constant = -menuToolbar.frame.size.height
      addButton.enabled = true
    } else {
      tableView.setEditing(true, animated: true)
      navigationItem.leftBarButtonItem?.title = "Done"
      menuToolbarTopConstraint.constant = 0
      addButton.enabled = false
    }

    UIView.animateWithDuration(0.35) { self.view.layoutIfNeeded() }
  }

  @IBAction func didPressAddTodoList() {
    let ac = UIAlertController(title: "New Todo List",
      message: "Please name your new list",
      preferredStyle: UIAlertControllerStyle.Alert)
    ac.addAction(UIAlertAction(title: "Create", style: UIAlertActionStyle.Default)
      { (action: UIAlertAction) in
        if let name = ac.textFields?.first?.text where !name.isEmpty {
          self.addTodoList(name)
        }
    })
    ac.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
    ac.addTextFieldWithConfigurationHandler { $0.placeholder = "My New List" }
    self.presentViewController(ac, animated: true, completion: nil)
  }

  func addTodoList(name: String) {
    let list = TodoList(name: name)
    do {
      try addList(list)
    } catch {
      print("Error adding list: \(error)")
      let ac = UIAlertController(
        title: "Oops!",
        message: "Error adding list. Try again.",
        preferredStyle: .Alert)
      ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
      self.presentViewController(ac, animated: true, completion: nil)
    }
  }

  @IBAction func debug() {
    // TODO(azinman): Make real
  }

  @IBAction func toggleSharing() {
    // TODO(azinman): Make real
  }

  func completeAllTasks(indexPath: NSIndexPath) {
    let todoList = todoLists[indexPath.row]
    do {
      try setTasksAreDone(todoList, tasks: todoList.tasks, isDone: true)
    } catch {
      print("Error completing all tasks: \(error)")
      let ac = UIAlertController(
        title: "Oops!",
        message: "Error completing all tasks. Try again.",
        preferredStyle: .Alert)
      ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
      presentViewController(ac, animated: true, completion: nil)
    }
  }
}

/// Shows a todo list's name, number of items completed, photos of members, and last modified date.
class TodoListCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var completedLabel: UILabel!
  @IBOutlet weak var memberView: MemberView!
  @IBOutlet weak var lastModifiedLabel: UILabel!
  static let todoListCellId = "todoListCellId"
  var todoList: TodoList!

  /// Fills in the iboutlets with data from todoList local property. memberView has it's only render
  /// method that draws out the photos of the members in this todo list.
  func updateView() {
    if todoList.isComplete() {
      // Draw a strikethrough
      let str = NSAttributedString(string: todoList.name, attributes: [
        NSStrikethroughStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
        NSForegroundColorAttributeName: UIColor.lightGrayColor()
      ])
      titleLabel.attributedText = str
    } else {
      titleLabel.text = todoList.name
    }
    if todoList.tasks.isEmpty {
      completedLabel.text = "No tasks"
    } else {
      completedLabel.text = "\(todoList.numberTasksComplete())/\(todoList.tasks.count) completed"
    }
    lastModifiedLabel.text = TodosViewController.dateFormatter.stringFromDate(todoList.updatedAt)
    // Draw the photos of list members
    memberView.todoList = todoList
    memberView.updateView()
  }

}