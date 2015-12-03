//
//  Strings.swift
//  v23
//
//  Created by Aaron Zinman on 12/1/15.
//  Copyright © 2015 Google Inc. All rights reserved.
//

import Foundation

internal extension String {
  internal static func fromCStringNoCopy(ptr:UnsafeMutablePointer<Int8>, freeWhenDone:Bool) -> String? {
    return String.init(bytesNoCopy: ptr, length: Int(strlen(ptr)),
      encoding: NSUTF8StringEncoding, freeWhenDone: true)
  }
}