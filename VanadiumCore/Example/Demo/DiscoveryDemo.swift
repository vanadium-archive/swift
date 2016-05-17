// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import VanadiumCore

struct DiscoveryDemoDescription: DemoDescription {
  let segue: String = "DiscoveryDemo"

  var description: String {
    return "Discovery Demo"
  }

  var instance: Demo {
    return DiscoveryDemo()
  }
}

struct DiscoveryDemo: Demo {
  mutating func start() { }
  mutating func stop() { }
}

class DiscoveryViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var addressLabel: UILabel!
  var advertisements: [Advertisement] = []
  var ctx: Context!
  var d: Discovery!

  override func viewDidLoad() {
    super.viewDidLoad()
    try! V23.configure(VLoggingOptions())
    ctx = V23.instance.context
    d = Discovery(context: ctx)
    advertise()
    scan()
  }

  override func viewWillDisappear(animated: Bool) {
    V23.instance.shutdown()
  }

  func advertise() {
    weak var this = self
    let ad = Advertisement(id: nil,
      interfaceName: "v.io/v23/services/vtrace.Store",
      addresses: ["/ns.dev.v.io:8101/" + NSUUID().UUIDString],
      attributes: ["resolution": "1024x768"],
      attachments: nil)
    do {
      try d.advertise(ad, visibility: nil) { _ in
        log.info("Done advertising")
      }
      this?.addressLabel.text = ad.addresses.first!
    } catch (let e) {
      log.warning("unable to start advertising: \(e)")
      this?.addressLabel.text = "Error: \(e)"
    }
  }

  func scan() {
    weak var this = self
    do {
      try d.scan("") { (update, isScanDone) in
        if isScanDone {
          log.info("Scan is done")
          return
        }
        guard let ad = update else { return }
        log.info("Got update: \(ad)")
        if ad.isLost {
          guard let idx = this?.advertisements.indexOf({ return ad.adId == $0.adId }) else {
            log.warning("Couldn't find advertisement which got lost: \(update)")
            return
          }
          this?.advertisements.removeAtIndex(idx)
        } else {
          this?.advertisements.append(ad.advertisement)
        }
        this?.tableView.reloadData()
      }
    } catch (let e) {
      log.warning("Unable to start scanning: \(e)")
    }
  }
}

extension DiscoveryViewController: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return advertisements.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let kAdReuseIdentifier = "DiscoveryAdCell"
    guard let cell = tableView.dequeueReusableCellWithIdentifier(kAdReuseIdentifier) else {
      return errorCell(indexPath)
    }
    if indexPath.row > advertisements.count {
      return errorCell(indexPath)
    }
    let ad = advertisements[indexPath.row]
    cell.textLabel?.text = ad.adId?.base64EncodedStringWithOptions([]) ?? "<No Ad ID>"
    cell.detailTextLabel?.text = "Addresses: \(ad.addresses.joinWithSeparator(" "))"
    return cell
  }

  func errorCell(indexPath: NSIndexPath) -> UITableViewCell {
    let cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: nil)
    cell.textLabel?.text = "Error at \(indexPath.section), \(indexPath.row)"
    return cell
  }
}
