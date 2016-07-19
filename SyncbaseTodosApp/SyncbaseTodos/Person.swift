// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

final class Person: Jsonable {
  var name: String = ""
  var imageRef: String = ""
  var email: String = ""

  init(name: String, imageRef: String, email: String) {
    self.name = name
    self.imageRef = imageRef
    self.email = email
  }

  func toJsonable() -> [String: AnyObject] {
    return ["name": name, "imageRef": imageRef, "email": email]
  }

  static func fromJsonable(data: [String: AnyObject]) -> Person? {
    guard let name = data["name"] as? String,
      imageRef = data["imageRef"] as? String,
      email = data["email"] as? String else {
        return nil
    }
    return Person(name: name, imageRef: imageRef, email: email)
  }
}