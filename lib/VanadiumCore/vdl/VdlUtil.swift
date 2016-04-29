// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

extension String {
  public var description: String { return self }
}

extension Bool : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension UInt8 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension UInt16 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension UInt32 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension UInt64 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension Int8 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension Int16 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension Int32 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}

extension Int64 : CustomDebugStringConvertible {
  public var debugDescription: String { return self.description }
}
