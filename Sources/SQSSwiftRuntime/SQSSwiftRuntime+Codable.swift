//
//  SQSSwiftRuntime+Codable.swift
//  
//
//  Created by Kyle Ishie on 12/28/19.
//

import Foundation
import AWSSDKSwiftCore
import SQS
import NIO
import Dispatch

extension SQSSwiftRuntime {
    
    public typealias SyncEventHandler<E : Decodable> = (E) throws -> Void
    public func handleEvents<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping SyncEventHandler<Event>) throws {
        try handleMessages(request: request, handler: { try handler(try $0.decodeBody(as: Event.self)) })
    }
    
    public typealias AsyncEventHandler<E : Decodable> = (E, (() -> Void)) throws -> Void
    public func handleEvents<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping AsyncEventHandler<Event>) throws {
        try handleMessages(request: request, handler: { try handler(try $0.decodeBody(as: Event.self), $1) })
    }
    
    public typealias NIOEventHandler<E : Decodable> = (E) throws -> EventLoopFuture<Void>
    public func handleEvents<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping NIOEventHandler<Event>) throws {
        try handleMessages(request: request) { try handler(try $0.decodeBody(as: Event.self)) }
    }
    
}

extension SQSSwiftRuntime {
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping SyncEventHandler<Event>) throws {
        try handleMessagesInQueue(queue, handler: { try handler(try $0.decodeBody(as: Event.self)) })
    }
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping AsyncEventHandler<Event>) throws {
        try handleMessagesInQueue(queue) { try handler(try $0.decodeBody(as: Event.self), $1) }
    }
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping NIOEventHandler<Event>) throws {
        try handleMessagesInQueue(queue, handler: { try handler(try $0.decodeBody(as: Event.self)) })
    }
    
}
