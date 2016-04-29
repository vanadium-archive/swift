// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public let log = VLogger()

public struct VLogger {
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

  private func log(level:String, str:String, functionName: String = #function, fileName: String = #file, lineNumber: Int = #line) {
    if let threadName = NSThread.currentThread().name where threadName != "" {
      print("[", level, "] ", (fileName as NSString).lastPathComponent, ":", lineNumber, " (", threadName, ") ", str, separator: "")
    } else {
      print("[", level, "] ", (fileName as NSString).lastPathComponent, ":", lineNumber, " ", str, separator: "")
    }
  }
}

public enum VLogLevel: Int {
  case Info = 0
  case Warning = 1
  case Error = 2
  case Fatal = 3
}

public struct VLoggingOptions {
  /// Enable V-leveled logging at the specified level.
  let level: VLogLevel

  /// The syntax of the argument is a comma-separated list of pattern=N,
  /// where pattern is a literal file name (minus the ".go" suffix) or
  /// "glob" pattern and N is a V level. For instance, gopher*=3
  /// sets the V level to 3 in all Go files whose names begin "gopher".
  let moduleSpec: String?

  // We only log to disk on OS X
  #if os(OSX)
  /// If true, logs are written to standard error instead of to files
  let logToStderrOnly: Bool

  /// Log files will be wirtten to this directory instead of the default temp dir
  let logDir: String?
  #endif

  #if os(OSX)
  public init(level:VLogLevel=VLogLevel.Info,
      moduleSpec:String?=nil,
      logToStderrOnly:Bool=true,
      logDir:String?=nil) {
    self.level = level
    self.moduleSpec = moduleSpec
    self.logToStderrOnly = logToStderrOnly
    self.logDir = logDir
    if (self.logToStderrOnly && self.logDir != nil) {
      NSLog("WARNING: logToStderrOnly set to true and logDir was set -- only logging to stderr and not to disk.")
    }
  }
  #else
  public init(level:VLogLevel=VLogLevel.Info, moduleSpec:String?=nil) {
    self.level = level
    self.moduleSpec = moduleSpec
  }
  #endif

  /// Call the init logging function in go -- INTERNAL ONLY
  internal func initGo() throws {
    #if os(OSX)
      try SwiftVError.catchAndThrowError({ errPtr in
        swift_io_v_v23_V_nativeInitLogging(
          logDir?.toGo() ?? nil,
          logToStderrOnly.toGo(),
          level.rawValue.toGo(),
          moduleSpec?.toGo() ?? nil,
          errPtr)
      })
    #else
      try SwiftVError.catchAndThrowError({ errPtr in
        swift_io_v_v23_V_nativeInitLogging(nil, 0, // no logging to disk
            level.rawValue.toGo(), moduleSpec?.toGo() ?? nil, errPtr)
      })
    #endif
  }
}