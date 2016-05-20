// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import SyncbaseCore
import UIKit

struct DatabasesDemoDescription: DemoDescription {
  let segue: String = "DatabasesDemo"

  var description: String {
    return "Database Inspector"
  }

  var instance: Demo {
    return DatabasesDemo()
  }
}

@objc class DatabasesDemo: UIViewController, Demo {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var addBarButton: UIBarButtonItem!
  var databases = [Identifier]()

  func start() { }

  func reloadData() {
    do {
      databases = try Syncbase.instance.listDatabases()
      tableView.reloadData()
    } catch (let e) {
      print("Unable to load databases: \(e)")
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationItem.rightBarButtonItem = addBarButton
    reloadData()
  }

  @IBAction func didPressAdd(sender: UIBarButtonItem) {
    guard Syncbase.instance.isLoggedIn else {
      presentAuthAlert()
      return
    }

    let ac = UIAlertController(title: "Create a database", message: "What to call it?", preferredStyle: .Alert)
    ac.addTextFieldWithConfigurationHandler { textField in
      textField.placeholder = "Database name"
      textField.keyboardType = .Default
    }
    let action = UIAlertAction(title: "Create", style: .Default, handler: { action in
      if let text = ac.textFields?.first?.text where text != "" {
        self.createDatabase(text)
      }
    })
    ac.addAction(action)
    ac.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
    presentViewController(ac, animated: true, completion: nil)
  }

  func presentAuthAlert() {
    let ac = UIAlertController(title: "Not authorized",
      message: "Sign in to Google to create databases",
      preferredStyle: .Alert)
    ac.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
    ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: { _ in
      if !Syncbase.instance.isLoggedIn {
        self.performSegueWithIdentifier("GoogleSignInSegue", sender: self)
      }
      }))
    presentViewController(ac, animated: true, completion: nil)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    super.prepareForSegue(segue, sender: sender)
    if let nvc = segue.destinationViewController as? UINavigationController,
      let vc = nvc.topViewController as? GoogleSignInDemo {
        vc.dismissOnSignIn = true
    }
  }

  func createDatabase(name: String) {
    do {
      let db = try Syncbase.instance.database(name)
      if try !db.exists() {
        print("Db doesn't exist, creating it")
        try db.create(nil)
        reloadData()
      } else {
        toast("A database already exists with that name")
      }
    } catch (let e) {
      toast("Can't create database: \(e)")
    }
  }

  func toast(msg: String) {
    print(msg)
    let ac = UIAlertController(title: "Error", message: msg, preferredStyle: .Alert)
    ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
    presentViewController(ac, animated: true, completion: nil)
  }
}

extension DatabasesDemo: UITableViewDelegate {

}

extension DatabasesDemo: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return databases.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let kReuseIdentifier = "DatabaseIdCell"
    let cell = tableView.dequeueReusableCellWithIdentifier(kReuseIdentifier) ??
    UITableViewCell(style: .Subtitle, reuseIdentifier: kReuseIdentifier)
    let dbId = databases[indexPath.row]
    cell.textLabel?.text = dbId.name
    cell.detailTextLabel?.text = dbId.blessing
    return cell
  }
}