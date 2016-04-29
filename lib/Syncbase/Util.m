// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "Util.h"

@implementation SyncbaseUtil

+ (BOOL) catchObjcException:(void (^ _Nonnull)())block error:(NSError * _Nullable * _Nonnull)error {
  @try {
    block();
    return true;
  } @catch (NSException *exception) {
    if (!error) return false;
    *error = [NSError errorWithDomain:@"io.v.Syncbase"
                                 code:-100
                             userInfo:@{@"name": exception.name,
                                        @"reason": exception.reason,
                                        @"userInfo": exception.userInfo}];
    return false;
  }
}

@end