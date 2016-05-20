// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import UIKit
import SyncbaseCore

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
  @IBOutlet weak var doneButton: UIBarButtonItem!
  @IBOutlet weak var logoImage: UIImageView!
  var dismissOnSignIn = false

  override func viewDidLoad() {
    super.viewDidLoad()
    statusLabel.text = ""
    configureGoogle()
  }

  @IBAction func cancelPressed(sender: UIBarButtonItem) {
    dismissViewControllerAnimated(true) { }
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
    user.authentication.getTokensWithHandler { [weak self](auth, error) in
      guard error == nil else {
        debugPrint("Error getting auth token: \(error)")
        self?.statusLabel.text = "Error getting auth token: \(error)"
        return
      }
      self?.didSignIn(user, auth: auth)
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
    Syncbase.instance.login(GoogleCredentials(token: oauthToken)) { [weak self] err in
      guard err == nil else {
        self?.animateInResult("Error: \(err!)")
        return
      }
      // Success
      if self?.dismissOnSignIn ?? false {
        self?.dismissViewControllerAnimated(true) { }
      } else {
        let blessings: String = Syncbase.instance.loggedInBlessingDebugDescription
        self?.animateInResult(blessings)
      }
    }
  }

  func animateInResult(text: String) {
    debugPrint(text)
    UIView.animateWithDuration(0.35,
      animations: { [weak self] in
        self?.statusLabel.alpha = 0
        self?.logoImage.alpha = 0
      },
      completion: { _ in
        self.statusLabel.text = text
        UIView.animateWithDuration(0.35) { [weak self] in
          self?.statusLabel.alpha = 1
        }
    })
  }
}
