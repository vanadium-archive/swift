// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import UIKit
import CoreBluetooth

extension CBUUID {
  static func random16() -> CBUUID {
    var intBytes = random() % Int(Int16.max)
    let data = NSData(bytes: &intBytes, length: sizeof(Int16))
    return CBUUID(data: data)
  }
}

class AdvertiseViewController: UIViewController {
  @IBOutlet weak var advertisingSwitch: UISwitch!
  @IBOutlet weak var advertisingSpinner: UIActivityIndicatorView!
  @IBOutlet weak var localNameField: UITextField!
  @IBOutlet weak var serviceUUIDsTableView: UITableView!
  @IBOutlet weak var backgroundAuthStatusLabel: UILabel!
  @IBOutlet weak var bleStatusLabel: UILabel!

  var serviceUUIDs: [CBUUID] = []
  var peripheralManager: CBPeripheralManager!
  var state = State.NotAdvertising
  var connectionLatency = CBPeripheralManagerConnectionLatency.Medium
  var subscribers: Set<CBCentral> = []
  var isAdOnlyServices = true
  let kObjectNameUUID = CBUUID(string: "2ABE")

  enum State {
    case NotAdvertising
    case AdvertisingStarting
    case Advertising
  }

  override func viewDidLoad() {
    serviceUUIDsTableView.delegate = self
    serviceUUIDsTableView.dataSource = self
    serviceUUIDsTableView.allowsMultipleSelectionDuringEditing = false
    peripheralManager = CBPeripheralManager(delegate: self,
      queue: dispatch_get_main_queue(),
      options: [CBCentralManagerOptionShowPowerAlertKey: true])
    switch CBPeripheralManager.authorizationStatus() {
    case .NotDetermined:
      backgroundAuthStatusLabel.text = "Not determined"
    case .Restricted:
      backgroundAuthStatusLabel.text = "Restricted"
    case .Denied:
      backgroundAuthStatusLabel.text = "Denied"
    case .Authorized:
      backgroundAuthStatusLabel.text = "Authorized"
    }
  }

  func startAdvertising() {
    advertisingSwitch.on = true
    state = State.AdvertisingStarting
    advertisingSpinner.startAnimating()
    var ad: [String: AnyObject] = [:]
    if let text = localNameField.text where !text.isEmpty {
      ad[CBAdvertisementDataLocalNameKey] = localNameField.text!
    }
    if !serviceUUIDs.isEmpty {
      ad[CBAdvertisementDataServiceUUIDsKey] = serviceUUIDs
    }
    NSLog("Starting advertising")
    peripheralManager.removeAllServices()
    if !isAdOnlyServices {
      for uuid in serviceUUIDs {
        let service = CBMutableService(type: uuid, primary: true)
        service.characteristics = [CBMutableCharacteristic.init(
          type: kObjectNameUUID,
          properties: .Read,
          value: nil, // not cached, read on demand
          permissions: .Readable)]
        peripheralManager.addService(service)
      }
    }
    peripheralManager.startAdvertising(ad)
  }

  func stopAdvertising() {
    NSLog("Stopping advertising")
    advertisingSwitch.on = false
    state = State.NotAdvertising
    advertisingSpinner.stopAnimating()
    peripheralManager.stopAdvertising()
    peripheralManager.removeAllServices()
  }

  @IBAction func toggleAdvertising(sender: UISwitch!) {
    if sender.on {
      startAdvertising()
    } else {
      stopAdvertising()
    }
  }

  @IBAction func serviceTypeChanged(sender: UISegmentedControl!) {
    isAdOnlyServices = sender.selectedSegmentIndex == 0
    stopAdvertising()
  }

  @IBAction func addUuid(sender: UIButton!) {
    var uuid: CBUUID!
    if sender.titleLabel!.text!.containsString("128") {
      // UUID4
      uuid = CBUUID(NSUUID: NSUUID())
    } else {
      uuid = CBUUID.random16()
    }
    serviceUUIDs.append(uuid)
    serviceUUIDsTableView.reloadData()
    stopAdvertising()
  }

  @IBAction func localNameChanged(sender: UITextField!) {
    sender.resignFirstResponder()
    stopAdvertising()
  }

