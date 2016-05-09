// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import "Exceptions.h"

@implementation SBObjcHelpers
+ (BOOL)catchObjcException:(dispatch_block_t _Nonnull)block
                     error:(NSError* _Nullable* _Nonnull)error {
  @try {
    block();
    return TRUE;
  } @catch (NSException* exception) {
    if (!error) return false;
    *error = [NSError errorWithDomain:@"io.v.SyncbaseCore"
                                 code:-100
                             userInfo:@{
                               @"name" : exception.name,
                               @"reason" : exception.reason,
                               @"userInfo" : exception.userInfo
                             }];
    return NO;
  }
}

@end