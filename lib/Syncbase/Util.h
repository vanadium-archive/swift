// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#import <Foundation/Foundation.h>

@interface SyncbaseUtil : NSObject
+ (BOOL) catchObjcException:(void (^ _Nonnull)())block error:(NSError * _Nullable * _Nonnull)error;
@end