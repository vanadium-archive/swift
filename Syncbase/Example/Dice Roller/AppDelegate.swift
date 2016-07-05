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
    // Configure Google Sign-In
    let infoPath = NSBundle.mainBundle().pathForResource("GoogleService-Info", ofType: "plist")!
    let info = NSDictionary(contentsOfFile: infoPath)!
    let clientID = info["CLIENT_ID"] as! String
    GIDSignIn.sharedInstance().clientID = clientID

    // Configure Syncbase
    try! Syncbase.configure(adminUserId: "zinman@google.com",
      // Craft a blessing prefix using google sign-in and the dev.v.io blessings provider.
      defaultBlessingStringPrefix: "dev.v.io:o:\(clientID):",
      // Cloud mount-point.
      // TODO(zinman): Determine if this is correct.
      mountPoints: ["/ns.dev.v.io:8101/tmp/ios/diceroller/users/"])
    return true
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
