//
//  File.swift
//  Swift 5.0
//  Created by Kyle Ishie, Kyle Ishie Development.
//


import Foundation
import NIO

extension EventLoopFuture where Value : Sequence {
    
    @inlinable public func map<T>(transform: @escaping (Value.Element) throws -> T) rethrows -> EventLoopFuture<[T]> {
        flatMapThrowing { try $0.map(transform) }
    }
    
    @inlinable public func compactMap<T>(_ transform: @escaping (Value.Element) throws -> T?) rethrows -> EventLoopFuture<[T]> {
        flatMapThrowing { try $0.compactMap(transform) }
    }
    
}

extension EventLoopFuture {
    
    @inlinable public func whenAllComplete<NewValue>() throws -> EventLoopFuture<[Result<NewValue, Error>]> where Value == [EventLoopFuture<NewValue>] {
        flatMap { futures -> EventLoopFuture<[Result<NewValue, Error>]> in
            EventLoopFuture<NewValue>.whenAllComplete(futures, on: self.eventLoop)
        }
    }
    
}

extension EventLoopFuture where Value : Collection {
    
    @inlinable public func flatMap<SegmentOfResult>(_ transform: @escaping (Value.Element) throws -> SegmentOfResult) rethrows -> EventLoopFuture<[SegmentOfResult.Element]> where SegmentOfResult : Sequence {
        flatMapThrowing({ try $0.flatMap(transform) })
    }

}

