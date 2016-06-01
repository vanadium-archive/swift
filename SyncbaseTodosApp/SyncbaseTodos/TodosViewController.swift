// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit

class TodosViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var addButton: UIBarButtonItem!
  // The menu toolbar is shown when the "edit" navigation bar is pressed
  @IBOutlet weak var menuToolbar: UIToolbar!
  @IBOutlet weak var menuToolbarTopConstraint: NSLayoutConstraint!
  var data: [TodoList] = []
  static let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "MMM d"
    return dateFormatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    // Hide the bottom menu by default
    menuToolbarTopConstraint.constant = -menuToolbar.frame.size.height
    createFakeData()
    tableView.reloadData()
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    tableView.reloadData()
  }

  func createFakeData() {
    // TODO(azinman): Remove
    data = [TodoList(name: "Nooglers Training"), TodoList(name: "Sunday BBQ Shopping")]
    let person = Person(name: "John", imageName: "profilePhoto")
    data[0].members = [person, person, person]
    data[0].tasks = [
      Task(text: "Retrieve Noogler Hat"),
      Task(text: "Eat lunch at a cafe", done: true),
      Task(text: "Pick up badge", done: true),
      Task(text: "Parkin building 45", done: true),
    ]

    data[1].members = [person, person]
    data[1].tasks = [
      Task(text: "Apples"),
      Task(text: "Frosted Mini Wheats", done: true),
      Task(text: "Whole wheat bagels"),
      Task(text: "Kale"),
      Task(text: "Eggs", done: true),
    ]
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // When we tap on a todo list and segue into the tasks list
    if let tvc = segue.destinationViewController as? TasksViewController,
      cell = sender as? TodoListCell,
      indexPath = tableView.indexPathForCell(cell) {
        tvc.todoList = data[indexPath.row]
    }
  }
}

//Handles tableview functionality, including rendering and swipe actions. Tap actions are
// handled directly in Main.storyboard using segues
extension TodosViewController: UITableViewDelegate, UITableViewDataSource {
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    // TodoListCell is the prototype inside the Main.storyboard. Cannot fail.
    let cell = tableView.dequeueReusableCellWithIdentifier(TodoListCell.todoListCellId, forIndexPath: indexPath) as! TodoListCell
    cell.todoList = data[indexPath.row]
    cell.updateView()
    return cell
  }

  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    switch editingStyle {
    case .Delete:
      data.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    default: break
    }
  }

  func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
    let actions = [
      UITableViewRowAction(style: .Normal, title: "Check All", handler: { [weak self](action, indexPath) in
        self?.completeAllTasks(indexPath)
      }),
      UITableViewRowAction(style: .Default, title: "Delete", handler: { [weak self](action, indexPath) in
        self?.deleteList(indexPath)
      })
    ]
    return actions
  }
}

// IBActions and data modification functions
extension TodosViewController {
  @IBAction func toggleEdit() {
    // Do this manually because we're a UIViewController not a UITableViewController, so we don't
    // get editing behavior for free
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

  @IBAction func debug() {
    // TODO(azinman): Make real
  }

  @IBAction func toggleSharing() {
    // TODO(azinman): Make real
  }

  func completeAllTasks(indexPath: NSIndexPath) {
    // TODO(azinman): Make real
    assert(data.indices.contains(indexPath.row), "data does not contain that index path")
    let todoList = data[indexPath.row]
    for task in todoList.tasks {
      task.done = true
    }
    tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  }

  func deleteList(indexPath: NSIndexPath) {
    // TODO(azinman): Make real
    data.removeAtIndex(indexPath.row)
    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  }
}

/// Shows a todo list's name, number of items completed, photos of members, and last modified date.
class TodoListCell: UITableViewCell {
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var completedLabel: UILabel!
  @IBOutlet weak var memberView: MemberView!
  @IBOutlet weak var lastModifiedLabel: UILabel!
  static let todoListCellId = "todoListCellId"
  var todoList = TodoList()

  // Fills in the iboutlets with data from todoList local property.
  // memberView has it's only render method that draws out the photos of the members in this todo
  // list.
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
    completedLabel.text = "\(todoList.numberTasksComplete())/\(todoList.tasks.count) completed"
    lastModifiedLabel.text = TodosViewController.dateFormatter.stringFromDate(todoList.updatedAt)
    // Draw the photos of list members
    memberView.todoList = todoList
    memberView.updateView()
  }

}