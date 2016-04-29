// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit
import Syncbase
import VanadiumCore

struct GoogleSignInDemoDescription: DemoDescription {
  let segue: String = "GoogleSignInDemo"

  var description: String {
    return "Google Sign-In"
  }

  var instance: Demo {
    return GoogleSignInDemo()
  }
}

@objc class GoogleSignInDemo: UIViewController, Demo, GIDSignInDelegate, GIDSignInUIDelegate {
  @IBOutlet weak var signInButton: GIDSignInButton!
  @IBOutlet weak var statusLabel: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()
    statusLabel.text = ""
    configureGoogle()
  }

  func start() {
    // We have to configureGoogle() on viewDidLoad as the Google Sign In's delegates (self) are
    // not fully initialized at this point. This start call is more useful for non-UI-based demos.
  }

  func configureGoogle() {
    // Pull client_id out of the GoogleService-Info plist
    let plistUrl = NSBundle.mainBundle().URLForResource("GoogleService-Info", withExtension: "plist")!
    let servicePlist = NSDictionary(contentsOfURL: plistUrl)!
    let clientId = servicePlist["CLIENT_ID"] as! String
    // Initialize sign-in
    GIDSignIn.sharedInstance().clientID = clientId
    GIDSignIn.sharedInstance().delegate = self
    GIDSignIn.sharedInstance().uiDelegate = self
    // Style
    signInButton.style = .Wide
  }

  func signIn(signIn: GIDSignIn!, presentViewController viewController: UIViewController!) {
    self.presentViewController(viewController, animated: true) {
      debugPrint("Presented google sign in")
    }
  }

  func signIn(signIn: GIDSignIn!, dismissViewController viewController: UIViewController!) {
    self.dismissViewControllerAnimated(true) {
      debugPrint("Dismissed sign on")
    }
  }

  func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
    // Handle errors
    guard error == nil else {
      debugPrint("Error signing in: \(error)")
      statusLabel.text = "Error signing in: \(error)"
      return
    }
    guard user != nil else {
      debugPrint("Error signing in: couldn't get user object")
      statusLabel.text = "Error signing in: couldn't get user object"
      return
    }
    // Get or refresh oauth access token
    weak var this = self
    user.authentication.getTokensWithHandler { (auth, error) in
      guard error == nil else {
        debugPrint("Error getting auth token: \(error)")
        this?.statusLabel.text = "Error getting auth token: \(error)"
        return
      }
      this?.didSignIn(user, auth: auth)
    }
  }

  func didSignIn(user: GIDGoogleUser, auth: GIDAuthentication) {
    signInButton.hidden = true

    let oauthToken = auth.accessToken
    let userId = user.userID
    let userEmail = user.profile.email

    debugPrint("Signed in \(userEmail) (\(userId)) with oauth token \(oauthToken)")
    statusLabel.text = "Signed in \(userEmail)... getting blessing"
    getBlessing(oauthToken)
  }

  func getBlessing(oauthToken: String) {
    weak var this = self
    let credentials = GoogleCredentials(oauthToken: oauthToken)
    credentials.authorize()
      .onReject { err in
        debugPrint("Unable to get blessing: \(err)")
        this?.statusLabel.text = "Unable to get blessing: \(err)"
    }
      .onResolve { _ in
        let blessings: String! = try? Principal.blessingsDebugString() ?? "<error>"
        debugPrint("Got blessings \(blessings)")
        this?.statusLabel.text = "Got blessing: \(blessings)"
    }
  }
}
