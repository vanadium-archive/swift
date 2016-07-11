// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import GoogleSignIn
import Syncbase
import UIKit

class LoginViewController: UIViewController, GIDSignInUIDelegate {
  @IBOutlet weak var signInButton: GIDSignInButton!
  @IBOutlet weak var spinner: UIActivityIndicatorView!
  var doLogout: Bool = false

  override func viewDidLoad() {
    super.viewDidLoad()
    GIDSignIn.sharedInstance().delegate = self
    GIDSignIn.sharedInstance().uiDelegate = self
    signInButton.colorScheme = .Light
    spinner.alpha = 0
    signInButton.alpha = 0

    if doLogout {
      // Coming back from the game picker -- log out as the current user and reset the world.
      logout()
    } else {
      // Normal case.
      attemptAutomaticLogin()
    }
  }

  func logout() {
    doLogout = false
    showSpinner()
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
      Syncbase.shutdown()
      // Because the user might sign in with a different user, we must shutdown Syncbase and
      // delete it's root directory, otherwise the existing credentials will be invalid.
      // TODO(zinman): Remove this once https://github.com/vanadium/issues/issues/1381 is fixed.
      try! NSFileManager.defaultManager().removeItemAtPath(Syncbase.defaultRootDir)
      AppDelegate.configureSyncbase()
      // This will call back via the delegate below -- it will redirect to didDisconnectForLogout.
      GIDSignIn.sharedInstance().disconnect()
    }
  }

  func attemptAutomaticLogin() {
    // Advance if already logged in or we have exchangable oauth keys.
    do {
      if try Syncbase.isLoggedIn() {
        didSignIn()
        return
      }
    } catch let e {
      print("Syncbase error: \(e) ")
    }
    if GIDSignIn.sharedInstance().hasAuthInKeychain() {
      showSpinner()
      GIDSignIn.sharedInstance().signInSilently()
    } else {
      showSignInButton()
    }
  }

  func didSignIn() {
    spinner.stopAnimating()
    spinner.alpha = 0
    performSegueWithIdentifier("LoggedInSegue", sender: self)
  }

  func showSpinner() {
    signInButton.alpha = 0
    spinner.alpha = 1
    spinner.startAnimating()
  }

  func showSignInButton() {
    spinner.stopAnimating()
    spinner.alpha = 0
    signInButton.alpha = 1
  }

  func showErrorMsg(msg: String) {
    let ac = UIAlertController(title: "Oops!", message: msg, preferredStyle: .Alert)
    ac.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
    presentViewController(ac, animated: true, completion: nil)
  }

  func signIn(signIn: GIDSignIn!, presentViewController viewController: UIViewController!) {
    showSpinner()
    presentViewController(viewController, animated: true, completion: nil)
  }
}

extension LoginViewController: GIDSignInDelegate {
  func signIn(signIn: GIDSignIn!, didSignInForUser user: GIDGoogleUser!, withError error: NSError!) {
    dispatch_async(dispatch_get_main_queue()) {
      guard error == nil else {
        self.showSignInButton()
        print("Got error signing into Google: \(error)")
        let errorCode = GIDSignInErrorCode(rawValue: error.code)
        if errorCode != .Canceled && errorCode != .HasNoAuthInKeychain {
          self.showErrorMsg("Couldn't sign in to Google. Try again.")
        }
        return
      }

      Syncbase.login(GoogleOAuthCredentials(token: user.authentication.accessToken)) { err in
        if err == nil {
          self.didSignIn()
        } else {
          print("Unable to login to Syncbase: \(err) ")
          switch err! {
          case .NoAccess:
            // We signed in with a different user -- our credentials are now invalid. We must
            // delete the Syncbase database and retry.
            self.logout()
          default:
            // Delete the credentials so the user has the chance to sign-in again.
            GIDSignIn.sharedInstance().disconnect()
          }
          self.showSignInButton()
          self.showErrorMsg("Unable to login to Syncbase. Try again.")
        }
      }
    }
  }

  func signIn(signIn: GIDSignIn!, didDisconnectWithUser user: GIDGoogleUser!, withError error: NSError!) {
    dispatch_async(dispatch_get_main_queue()) {
      self.showSignInButton()
      if error != nil {
        print("Couldn't logout: \(error)")
        self.showErrorMsg("Unable to logout of Syncbase. Try again.")
      }
    }
  }
}