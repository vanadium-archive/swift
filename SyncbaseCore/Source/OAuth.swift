// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// The provider of the oauth token, such as Google.
public enum OAuthProvider: String {
  /// Currently, Google is the only supported provider.
  case Google = "google"
}

/// Represents a valid OAuth token obtained from an OAuth provider such as Google.
public protocol OAuthCredentials {
  /// The oauth provider, e.g. OAuthProvider.Google.
  var provider: OAuthProvider { get }
  /// The oauth token just received from the provider.
  var token: String { get }
}

/// Shortcut for OAuthCredentials provided by Google.
public struct GoogleCredentials: OAuthCredentials {
  public let token: String
  public let provider = OAuthProvider.Google

  public init(token: String) {
    self.token = token
  }
}
