// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

let log = Logger()

public struct Logger {
  public func debug(@autoclosure closure: () -> String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    log("DEBUG", str: closure(), functionName: functionName, fileName: fileName, lineNumber: lineNumber)
  }

  public func info(@autoclosure closure: () -> String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    log("INFO", str: closure(), functionName: functionName, fileName: fileName, lineNumber: lineNumber)
  }

  public func warning(@autoclosure closure: () -> String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    log("WARN", str: closure(), functionName: functionName, fileName: fileName, lineNumber: lineNumber)
  }

  public func error(@autoclosure closure: () -> String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    log("ERROR", str: closure(), functionName: functionName, fileName: fileName, lineNumber: lineNumber)
  }

  public func fatal(@autoclosure closure: () -> String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    log("FATAL", str: closure(), functionName: functionName, fileName: fileName, lineNumber: lineNumber)
  }

  private func log(level: String, str: String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    if let threadName = NSThread.currentThread().name where threadName != "" {
      NSLog("[%@] %@:%d (%@) %@", level, (fileName as NSString).lastPathComponent, lineNumber, threadName, str)
    } else {
      NSLog("[%@] %@:%d %@", level, (fileName as NSString).lastPathComponent, lineNumber, str)
    }
  }
}

public enum LogLevel: Int {
  case Info = 0
  case Warning = 1
  case Error = 2
  case Fatal = 3
}
