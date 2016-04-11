// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public func configure(loggingOptions:VLoggingOptions?=nil) throws {
  try V23.configure(loggingOptions)
}

public let instance = V23.instance

public class V23 {
  private static var _instance: V23? = nil
  private var rootContext:Context

  /// The singleton instance of V23 that you use to create and configure any clients/servers.
  ///
  /// **Warning:** You must first call configure before you can grab an instance. It will
  /// crash with a fatalError otherwise.
  public static var instance: V23 {
    get {
      if (_instance == nil) {
        fatalError("You must first call V23.configure before you can use an instance")
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
  private init(loggingOptions:VLoggingOptions) throws {
    // We must have all variables initialized before we can throw
    rootContext = Context(handle: ContextHandle(0))

    let appSupportUrl = NSURL(fileURLWithPath:
      NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)[0])
    let v23Url = appSupportUrl.URLByAppendingPathComponent("Vanadium")
    let credentialsPath = v23Url.path!
    log.debug("Using credentials path \(credentialsPath)")
    if !NSFileManager.defaultManager().fileExistsAtPath(credentialsPath) {
      // Create it
      let attrs = [NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication]
      try NSFileManager.defaultManager().createDirectoryAtPath(
        credentialsPath, withIntermediateDirectories: true, attributes: attrs)
    }
    try SwiftVError.catchAndThrowError { errPtr in
      swift_io_v_v23_V_nativeInitGlobal(credentialsPath.toGo(), errPtr)
    }

    try loggingOptions.initGo()
    rootContext = Context(handle: ContextHandle(swift_io_v_impl_google_rt_VRuntimeImpl_nativeInit()))
  }

  deinit {
    swift_io_v_impl_google_rt_VRuntimeImpl_nativeShutdown(rootContext.handle.goHandle)
  }

  /// You must call configure before using Vanadium or grabbing an instance.
  /// This is where you pass any logging options... (TBD)
  ///
  /// **Warning:** You may only call this once. It will otherwise crash with a fatalError.
  ///
  /// :param: loggingOptions Logging options used by the Vandadium internals.
  ///         See documentation on VLoggingOptions for more information
  public class func configure(loggingOptions:VLoggingOptions?=nil) throws {
    if _instance == nil {
      instance = try V23(loggingOptions: loggingOptions ?? VLoggingOptions())
    }
  }

  public var context: Context {
    get {
      return rootContext
    }
  }
}