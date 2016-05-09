// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit
import CoreBluetooth

@objc class DevicesViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  var centralMgr: CBCentralManager!
  var devices: [Peripheral] = []
  var isScanning = false
  var allowDuplicates = true

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.dataSource = self
    centralMgr = CBCentralManager(delegate: self, queue: dispatch_get_main_queue())
    NSLog("viewDidLoad")
  }

  @IBAction func toggledAllowDuplicateFilter(sender: UISwitch) {
    if sender.on != allowDuplicates {
      allowDuplicates = sender.on
      if isScanning {
        stopScan()
        startScan()
      }
    }
  }

  func startScan() {
    if !isScanning && centralMgr.state == .PoweredOn {
      NSLog("Starting scan")
      centralMgr.scanForPeripheralsWithServices(nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: allowDuplicates])
      isScanning = true
    }
  }

  func stopScan() {
    if isScanning {
      NSLog("Stopping scanning")
      centralMgr.stopScan()
      isScanning = false
      devices = []
    }
  }

  override func viewDidAppear(animated: Bool) {
    NSLog("viewDidAppear")
    startScan()
  }

  override func viewWillDisappear(animated: Bool) {
    NSLog("viewWillDisappear")
    stopScan()
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    (segue.destinationViewController as! DeviceInfoViewController).device = devices[(tableView.indexPathForSelectedRow?.row)!]
  }
}

extension DevicesViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(central: CBCentralManager) {
    switch central.state {
    case .PoweredOn:
      print("Did update state: poweredOn")
      print("starting scanning")
      startScan()
    case .PoweredOff:
      print("Did update state: powered off")
      stopScan()
    case .Resetting:
      print("Did update state: resetting")
      stopScan()
    case .Unauthorized:
      print("Did update state: unauthorized")
    case .Unknown:
      print("Did update state: unknown")
    case .Unsupported:
      print("Did update state: unsupported")
    }
  }

  func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String: AnyObject], RSSI: NSNumber) {
    print("Did discover \(peripheral) with ad data \(advertisementData)")
    let p = Peripheral(peripheral: peripheral, adData: advertisementData, rssi: RSSI.floatValue)
    let existingIdx = devices.indexOf { existing -> Bool in
      return existing.peripheral == p.peripheral
    }
    if let i = existingIdx {
      devices[i] = p
    } else {
      devices.append(p)
    }
    devices.sortInPlace { (p1, p2) -> Bool in
      // Only filter on name if they're both defined, otherwise use the UUID
      var p1Str = ""
      var p2Str = ""
      if let p1Name = p1.peripheral.name, p2Name = p2.peripheral.name {
        p1Str = p1Name
        p2Str = p2Name
      } else {
        p1Str = p1.peripheral.identifier.UUIDString
        p2Str = p2.peripheral.identifier.UUIDString
      }
      switch p1Str.compare(p2Str) {
      case .OrderedAscending: return true
      default: return false
      }
    }
    tableView.reloadData()
  }

  func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
    devices = devices.filter({ p -> Bool in
      return p.peripheral != peripheral
    })
    tableView.reloadData()
  }
}

extension DevicesViewController: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section > 0 { return 0 }
    return devices.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let kReuseIdentifier = "Devices"
    let cell = tableView.dequeueReusableCellWithIdentifier(kReuseIdentifier) ??
    UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kReuseIdentifier)
    guard indexPath.row < devices.count else {
      cell.detailTextLabel?.text = "Error at \(indexPath.section), \(indexPath.row)"
      cell.detailTextLabel?.text = ""
      return cell
    }
    let device = devices[indexPath.row]
    cell.textLabel?.text = "\(device.peripheral.name ?? "?")"
    cell.detailTextLabel?.text = "RSSI: \(device.rssi) - Identifier: \(device.peripheral.identifier.UUIDString)"
    return cell
  }
}
