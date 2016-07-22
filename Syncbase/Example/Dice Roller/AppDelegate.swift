// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import GoogleSignIn
import Syncbase
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?

  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    AppDelegate.configureGoogleSignIn()
    AppDelegate.configureSyncbase()
    return true
  }

  static func configureGoogleSignIn() {
    let infoPath = NSBundle.mainBundle().pathForResource("GoogleService-Info", ofType: "plist")!
    let info = NSDictionary(contentsOfFile: infoPath)!
    let googleSignInClientID = info["CLIENT_ID"] as! String
    GIDSignIn.sharedInstance().clientID = googleSignInClientID
  }

  static func configureSyncbase() {
    try! Syncbase.configure(
      // Cloud & mount-point.
      cloudName: "/(dev.v.io:r:vprod:service:mounttabled)@ns.dev.v.io:8101/sb/syncbased-df0f9bfa",
      cloudBlessing: "dev.v.io:r:allocator:us:x:syncbased-df0f9bfa",
      mountPoints: ["/ns.dev.v.io:8101/tmp/ios/diceroller/users/"])
  }

  func application(app: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool {
    return GIDSignIn.sharedInstance().handleURL(url,
      sourceApplication: options[UIApplicationOpenURLOptionsSourceApplicationKey] as! String,
      annotation: options[UIApplicationOpenURLOptionsAnnotationKey])
  }

  func applicationWillTerminate(application: UIApplication) {
    Syncbase.shutdown()
  }
}
