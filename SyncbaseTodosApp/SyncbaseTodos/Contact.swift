// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Contacts
import Foundation
import Syncbase

final class Contact: CustomStringConvertible {
  static let keysToFetch = [
    CNContactFormatter.descriptorForRequiredKeysForStyle(.FullName),
    CNContactEmailAddressesKey,
    CNContactImageDataAvailableKey]

  var name: String?
  var emails: [String]?
  var imageURL: NSURL?
  var user: User?

  init(name: String? = nil, emails: [String]? = nil, imageURL: NSURL? = nil, user: User? = nil) {
    self.name = name
    self.emails = emails
    self.user = user
    self.imageURL = imageURL
  }

  init (contact: CNContact) {
    name = CNContactFormatter.stringFromContact(contact, style: .FullName)
    // Note there are very rare occasions where an email address may be case-sensitive. You may want
    // to account for this in your app accordingly.
    emails = contact.emailAddresses.map { ($0.value as! String).lowercaseString }
    if contact.imageDataAvailable {
      imageURL = NSURL(string: "contact://image/\(contact.identifier))")
    }
  }

  var description: String {
    if let name = name {
      if let user = user {
        // Distinguish the contact better by providing the advertising alias (email) for context.
        return "\(name) - \(user.alias)"
      }
      return name
    } else if let user = user {
      return user.alias
    } else if let emails = emails where !emails.isEmpty {
      return emails.first!
    } else {
      return ""
    }
  }
}