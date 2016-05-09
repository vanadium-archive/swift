// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import UIKit
import CoreBluetooth

@objc class DeviceInfoViewController: UITableViewController {
  // Set by the previous view controller on segue
  var device: Peripheral!
  // Initialized at load, when we know the device has been bound
  var basicInfo: [(String, String)] = []
  var serviceInfo: [(String, String)] = []
  var overflowServiceInfo: [(String, String)] = []
  var solicitedServiceInfo: [(String, String)] = []

  override func viewDidLoad() {
    super.viewDidLoad()
    basicInfo = [
      ("Peripheral Name", device.peripheral.name ?? ""),
      ("Peripheral UUID", device.peripheral.identifier.UUIDString),
      ("Local Name", device.localName ?? ""),
      ("RSSI", "\(device.rssi)"),
      ("Connectable", device.isConnectable.map { "\($0)" } ?? "?"),
      ("TX Level", device.txPower.map { "\($0)" } ?? ""),
      ("Manufacturer data", device.manufacturerData?.toString() ?? ""),
    ]
    serviceInfo = makeServiceInfoData("Advertised service", uuids: device.serviceUUIDs ?? [])
    overflowServiceInfo = makeServiceInfoData("Overflow service", uuids: device.overflowServiceUUIDs ?? [])
    solicitedServiceInfo = makeServiceInfoData("Solicited service", uuids: device.solicitedServiceUUIDs ?? [])
  }

  func makeServiceInfoData(name: String, uuids: [CBUUID]) -> [(String, String)] {
    return uuids.map { uuid in
      return (name, uuid.UUIDString)
    }
  }

  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 4
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return basicInfo.count
    case 1: return serviceInfo.count
    case 2: return overflowServiceInfo.count
    case 3: return solicitedServiceInfo.count
    default: return 0
    }
  }

  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let kReuseIdentifier = "DeviceInfo"
    let cell = tableView.dequeueReusableCellWithIdentifier(kReuseIdentifier) ??
    UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kReuseIdentifier)
    guard let row = dataForIndexPath(indexPath) else {
      cell.textLabel?.text = ""
      cell.detailTextLabel?.text = "Error at \(indexPath.section), \(indexPath.row)"
      return cell
    }
    cell.textLabel?.text = row.0
    cell.detailTextLabel?.text = row.1
    cell.textLabel?.numberOfLines = 0
    cell.detailTextLabel?.numberOfLines = 0
    return cell
  }

  func dataForIndexPath(indexPath: NSIndexPath) -> (String, String)? {
    var sectionData: [(String, String)]!
    switch indexPath.section {
    case 0: sectionData = basicInfo
    case 1: sectionData = serviceInfo
    case 2: sectionData = overflowServiceInfo
    case 3: sectionData = solicitedServiceInfo
    default: return nil
    }
    guard indexPath.row < sectionData.count else {
      return nil
    }
    return sectionData[indexPath.row]
  }
}
