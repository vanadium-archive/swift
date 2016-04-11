// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

import VanadiumCore

public let instance = Syncbase.instance

public class Syncbase {
  private static var _instance: Syncbase? = nil

  /// The singleton instance of Syncbase. This is the primary class that houses the simplified
  /// API.
  ///
  /// You won't be able to sync with anybody unless you grant yourself a blessing via the authorize
  /// method.
  public static var instance: Syncbase {
    get {
      if (_instance == nil) {
        do {
          _instance = try Syncbase()
        } catch let err {
          VanadiumCore.log.warning("Couldn't instantiate an instance of Syncbase: \(err)")
        }
      }
      return _instance!
    }
    set {
      if (_instance != nil) {
        fatalError("You cannot create another instance of V23")
      }
      _instance = newValue
    }
  }

  /// Private constructor for V23.
  private init() throws {
    try V23.configure()
  }

  deinit {

  }
}
