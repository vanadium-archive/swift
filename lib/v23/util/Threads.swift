// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

internal func dispatch_maybe_async(queue:dispatch_queue_t?, block:dispatch_block_t) {
  guard let queue = queue else {
    block()
    return
  }
  if (isCurrentQueue(queue)) {
    block()
  } else {
    dispatch_async(queue, block)
  }
}

internal func dispatch_maybe_sync(queue:dispatch_queue_t?, block:dispatch_block_t) {
  guard let queue = queue else {
    block()
    return
  }
  if (isCurrentQueue(queue)) {
    block()
  } else {
    dispatch_sync(queue, block)
  }
}

internal func isCurrentQueue(queue:dispatch_queue_t) -> Bool {
  let current = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)
  let queueName = dispatch_queue_get_label(queue)
  return current != nil && queueName != nil && strcmp(current, queueName) == 0
}

internal func dispatch_after_delay(delay:NSTimeInterval, queue:dispatch_queue_t, block:dispatch_block_t) {
  dispatch_after(dispatch_time_t.fromNSTimeInterval(delay), queue, block)
}

internal func RunOnMain(block:dispatch_block_t) {
  dispatch_maybe_async(dispatch_get_main_queue(), block: block)
}

internal func RunInBackground(block:dispatch_block_t) {
  dispatch_maybe_async(dispatch_get_bg_queue(), block: block)
}

internal func dispatch_get_bg_queue() -> dispatch_queue_t {
  return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
}

extension dispatch_time_t {
  static func fromNSTimeInterval(t:NSTimeInterval) -> dispatch_time_t {
    return dispatch_time(DISPATCH_TIME_NOW, Int64(t * Double(NSEC_PER_SEC)))
  }
}