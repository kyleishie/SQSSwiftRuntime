import Foundation
import AWSSDKSwiftCore
import SQS
import NIO
import Dispatch

public final class SQSSwiftRuntime {
    
    private let sqsClient : SQS
    
    public init(accessKeyId: String? = nil, secretAccessKey: String? = nil, region: AWSSDKSwiftCore.Region? = nil, endpoint: String? = nil) {
        self.sqsClient = SQS(accessKeyId: accessKeyId, secretAccessKey: secretAccessKey, region: region, endpoint: endpoint)
    }
    
    
    enum State : Int, Comparable {
        
        /// The initial state.
        case idle = 0
        
        /// The Runtime is actively receiving messages from at least one queue.
        case receiving
        
        /// The Runtime is shutting down and all receivers run loops have draining.
        case shuttingdown
        
        /// The Runtime has shutdown and all receivers have stopped receiving.
        case shutdown
        
        static func < (lhs: SQSSwiftRuntime.State, rhs: SQSSwiftRuntime.State) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    private var _state : State = .idle
    private var _stateLock = DispatchSemaphore(value: 1)
    
    private func lockState() {
        _ = _stateLock.wait(timeout: DispatchTime.distantFuture)
    }
    
    private func unlockState() {
        _stateLock.signal()
    }
    
}


extension SQSSwiftRuntime {
    
    public typealias SyncEventHandler<E : Decodable> = (E) throws -> Void
    public func handleEvent<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping SyncEventHandler<Event>) throws {
        try handleEvent(request: request) { [unowned self] event -> EventLoopFuture<Void> in
            return self.sqsClient.client.eventLoopGroup.next().submit({ try handler(event) })
        }
    }
    
    public typealias AsyncEventHandler<E : Decodable> = (E, (() -> Void)) throws -> Void
    public func handleEvent<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping AsyncEventHandler<Event>) throws {
        try handleEvent(request: request) { [unowned self] (event : Event) -> EventLoopFuture<Void> in
            
            let promise = self.sqsClient.client.eventLoopGroup.next().makePromise(of: Void.self)
            do {
                try handler(event, { promise.succeed(()) })
            } catch {
                promise.fail(error)
            }
            return promise.futureResult
        }
    }
    
    internal enum ReceiverError : Swift.Error {
        case noNewMessages
    }
    
    public typealias NIOEventHandler<E : Decodable> = (E) throws -> EventLoopFuture<Void>
    public func handleEvent<Event : Decodable>(request: SQS.ReceiveMessageRequest, handler: @escaping NIOEventHandler<Event>) throws {
        
        lockState()
        _state = .receiving
        unlockState()
        
        var backOffTimeAmount : TimeAmount = .milliseconds(0)
        
        repeat {
            
            do {
                /// Receive Messages from SQS
                /// Verify that we have messages
                /// Decoded the message bodies
                /// Call the handlers passing in the message bodies
                _ = try sqsClient.client.eventLoopGroup.next().scheduleTask(in: backOffTimeAmount) {
                    return try self.sqsClient.receiveMessage(request)
                        .unwrapMessages()
                        .map({ messages -> [SQS.Message] in
                            backOffTimeAmount = .milliseconds(0)
                            return messages
                        })
                        .decodeMessages(to: Event.self)
                        .map { (message, event) -> EventLoopFuture<Void> in
                            return try handler(event).flatMapThrowing({
                                let deleteRequest = SQS.DeleteMessageRequest(queueUrl: request.queueUrl, receiptHandle: message.receiptHandle!)
                                try self.sqsClient.deleteMessage(deleteRequest)
                            })
                        }
                        .whenAllComplete()
                    
                }.futureResult
                .wait().wait()
                
            } catch ReceiverError.noNewMessages {
                
                switch backOffTimeAmount {
                case .milliseconds(0):
                    backOffTimeAmount = .milliseconds(200)
                case .milliseconds(200):
                    backOffTimeAmount = .milliseconds(400)
                default:
                    backOffTimeAmount = .milliseconds(400)
                }
                
            } catch {
                print(error)
            }

        } while _state < .shuttingdown
        
    }
    
}

extension SQSSwiftRuntime {
    
    public enum QueueError : Swift.Error {
        case queueNotFound
    }
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping SyncEventHandler<Event>) throws {
        try handleEventsInQueue(queue) { [unowned self] event -> EventLoopFuture<Void> in
            return self.sqsClient.client.eventLoopGroup.next().submit({ try handler(event) })
        }
    }
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping AsyncEventHandler<Event>) throws {
        try handleEventsInQueue(queue) { [unowned self] (event : Event) -> EventLoopFuture<Void> in
            let promise = self.sqsClient.client.eventLoopGroup.next().makePromise(of: Void.self)
            do {
                try handler(event, { promise.succeed(()) })
            } catch {
                promise.fail(error)
            }
            return promise.futureResult
        }
    }
    
    public func handleEventsInQueue<Event : Decodable>(_ queue: String, handler: @escaping NIOEventHandler<Event>) throws {
        let response = try sqsClient.getQueueUrl(SQS.GetQueueUrlRequest(queueName: queue, queueOwnerAWSAccountId: nil)).wait()
        guard let queueUrl = response.queueUrl else {
            throw QueueError.queueNotFound
        }
        
        let request = SQS.ReceiveMessageRequest(maxNumberOfMessages: 10, queueUrl: queueUrl, visibilityTimeout: 10, waitTimeSeconds: 20)
        
        try handleEvent(request: request, handler: handler)
        
    }
    
}

