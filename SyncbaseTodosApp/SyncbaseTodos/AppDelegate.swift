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
      // TODO(mrschmidt): Remove the ios-specific portion of mountpoint when VOM is implemented.
      mountPoints: ["/ns.dev.v.io:8101/tmp/ios/todos/users/"])
    return true
  }

  func application(app: UIApplication, openURL url: NSURL, options: [String: AnyObject]) -> Bool {
    return GIDSignIn.sharedInstance().handleURL(url,
      sourceApplication: options[UIApplicationOpenURLOptionsSourceApplicationKey] as! String,
      annotation: options[UIApplicationOpenURLOptionsAnnotationKey])
  }

  func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  func applicationDidEnterBackground(application: UIApplication) {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }

  func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive(application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
  }

  func applicationWillTerminate(application: UIApplication) {
    Syncbase.shutdown()
  }
}

