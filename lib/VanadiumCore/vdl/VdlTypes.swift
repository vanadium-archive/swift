// Copyright 2015 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

// Define protocols

public protocol VdlTypeProtocol {
  static var vdlTypeName: String { get }
  // TODO(zinman): vdlType
//  static var vdlType: VdlType { get }
}

// TODO(zinman) Re-implement hashable once vdlType is implemented with unique
public struct VdlTypeObject /*: Hashable*/ {
  let type:VdlType?

  public static var vdlTypeName: String {
    return "vdl.TypeObject"
  }

//  public var hashValue: Int {
//    return type?.hashValue ?? 0
//  }

  public var description: String {
    return "[VdlTypeObject type=\(type)]"
  }

  public var debugDescription: String {
    return description
  }
}

//public func ==(lhs: VdlTypeObject, rhs: VdlTypeObject) -> Bool {
//  return lhs.type == rhs.type
//}

// These will later help with VOM reflection once further flushed out
public protocol VdlUnion : VdlTypeProtocol {
  var vdlName: String { get }
}

public protocol VdlStruct : VdlTypeProtocol{ }

public protocol VdlPrimitive : VdlTypeProtocol, RawRepresentable { }

extension VdlPrimitive {
  public var description: String {
    return "\(self.rawValue)"
  }
}

public protocol VdlEnum : Hashable, VdlTypeProtocol {
  var vdlName: String { get }
}

public enum VdlTypeKind {
  // Variant kinds
  case Any, // any type
  Optional, // value might not exist
  // Scalar kinds
  Bool,       // boolean
  Byte,      // 8 bit unsigned integer
  Uint16,     // 16 bit unsigned integer
  Uint32,     // 32 bit unsigned integer
  Uint64,     // 64 bit unsigned integer
  Int8,       // 8 bit signed integer
  Int16,      // 16 bit signed integer
  Int32,      // 32 bit signed integer
  Int64,      // 64 bit signed integer
  Float32,    // 32 bit IEEE 754 floating point
  Float64,    // 64 bit IEEE 754 floating point
  String,     // unicode string (encoded as UTF-8 in memory)
  Enum,       // one of a set of labels
  TypeObject, // type represented as a value
  // Composite kinds
  Array,  // fixed-length ordered sequence of elements
  List,   // variable-length ordered sequence of elements
  Set,    // unordered collection of distinct keys
  Map,    // unordered association between distinct keys and values
  Struct, // conjunction of an ordered sequence of (name,type) fields
  Union,  // disjunction of an ordered sequence of (name,type) fields

  // Internal kinds; they never appear in a *Type returned to the user.
  internalNamed // placeholder for named types while they're being built.
}

// We have Bol, Set and String already in our enum which overrides the Swift versions.
// Typealias the Swift structs to overcome this issue.
public typealias SwiftBool = Bool
public typealias SwiftString = String
public typealias SwiftVdlSet = Set<VdlTypeKind>

//: The code below is starter code for vdlType. Note that we can't actually use an enum here
/// because we need to be able to support cyclic types that can refer to themselves (not just
/// another node of the same type like a LinkedList which indrect enums support), but two types that
/// refer to each other. The issue is that enums are immutable structures, so temporary declarations
/// aren't possible.

