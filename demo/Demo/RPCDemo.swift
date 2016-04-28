// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit
import VanadiumCore

struct RPCDemoDescription: DemoDescription {
  let segue: String = "ConsoleDemo"

  var description: String {
    return "RPC Demo"
  }

  var instance: Demo {
    return RPCDemo()
  }
}

struct RPCDemo: Demo {
  mutating func start() {
    startVanadium()
    testHelloCall()
    testCancel()
  }

  let addr = "/" + "@6@wsh@100.110.93.71:23000@@b6752aa9f33f86b9aecf25ecad73c8a4@l@tutorial@@"
  var instance: V23? = nil

  mutating func startVanadium() {
    do {
      try V23.configure()
      instance = V23.instance
    } catch let e as VError {
      print("Got a verror:", e)
    } catch let e {
      print("Got an exception:", e)
    }
  }

  func testHelloCall() {
    var ctx = instance!.context
    ctx.deadline = NSDate(timeIntervalSinceNow: 1)
    print("Calling startCall")

    do {
      let client = try ctx.client()
      client.call(name: addr, method: "Get", args: nil, returnArgsLength: 1, skipServerAuth: true)
        .onResolve { result -> () in
          print("Finished with \(result)")
      }
        .onReject { err -> () in
          print("Errored with \(err)")
      }
    } catch let e as VError {
      print("Got a verror:", e)
    } catch let e {
      print("Got an exception:", e)
    }
  }

  func testCancel() {
    var ctx = instance!.context
    ctx.isCancellable = true
    print("Calling startCall")

    do {
      let client = try ctx.client()
      client.call(name: addr, method: "Get", args: nil, returnArgsLength: 1, skipServerAuth: true)
        .onResolve { result -> () in
          print("Call shouldnt have finished with \(result)")
      }
        .onReject { err -> () in
          print("Call errored with \(err)")
      }
      try ctx.cancel()
        .onResolve {
          print("Cancelled correctly")
      }
        .onReject { err -> () in
          print("Cancel errored with \(err)")
      }
    } catch let e as VError {
      print("Got an unexpected verror:", e)
    } catch let e {
      print("Got an unexpected exception:", e)
    }
  }
}
