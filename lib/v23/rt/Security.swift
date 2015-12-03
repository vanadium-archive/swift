// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import Security

public typealias Hash = String
public struct PublicKey {
  let hash:Hash
  let derPkix:[UInt8]
}

public struct Caveat {
  let id:[UInt8] // likely a UUID
  let paramVom:[UInt8] // // VOM-encoded bytes of the parameters to be provided to the validation function.
}

public struct Signature {
  let purpose:[UInt8]
  let hash:Hash
  let r:[UInt8]
  let s:[UInt8]
}

public struct Certificate {
  let extensionStr:String // Human-readable string extension bound to PublicKey
  let publicKey:[UInt8] // DER-encoded PKIX public key
  let caveats:[Caveat]
  let signature:Signature
}

public struct Blessings {
  let chains:[[Certificate]]
  let publicKey:PublicKey
  let digests:[[UInt8]]
  let uniqueId:[UInt8]
}
