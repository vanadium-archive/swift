// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit

enum Section: Int {
  case Invite
  case Tasks
}

class TasksViewController: UIViewController {
  let inviteCellId = "inviteCellId"
  let taskCellId = "taskCellId"
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var addButton: UIBarButtonItem!
  var todoList = TodoList() // Set by segue from TodosViewController
  static let dateFormatter: NSDateFormatter = {
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateFormat = "MMM d"
    return dateFormatter
  }()

  override func viewDidLoad() {
    super.viewDidLoad()
    title = todoList.name
    tableView.reloadData()
  }
}

/*
 * Handles tableview functionality, including rendering and swipe actions. Tap actions are
 * handled directly in Main.storyboard using segues
 */
extension TasksViewController: UITableViewDataSource, UITableViewDelegate {
  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 2
  }

  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == Section.Invite.rawValue {
      return 1
    } else {
      return todoList.tasks.count
    }
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    // These cells are prototypes inside the Main.storyboard. Cannot fail.
    if indexPath.section == Section.Invite.rawValue {
      let cell = tableView.dequeueReusableCellWithIdentifier(inviteCellId, forIndexPath: indexPath) as! InviteCell
      cell.todoList = todoList
      cell.updateView()
      return cell
    } else {
      let cell = tableView.dequeueReusableCellWithIdentifier(taskCellId, forIndexPath: indexPath) as! TaskCell
      cell.task = todoList.tasks[indexPath.row]
      cell.updateView()
      return cell
    }
  }

  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      self.deleteTask(indexPath)
    }
  }

  func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    if indexPath.section == Section.Invite.rawValue {
      return 90
    } else {
      return 60
    }
  }
}

/*
 * IBActions and data modification functions
 */
extension TasksViewController {
  @IBAction func toggleEdit() {
    // Do this manually because we're a UIViewController not a UITableViewController, so we don't
    // get editing behavior for free
    if tableView.editing {
      tableView.setEditing(false, animated: true)
      navigationItem.rightBarButtonItem?.title = "Edit"
      addButton.enabled = true
    } else {
      tableView.setEditing(true, animated: true)
      navigationItem.rightBarButtonItem?.title = "Done"
      addButton.enabled = false
    }

    UIView.animateWithDuration(0.35) { self.view.layoutIfNeeded() }
  }

  @IBAction func showAddTask() {
    let alert = UIAlertController(title: "Add task", message: nil, preferredStyle: .Alert)
    alert.addTextFieldWithConfigurationHandler { (textField) in }
    alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
    alert.addAction(UIAlertAction(title: "Add", style: .Default, handler: { [weak self] action in
      if let field = alert.textFields?.first, text = field.text {
        self?.addTask(text)
      }
      }))
    presentViewController(alert, animated: true, completion: nil)
  }

  func addTask(text: String) {
    // TODO(azinman): Make real
    let task = Task(text: text)
    todoList.tasks.insert(task, atIndex: 0)
    tableView.insertRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: Section.Tasks.rawValue)], withRowAnimation: .Automatic)
  }

  func deleteTask(indexPath: NSIndexPath) {
    todoList.tasks.removeAtIndex(indexPath.row)
    tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
  }
}

// Displays the memebers of the todo list as photos and an invite button to launch the invite flow
class InviteCell: UITableViewCell {
  @IBOutlet weak var memberView: MemberView!
  var todoList: TodoList?

  // Member view has its own render method that draws the member photos
  func updateView() {
    selectionStyle = .None
    memberView.todoList = todoList
    memberView.updateView()
  }
}

/// TaskCell displays a single task with a checkbox for completing it, the text of the task, and
/// the time it was added.
class TaskCell: UITableViewCell {
  @IBOutlet weak var completeButton: UIButton!
  @IBOutlet weak var taskNameLabel: UILabel!
  @IBOutlet weak var addedAtLabel: UILabel!
  var task = Task(text: "default")

  func updateView() {
    selectionStyle = .None

    if task.done {
      let str = NSAttributedString(string: task.text, attributes: [
        NSStrikethroughStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
        NSForegroundColorAttributeName: UIColor.lightGrayColor()
      ])
      taskNameLabel.attributedText = str
    } else {
      taskNameLabel.text = task.text
    }

    addedAtLabel.text = TasksViewController.dateFormatter.stringFromDate(task.addedAt)
    updateCompleteButton()
    setNeedsLayout()
  }

  func updateCompleteButton() {
    if task.done {
      completeButton.setImage(UIImage(named: "checkmarkOn"), forState: .Normal)
    } else {
      completeButton.setImage(UIImage(named: "checkmarkOff"), forState: .Normal)
    }
  }

  @IBAction func toggleComplete() {
    task.done = !task.done
    updateView()
  }
}