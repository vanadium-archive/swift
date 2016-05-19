// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation
import CoreGraphics

extension NSNumber {
  /// Returns true if value can be cast to NSNumber or NSNumber?
  static func isNSNumber<V>(value: V) -> Bool {
    // Can't do this:
    // if value is NSNumber {
    // because it will always succeed through type coercion, even if value is an Int.
    // Instead we use the dynamic (runtime) type
    let type = value.dynamicType
    return type is NSNumber.Type || type is NSNumber?.Type
  }

  /// Returns true if target can be set/cast from this NSNumber without precision-loss or type
  /// conversion. For example ```NSNumber.init(bool: true) as Float``` will return a Swift Float of
  /// value 1, where as this function would return false as the types are unrelated -- only
  /// casting as Bool would return true. This function checks for 32/64-bit correctness with types.
  ///
  /// Caveat: Currently this function makes no attempt to determine signed/unsigned correctness of
  /// the underlying data, although this is sometimes knowable with NSNumber.objCType.
  func isTargetCastable<T>(inout target: T?) -> Bool {
    // Allow matching types of this size, and bigger. Signed and unsigned of same size are not allowed.
    // Swift: https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/TheBasics.html
    // C types: https://developer.apple.com/library/ios/documentation/General/Conceptual/CocoaTouch64BitGuide/Major64-BitChanges/Major64-BitChanges.html
    switch CFNumberGetType(self as CFNumberRef) {
      // Obj-C bool is stored as Char, but if it's a @(YES) or @(NO) they are all a shared instance.
    case .CharType where (unsafeAddressOf(self) == unsafeAddressOf(kCFBooleanFalse) ||
      unsafeAddressOf(self) == unsafeAddressOf(kCFBooleanTrue)):
      // We know we have a bool... make sure it's compatible
      let type = target.dynamicType
      guard type == Bool?.self || type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
      // Handle fixed lengths on 32/64 bit
    case .SInt8Type, .CharType:
      let type = target.dynamicType
      guard type == Int?.self || type == UInt?.self ||
      type == Int8?.self || type == Int16?.self || type == Int32?.self || type == Int64?.self ||
      type == UInt8?.self || type == UInt16?.self || type == UInt32?.self || type == UInt64?.self ||
      type == CChar?.self || type == CShort?.self || type == CInt?.self || type == CLong?.self || type == CLongLong?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
    case .SInt16Type, .ShortType:
      let type = target.dynamicType
      guard type == Int?.self || type == UInt?.self ||
      type == Int16?.self || type == Int32?.self || type == Int64?.self ||
      type == UInt16?.self || type == UInt32?.self || type == UInt64?.self ||
      type == CShort?.self || type == CInt?.self || type == CLong?.self || type == CLongLong?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
    case .SInt32Type, .IntType:
      let type = target.dynamicType
      guard type == Int?.self || type == UInt?.self ||
      type == Int32?.self || type == Int64?.self ||
      type == UInt32?.self || type == UInt64?.self ||
      type == CInt?.self || type == CLong?.self || type == CLongLong?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
    case .SInt64Type, .LongLongType:
      let type = target.dynamicType
      guard (type == Int?.self && sizeof(Int) == sizeof(CLongLong)) ||
      (type == UInt?.self && sizeof(UInt) == sizeof(CLongLong)) ||
      type == Int64?.self || type == UInt64?.self ||
      type == CLongLong?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
    case .Float32Type, .FloatType:
      let type = target.dynamicType
      guard type == Float?.self ||
      type == Double?.self ||
      type == Float32?.self ||
      type == Float64?.self ||
      type == CFloat?.self || type == CDouble?.self || type == CGFloat?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
    case .Float64Type, .DoubleType: /* 64-bit IEEE 754 */
      let type = target.dynamicType
      guard type == Double?.self ||
      type == Float64?.self ||
      type == CDouble?.self || type == CGFloat?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }

      // Handle 32/64-bit types
    case .LongType, .NSIntegerType:
      let type = target.dynamicType
      guard type == Int?.self || type == UInt?.self ||
      (type == Int32?.self && sizeof(Int32) == sizeof(NSInteger)) ||
      (type == UInt32?.self && sizeof(UInt32) == sizeof(NSInteger)) ||
      type == Int64?.self || type == UInt64?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self ||
      type == CLong?.self || type == CLongLong?.self else {
        return false
      }
    case .CGFloatType:
      let type = target.dynamicType
      guard (type == Float?.self && sizeof(CGFloat) == sizeof(Float)) ||
      type == Double?.self ||
      (type == Float32?.self && sizeof(CGFloat) == sizeof(Float32)) ||
      type == Float64?.self ||
      type == NSNumber?.self || type == AnyObject?.self || type == NSObject?.self else {
        return false
      }
      // Misc
    case .CFIndexType:
      guard target.dynamicType == CFIndex?.self else {
        return false
      }
    }
    return true
  }
}
