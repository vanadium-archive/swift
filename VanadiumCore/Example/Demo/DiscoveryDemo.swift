// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import VanadiumCore

struct DiscoveryDemoDescription: DemoDescription {
  let segue: String = "ConsoleDemo"

  var description: String {
    return "Discovery Demo"
  }

  var instance: Demo {
    return DiscoveryDemo()
  }
}

struct DiscoveryDemo: Demo {
  var ctx: Context!
  var d: Discovery!

  mutating func start() {
    try! V23.configure(VLoggingOptions())
    ctx = V23.instance.context
    d = Discovery(context: ctx)
    let ad = Advertisement(adId: nil,
      interfaceName: "v.io/v23/services/vtrace.Store",
      addresses: ["/ns.dev.v.io:8101/blah/blah"],
      attributes: ["resolution": "1024x768"],
      attachments: nil)
    do {
      try d.advertise(ad, visibility: nil) { _ in
        log.info("Done advertising")
      }

      try d.scan("") { (update, isScanDone) in
        if isScanDone {
          log.info("Scan is done")
        } else {
          log.info("Got update: \(update)")
        }
      }
    } catch (let e) {
      log.warning("Unable to start demo: \(e)")
    }
//    v23_cb_demo_init()
//    v23_cb_demo_advertising_add_services()
//    v23_cb_demo_discovery_start { cjson in
//      let json = NSData(bytes: cjson, length: Int(strlen(cjson)))
//      let data = try! NSJSONSerialization.JSONObjectWithData(json, options: []) as! NSDictionary
//      print("Discovered: \(data)")
//    }
  }

  mutating func stop() {
//    v23_cb_demo_advertising_remove_services()
//    v23_cb_demo_discovery_stop()
//    v23_cb_demo_deinit()
    do { try ctx.cancel() } catch { }
  }
}
