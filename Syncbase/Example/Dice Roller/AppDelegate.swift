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

  static var googleSignInClientID: String {
    let infoPath = NSBundle.mainBundle().pathForResource("GoogleService-Info", ofType: "plist")!
    let info = NSDictionary(contentsOfFile: infoPath)!
    return info["CLIENT_ID"] as! String
  }

  static func configureGoogleSignIn() {
    GIDSignIn.sharedInstance().clientID = AppDelegate.googleSignInClientID
  }

  static func configureSyncbase() {
    try! Syncbase.configure(adminUserId: "zinman@google.com",
      // Craft a blessing prefix using google sign-in and the dev.v.io blessings provider.
      defaultBlessingStringPrefix: "dev.v.io:o:\(AppDelegate.googleSignInClientID):",
      // Cloud mount-point.
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
