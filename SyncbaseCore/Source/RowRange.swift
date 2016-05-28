// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// RowRange represents all rows with keys in [start, limit).
/// If limit is "", all rows with keys >= start are included.
public protocol RowRange {
  var start: String { get }
  /// If limit is "", all rows with keys >= start are included.
  var limit: String { get }
}

/// RowRangeAll represents all rows.
public struct RowRangeAll: RowRange {
  public var start: String {
    return ""
  }

  public var limit: String {
    return ""
  }
}

/// RowRangeStandard represents all rows with keys in [start, limit).
/// If limit is "", all rows with keys >= start are included.
public struct RowRangeStandard: RowRange {
  public let start: String
  /// If limit is "", all rows with keys >= start are included.
  public let limit: String
}

/// RowRangeSingleRow represents a single row with an explicit key.
public struct RowRangeSingleRow: RowRange {
  public let row: String

  public var start: String {
    return row
  }

  public var limit: String {
    return row + "\0"
  }
}

/// RowRangePrefix represents all rows with keys that have some prefix.
public struct RowRangePrefix: RowRange {
  public let prefix: String

  /// Returns the start of the row range for the given prefix.
  public var start: String {
    return prefix
  }

  public var limit: String {
    var utf8 = Array(prefix.utf8)
    while utf8.count > 0 {
      if utf8.last! == 255 {
        utf8.removeLast() // chop off what would otherwise be a trailing \x00
      } else {
        utf8[utf8.count - 1] += 1 // add 1
        break // no carry
      }
    }
    return String(bytes: utf8, encoding: NSUTF8StringEncoding)!
  }
}
