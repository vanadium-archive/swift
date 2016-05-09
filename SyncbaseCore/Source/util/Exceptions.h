// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

@interface SBObjcHelpers : NSObject
+ (BOOL)catchObjcException:(dispatch_block_t _Nonnull)block
                     error:(NSError* _Nullable* _Nonnull)error;
@end
