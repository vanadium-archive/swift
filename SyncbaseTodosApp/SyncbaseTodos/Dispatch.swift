// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// Normally this would be a static variable on DispatchHandler but we can't do that for a generic
// type in Swift as of 2.x.
var _dispatchHandlerUniqueCounter: Int32 = 0

/// Struct to hold the callbacks for a Dispatch listener. It is hashable to support adding/removing
/// callbacks -- function pointers are not otherwise equatable in Swift.
class DispatchHandler<Event>: Hashable {
  var onEvents: [Event] -> ()
  let uniqueId = OSAtomicIncrement32(&_dispatchHandlerUniqueCounter)
  var hashValue: Int { return uniqueId.hashValue }

  required init(onEvents: [Event] -> ()) {
    self.onEvents = onEvents
  }
}

func == <Event>(lhs: DispatchHandler<Event>, rhs: DispatchHandler<Event>) -> Bool {
  return lhs.uniqueId == rhs.uniqueId
}

class Dispatch<Event> {
  var queue = dispatch_get_main_queue()
  private var handlers: Set<DispatchHandler<Event>> = []
  private var handlerMu = NSLock()

  func notify(events: [Event]) {
    if events.isEmpty {
      return
    }
    dispatch_async(queue) {
      // Normally having a mutex before doing a callback could result in a deadlock should the
      // callback end up calling functions that attempt to acquire the mutex like watch or unwatch.
      // However, we know in this very simple program that is never the case, and thus it is safe.
      self.handlerMu.lock()
      for handler in self.handlers {
        handler.onEvents(events)
      }
      self.handlerMu.unlock()
    }
  }

  func watch(eventHandler: DispatchHandler<Event>) {
    self.handlerMu.lock()
    handlers.insert(eventHandler)
    self.handlerMu.unlock()
  }

  func unwatch(eventHandler: DispatchHandler<Event>) {
    self.handlerMu.lock()
    handlers.remove(eventHandler)
    self.handlerMu.unlock()
  }
}
