//===--- TypeIndexed.swift ------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2015 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

protocol Resettable : AnyObject {
  func reset()
}

public class ResettableValue<Value> : Resettable {
  public init(_ value: Value) {
    self.defaultValue = value
    self.value = value
    _allResettables.append(self)
  }

  public func reset() {
    value = defaultValue
  }

  public let defaultValue: Value
  public var value: Value
}

internal var _allResettables: [Resettable] = []

public class TypeIndexed<Value> : Resettable {
  public init(_ value: Value) {
    self.defaultValue = value
    _allResettables.append(self)
  }
  
  public subscript(t: Any.Type) -> Value {
    get {
      return byType[TypeIdentifier(t)] ?? defaultValue
    }
    set {
      byType[TypeIdentifier(t)] = newValue
    }
  }

  public func reset() { byType = [:] }

  internal var byType: [TypeIdentifier:Value] = [:]
  internal var defaultValue: Value
}

extension TypeIndexed where Value : ForwardIndexType {
  public func expectIncrement<R>(
    t: Any.Type,
    @autoclosure _ message: () -> String = "",
    showFrame: Bool = true,
    stackTrace: SourceLocStack = SourceLocStack(),  
    file: String = __FILE__, line: UInt = __LINE__,
    body: () -> R
  ) -> R {
    let expected = self[t].successor()
    let r = body()
    expectEqual(
      expected, self[t], message(),
      stackTrace: stackTrace.pushIf(showFrame, file: file, line: line))
    return r
  }
}

extension TypeIndexed where Value : Equatable {
  public func expectUnchanged<R>(
    t: Any.Type,
    @autoclosure _ message: () -> String = "",
    showFrame: Bool = true,
    stackTrace: SourceLocStack = SourceLocStack(),  
    file: String = __FILE__, line: UInt = __LINE__,
    body: () -> R
  ) -> R {
    let expected = self[t]
    let r = body()
    expectEqual(
      expected, self[t], message(),
      stackTrace: stackTrace.pushIf(showFrame, file: file, line: line))
    return r
  }
}

public func <=> <T: Comparable>(
  lhs: (TypeIdentifier, T),
  rhs: (TypeIdentifier, T)
) -> ExpectedComparisonResult {
  let a = lhs.0 <=> rhs.0
  if !a.isEQ() { return a }
  return lhs.1 <=> rhs.1
}

public func expectEqual<V: Comparable>(
  expected: DictionaryLiteral<Any.Type, V>, _ actual: TypeIndexed<V>,
  @autoclosure _ message: () -> String = "",
  showFrame: Bool = true,
  stackTrace: SourceLocStack = SourceLocStack(),  
  file: String = __FILE__, line: UInt = __LINE__
) {
  expectEqualsUnordered(
    expected.map { (TypeIdentifier($0.0), $0.1) },
    actual.byType,
    message(), stackTrace: stackTrace) { $0 <=> $1 }
}

