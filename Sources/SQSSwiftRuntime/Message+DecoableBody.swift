//
//  File.swift
//  Swift 5.0
//  Created by Kyle Ishie, Kyle Ishie Development.
//


import Foundation
import SQS
import NIO

extension SQS.Message {
    
    public enum BodyDecodingError : Swift.Error {
        case noBody
    }
    
    public func decodeBody<T : Decodable>(as type: T.Type) throws -> T {
        guard let data = body?.data(using: .utf8) else {
            throw BodyDecodingError.noBody
        }
        
        return try JSONDecoder().decode(type, from: data)
    }
    
}

extension EventLoopFuture where Value == SQS.ReceiveMessageResult {
    
    func unwrapMessages() throws -> EventLoopFuture<[SQS.Message]> {
        flatMapThrowing { result -> [SQS.Message] in
            guard let messages = result.messages else {
                throw SQSSwiftRuntime.ReceiverError.noNewMessages
            }

            return messages
        }
    }
    
}

extension EventLoopFuture where Value == [SQS.Message] {
    
    func decodeMessages<Event : Decodable>(to type: Event.Type) throws -> EventLoopFuture<[(SQS.Message, Event)]> {
        flatMapThrowing { messages -> [(SQS.Message, Event)] in
            return try messages.map({ ($0, try $0.decodeBody(as: Event.self)) })
        }
    }
    
}
