// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import CoreBluetooth

struct Peripheral {
  let peripheral: CBPeripheral
  let adData: [String: AnyObject]
  let rssi: Float

  var serviceUUIDs: [CBUUID]? {
    return adData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
  }

  var overflowServiceUUIDs: [CBUUID]? {
    return adData[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]
  }

  var solicitedServiceUUIDs: [CBUUID]? {
    return adData[CBAdvertisementDataSolicitedServiceUUIDsKey] as? [CBUUID]
  }

  var isConnectable: Bool? {
    return (adData[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
  }

  var txPower: Float? {
    return (adData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.floatValue
  }

  var serviceData: [CBUUID: NSData]? {
    return adData[CBAdvertisementDataServiceDataKey] as? [CBUUID: NSData]
  }

  var manufacturerData: NSData? {
    return adData[CBAdvertisementDataManufacturerDataKey] as? NSData
  }

  var localName: String? {
    return adData[CBAdvertisementDataLocalNameKey] as? String
  }
}
