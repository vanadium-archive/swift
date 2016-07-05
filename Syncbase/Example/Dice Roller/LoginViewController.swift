// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import GoogleSignIn
import Syncbase
import UIKit

class LoginViewController: UIViewController, GIDSignInUIDelegate {
  @IBOutlet weak var signInButton: GIDSignInButton!
  @IBOutlet weak var spinner: UIActivityIndicatorView!

  override func viewDidLoad() {
    super.viewDidLoad()
    GIDSignIn.sharedInstance().delegate = self
    GIDSignIn.sharedInstance().uiDelegate = self
    signInButton.colorScheme = .Light
    spinner.alpha = 0
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
          self.showSignInButton()
          self.showErrorMsg("Unable to login to Syncbase. Try again.")
        }
      }
    }
  }
}