/// unique type is represented by exactly one VdlType instance, so to test for type
/// equality you just compare the VdlType instances.
///
/// Not all methods apply to all kinds of types.  Restrictions are noted in the
/// documentation for each method.  Calling a method inappropriate to the kind of
/// type causes a run-time panic.
///
/// Cyclic types are supported in VDL; e.g. you can represent a tree via:
///   type Node struct {
///     Val      string
///     Children []Node
///   }
public indirect enum VdlType /* : Hashable, CustomStringConvertible*/ {
  // Field describes a single field in a Struct or Union.
  public struct Field {
    let name:SwiftString
    let type:VdlType
  }

  // Variant kinds
//  case Any(name:SwiftString?, labels:[SwiftString]?, len:Int?, key:VdlType?,
//    elem:VdlType?, fields:[Field]?) // any type
  case Any(name:SwiftString)
  /// value might not exist
  case Optional(name:SwiftString?, elem:VdlType?)
  //// Scalar kinds
  /// boolean
  case Bool(name:SwiftString?)
  /// 8 bit unsigned integer
  case Byte(name:SwiftString?)
  /// 16 bit unsigned integer
  case Uint16(name:SwiftString?)
  /// 32 bit unsigned integer
  case Uint32(name:SwiftString?)
  /// 64 bit unsigned integer
  case Uint64(name:SwiftString?)
  /// 8 bit signed integer
  case Int8(name:SwiftString?)
  /// 16 bit signed integer
  case Int16(name:SwiftString?)
  /// 32 bit signed integer
  case Int32(name:SwiftString?)
  /// 64 bit signed integer
  case Int64(name:SwiftString?)
  /// 32 bit IEEE 754 floating point
  case Float32(name:SwiftString?)
  /// 64 bit IEEE 754 floating point
  case Float64(name:SwiftString?)
  /// unicode string (encoded as UTF-8 in memory)
  case String(name:SwiftString?)
  /// one of a set of labels
  case Enum(name:SwiftString?, labels:[SwiftString]?)
  /// type represented as a value
  case TypeObject(name:SwiftString?)
  //// Composite kinds
  /// fixed-length ordered sequence of elements
  case Array(name:SwiftString?, len:Int?, elem:VdlType?)
  /// variable-length ordered sequence of elements
  case List(name:SwiftString?, elem:VdlType?)
  /// unrdered collection of distinct keys
  case Set(name:SwiftString?, key:VdlType?)
  /// unordered association between distinct keys and values
  case Map(name:SwiftString?, key:VdlType?, elem:VdlType?)
  /// conjunction of an ordered sequence of (nametype) fields
  case Struct(name:SwiftString?, fields:[Field]?)
  /// disjunction of an ordered sequence of (nametype) fields
  case Union(name:SwiftString?, fields:[Field]?)

  //// Internal kinds; they never appear in a *Type returned to the user.
  /// placeholder for named types while they're being built.
  case internalNamed(name:SwiftString?, labels:[SwiftString]?, len:Int?, elem:VdlTypeKind?, key:VdlTypeKind?,
    fields:[Field]?) // any type

  // Kind returns the kind of type t.
  var kind:VdlTypeKind {
    switch self {
    case Any: return VdlTypeKind.Any
    case Optional: return VdlTypeKind.Optional
    case Bool: return VdlTypeKind.Bool
    case Byte: return VdlTypeKind.Byte
    case Uint16: return VdlTypeKind.Uint16
    case Uint32: return VdlTypeKind.Uint32
    case Uint64: return VdlTypeKind.Uint64
    case Int8: return VdlTypeKind.Int8
    case Int16: return VdlTypeKind.Int16
    case Int32: return VdlTypeKind.Int32
    case Int64: return VdlTypeKind.Int64
    case Float32: return VdlTypeKind.Float32
    case Float64: return VdlTypeKind.Float64
    case String: return VdlTypeKind.String
    case Enum: return VdlTypeKind.Enum
    case TypeObject: return VdlTypeKind.TypeObject
    case Array: return VdlTypeKind.Array
    case List: return VdlTypeKind.List
    case Set: return VdlTypeKind.Set
    case Map: return VdlTypeKind.Map
    case Struct: return VdlTypeKind.Struct
    case Union: return VdlTypeKind.Union
    case internalNamed: return VdlTypeKind.internalNamed
    }
  }

  // Name returns the name of type t. Nil names are allowed.
  var name:SwiftString? {
    switch self {
    case let .Any(name): return name
    case let .Optional(name, _): return name
    case let .Bool(name): return name
    case let .Byte(name): return name
    case let .Uint16(name): return name
    case let .Uint32(name): return name
    case let .Uint64(name): return name
    case let .Int8(name): return name
    case let .Int16(name): return name
    case let .Int32(name): return name
    case let .Int64(name): return name
    case let .Float32(name): return name
    case let .Float64(name): return name
    case let .String(name): return name
    case let .Enum(name, _): return name
    case let .TypeObject(name): return name
    case let .Array(name, _, _): return name
    case let .List(name, _): return name
    case let .Set(name, _): return name
    case let .Map(name, _, _): return name
    case let .Struct(name, _): return name
    case let .Union(name, _): return name
    default: fatalError("Unknown VDL kind")
    }
  }

  // CanBeNil returns true iff values of t can be nil.
  //
  // Any and Optional values can be nil.
  var canBeNil:SwiftBool {
    switch (self) {
    case .Any, .Optional: return true
    default: return false
    }
  }

  // CanBeNamed returns true iff t can be made into a named type.
  //
  // Any and TypeObject cannot be named.
  var canBeNamed:SwiftBool {
    switch (self) {
    case .Any, .Optional: return false
    default: return true
    }
  }

  // CanBeOptional returns true iff t can be made into an optional type.
  //
  // Only named structs can be optional.
  var canBeOptional:SwiftBool {
    // Our philosophy is that we should retain the full type information in our
    // generated code, and generating annotations to distinguish optional from
    // non-optional types is awkward for unnamed types.
    //
    // Allowing optionality for named types other than structs is also awkward.
    // E.g. if we allowed optional named maps, it's unclear how we'd generate it
    // in Go.  We might just generate a map, which is already a reference type and
    // may be nil, but then we can't distinguish optional map types from
    // non-optional map types.
    switch self {
    case .Struct where self.name != nil: return true
    default: return false
    }
  }

  // IsBytes returns true iff the kind of type is []byte or [N]byte.
  var isBytes:SwiftBool {
    switch self {
    case let .List(_, elem) where elem?.kind == VdlTypeKind.Byte: return true
    case let .Array(_, _, elem) where elem?.kind == VdlTypeKind.Byte: return true
    default: return false
    }
  }

//  public var hashValue: Int {
//    return unique.hashValue
//  }
}

//public func ==(lhs: VdlType, rhs: VdlType) -> Bool {
//  return lhs.unique == rhs.unique
//}
