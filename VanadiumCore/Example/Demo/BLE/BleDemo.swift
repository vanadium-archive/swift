// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit
import VanadiumCore

struct BleDiscoveryUtilityDemoDescription: DemoDescription {
  let segue: String = "BleDiscoveryUtilityDemo"

  var description: String {
    return "BLE Discovery General Utility"
  }

  var instance: Demo {
    return BleUtilityDemo()
  }
}

struct BleAdvertiseUtilityDemoDescription: DemoDescription {
  let segue: String = "BleAdvertiseUtilityDemo"

  var description: String {
    return "BLE Advertise General Utility"
  }

  var instance: Demo {
    return BleUtilityDemo()
  }
}

struct BleUtilityDemo: Demo {
  mutating func start() { }
  mutating func stop() { }
}
