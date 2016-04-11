// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

public typealias GranterHandle = Int32

public enum RpcClientOption {
  // TODO(zinman): Uncomment when VDL generation is baked in to build process
//  case AllowedServersPolicy(polices:[BlessingPattern])
  case RetryTimeout(timeout:NSTimeInterval)
  case Granter(granter:GranterHandle)
}

public struct Client {
  internal let defaultContext:Context

  internal init(defaultContext:Context) {
    self.defaultContext = defaultContext
  }

  internal func ctxHandle(ctx:Context?) -> ContextHandle {
    return (ctx ?? defaultContext).handle
  }

  public func startCall(ctx:Context?=nil, name:String, method:String, args:[AnyObject]?=nil, returnArgsLength:Int,
                        skipServerAuth:Bool=false) -> Promise<ClientCall> {
    let vomArgs = SwiftByteArrayArray(length: 0, data: nil)

    let (asyncId, handleP) = Client.outstandingHandles.newPromise()
    swift_io_v_impl_google_rpc_ClientImpl_nativeStartCallAsync(
      self.ctxHandle(ctx).goHandle,
      name.toGo(),
      method.toGo(),
      vomArgs,
      skipServerAuth.toGo(),
      asyncId,
      { asyncId, handle in Client.callDidSucceed(asyncId, handle: handle) },
      { asyncId, err in Client.callDidFail(asyncId, err: err) })
    return handleP.then { handle throws in
      return try ClientCall(
        ctxHandle: self.ctxHandle(ctx), callHandle: handle, returnArgsLength: returnArgsLength)
    }
  }

  private static let outstandingHandles = GoPromises<GoClientCallHandle>(timeout: nil)

  public func call(ctx:Context?=nil, name:String, method:String, args:[AnyObject]?=nil, returnArgsLength:Int,
                   skipServerAuth:Bool=false) -> Promise<[AnyObject]?> {
    return startCall(
        ctx,
        name: name,
        method: method,
        args: args,
        returnArgsLength: returnArgsLength,
        skipServerAuth: skipServerAuth)
      .then { call throws -> Promise<[AnyObject]?> in
      return try call.finish()
    }
  }

  internal static func callDidSucceed(asyncId:AsyncCallbackIdentifier, handle:_GoHandle) {
    if let p = Client.outstandingHandles.getAndDeleteRef(asyncId) {
      RunOnMain {
        do {
          try p.resolve(handle)
        } catch let e {
          log.warning("Unable to resolve asyncCall start with handle \(handle): \(e)")
        }
      }
    }
  }

  internal static func callDidFail(asyncId:AsyncCallbackIdentifier, err:SwiftVError) {
    let verr = err.toSwift()
    if let p = Client.outstandingHandles.getAndDeleteRef(asyncId) {
      RunOnMain {
        do {
          try p.reject(verr)
        } catch let e {
          log.warning("Unable to reject asyncCall start with err \(verr): \(e)")
        }
      }
    }
  }

  public func close(ctx:Context?=nil) {
    swift_io_v_impl_google_rpc_ClientImpl_nativeClose(ctxHandle(ctx).goHandle)
  }
}

public enum ClientCallErrors: ErrorType {
  case NilHandlerOnInit
}

public class ClientCall {
  internal let ctxHandle:ContextHandle
  internal let callHandle:GoClientCallHandle
  internal let returnArgsLength:Int

  internal init(ctxHandle:ContextHandle, callHandle:GoClientCallHandle, returnArgsLength:Int) throws {
    self.ctxHandle = ctxHandle
    self.callHandle = callHandle
    self.returnArgsLength = returnArgsLength
    guard callHandle != 0 else {
      throw ClientCallErrors.NilHandlerOnInit
    }
  }

  deinit {
    if callHandle != 0 {
      swift_io_v_impl_google_rpc_ClientCallImpl_nativeFinalize(callHandle)
    }
  }

  public func closeSend() throws {
    try SwiftVError.catchAndThrowError { errPtr in
      swift_io_v_impl_google_rpc_ClientCallImpl_nativeCloseSend(ctxHandle.goHandle, callHandle, errPtr)
    }
  }

  private static let outstandingFinishes = GoPromises<[AnyObject]?>(timeout: nil)
  public func finish() throws -> Promise<[AnyObject]?> {
    let (asyncId, p) = ClientCall.outstandingFinishes.newPromise()
    swift_io_v_impl_google_rpc_ClientCallImpl_nativeFinishAsync(
      ctxHandle.goHandle, callHandle, returnArgsLength.toGo(), asyncId,
      { asyncId, byteArrayArray in ClientCall.finishDidSucceed(asyncId, byteArrayArray: byteArrayArray) },
      { asyncId, err in ClientCall.finishDidFail(asyncId, err: err) })
    return p
  }

  internal static func finishDidSucceed(asyncId:AsyncCallbackIdentifier, byteArrayArray:SwiftByteArrayArray) {
    guard let p = ClientCall.outstandingFinishes.getAndDeleteRef(asyncId) else {
      log.warning("Couldn't find associated promise for finish succeeding on asyncId \(asyncId)")
      // Deallocate associated bytes malloc'd in Go
      byteArrayArray.dealloc()
      return
    }

    // VOM decode in background to let Go get free'd up and to not block main
    RunInBackground {
      // Deallocate associated bytes malloc'd in Go
      defer { byteArrayArray.dealloc() }

      do {
        // TODO Decode via VOM
//        log.debug("Got back byteArrayArray \(byteArrayArray) and data \(byteArrayArray.data)")
//        var i = 0
//        for byteArray in byteArrayArray {
//          log.debug("Byte array \(i): \(byteArray)")
//          i += 1
//        }
      } catch let e {
        do { try p.reject(e) } catch {}
        return
      }

      do {
        try p.resolve(nil)
      } catch let e {
        log.warning("Unable to resolve finish promise: \(e)")
      }
    }
  }

  internal static func finishDidFail(asyncId:AsyncCallbackIdentifier, err:SwiftVError) {
    let verr = err.toSwift()
    if let p = ClientCall.outstandingFinishes.getAndDeleteRef(asyncId) {
      RunOnMain {
        do {
          try p.reject(verr)
        } catch let e {
          log.warning("Unable to reject finish with err \(verr): \(e)")
        }
      }
    }
  }

//  public func remoteBlessings() -> (blessings:[String], cryptoBlessings:[Blessings]) {
//    fatalError("Unimplemented")
//  }
}