  @IBAction func selectedConnectionLatency(sender: UISegmentedControl!) {
    switch sender.selectedSegmentIndex {
    case 0: connectionLatency = .Low
    case 1: connectionLatency = .Medium
    case 2: connectionLatency = .High
    default: return
    }
    for central in subscribers {
      peripheralManager.setDesiredConnectionLatency(connectionLatency, forCentral: central)
    }
  }
}

extension AdvertiseViewController: CBPeripheralManagerDelegate {
  func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .PoweredOff:
      bleStatusLabel.text = "Powered Off"
      stopAdvertising()
    case .PoweredOn:
      bleStatusLabel.text = "Powered On"
      switch state {
      case .Advertising: startAdvertising()
      case .AdvertisingStarting: startAdvertising()
      case .NotAdvertising: break
      }
    case .Resetting:
      bleStatusLabel.text = "Resetting"
      stopAdvertising()
    case .Unauthorized:
      bleStatusLabel.text = "Unauthorized"
      stopAdvertising()
    case .Unknown:
      bleStatusLabel.text = "Unknown"
      stopAdvertising()
    case .Unsupported:
      bleStatusLabel.text = "Not supported"
      showAlert("Bluetooth", message: "Not supported on simulator")
      stopAdvertising()
    }
  }

  func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
    NSLog("didStartAdvertising: \(peripheral) - error \(error)")
    if let e = error {
      stopAdvertising()
      showAlert("Couldn't start advertising", message: "\(e)")
    }
    advertisingSpinner.stopAnimating()
  }

  func peripheralManager(peripheral: CBPeripheralManager, didAddService service: CBService, error: NSError?) {
    NSLog("didAddService: \(service) - \(error)")
    if let e = error {
      showAlert("Unable to add service", message: "\(e)")
    }
  }

  func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
    NSLog("central \(central) didSubscribeToCharacteristic")
    if !subscribers.contains(central) {
      peripheral.setDesiredConnectionLatency(connectionLatency, forCentral: central)
      subscribers.insert(central)
    }
  }

  func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
    NSLog("central \(central) didUnubscribeToCharacteristic")
    subscribers.remove(central)
  }

  func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
    NSLog("Received read request: \(request)")
    peripheral.setDesiredConnectionLatency(connectionLatency, forCentral: request.central)
    guard request.characteristic.UUID == kObjectNameUUID else {
      NSLog("Ignoring invalid characteristic")
      return
    }
    let data = "hello world".dataUsingEncoding(NSUTF8StringEncoding)!
    guard request.offset <= data.length else {
      peripheral.respondToRequest(request, withResult: CBATTError.InvalidOffset)
      return
    }
    request.value = data.subdataWithRange(NSMakeRange(request.offset, data.length - request.offset))
    peripheral.respondToRequest(request, withResult: CBATTError.Success)
  }
}

extension AdvertiseViewController: UITableViewDataSource {
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section > 0 { return 0 }
    return serviceUUIDs.count
  }

  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let kReuseIdentifier = "ServiceUUID"
    let cell = tableView.dequeueReusableCellWithIdentifier(kReuseIdentifier) ??
    UITableViewCell(style: UITableViewCellStyle.Subtitle, reuseIdentifier: kReuseIdentifier)
    guard indexPath.row < serviceUUIDs.count else {
      cell.detailTextLabel?.text = "Error at \(indexPath.section), \(indexPath.row)"
      cell.detailTextLabel?.text = ""
      return cell
    }
    let uuid = serviceUUIDs[indexPath.row]
    cell.textLabel?.text = "\(uuid.UUIDString)"
    return cell
  }
}

extension AdvertiseViewController: UITableViewDelegate {
  // Support removing service UUIDs by swipe
  func tableView(tableView: UITableView,
    commitEditingStyle editingStyle: UITableViewCellEditingStyle,
    forRowAtIndexPath indexPath: NSIndexPath) {
      guard editingStyle == .Delete else {
        return
      }
      serviceUUIDs.removeAtIndex(indexPath.row)
      serviceUUIDsTableView.reloadData()
      stopAdvertising()
  }
}

extension AdvertiseViewController {
  func showAlert(title: String, message: String) {
    let ac = UIAlertController.init(title: title, message: message, preferredStyle: .Alert)
    let ok = UIAlertAction(title: "Ok", style: .Default, handler: nil)
    ac.addAction(ok)
    self.presentViewController(ac, animated: true, completion: nil)
  }
}
