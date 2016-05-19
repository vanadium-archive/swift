// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit

class DemoViewController: UITableViewController {
  let demos: [DemoDescription] = [
    GoogleSignInDemoDescription(),
    DatabasesDemoDescription(),
  ]
  var currentDemo: Demo? = nil
  var currentDemoDescription: DemoDescription? = nil

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return demos.count
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    if indexPath.row >= demos.count {
      return mkErrorCell(indexPath)
    }
    guard let cell = tableView.dequeueReusableCellWithIdentifier("DemoNameCells") else {
      return mkErrorCell(indexPath)
    }
    let demo = demos[indexPath.row]
    cell.textLabel?.text = demo.description
    return cell
  }

  private func mkErrorCell(indexPath: NSIndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: .Default, reuseIdentifier: "error")
    cell.textLabel?.text = "Error for index path \(indexPath)"
    return cell
  }

  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let demo = demos[indexPath.row]
    currentDemo = demo.instance
    currentDemoDescription = demo
    performSegueWithIdentifier(demo.segue, sender: self)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Starts any non-UI demos
    if segue.identifier == "ConsoleDemo" {
      segue.destinationViewController.title = currentDemoDescription?.description
    }
    currentDemo?.start()
  }
}
