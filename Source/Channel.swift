//
//  Channel.swift
//  Pods
//
//  Created by Simon Manning on 24/06/2016.
//
//

import Foundation

open class Channel<T: ChatMessageProtocol> {
    // MARK: - Properties
    
    open let topic: String
    open let params: [String: Any]
    fileprivate weak var socket: Socket<T>?
    fileprivate(set) open var state: State
    
    fileprivate var callbacks: [String: (WebsocketResponse<T>) -> ()] = [:] //it was fileprivate var callbacks: [String: (Response) -> ()] = [:]
    
    init(socket: Socket, topic: String, params: [String: Any] = [:]) {
        self.socket = socket
        self.topic = topic
        self.params = params
        self.state = .Closed
    }
    
    // MARK: - Control
    
    @discardableResult
    open func join() -> Push<T>? {
        state = .Joining
        
        return send(SocketEvent.Join, payload: params)?.receive("ok", callback: { response in
            self.state = .Joined
        })
    }
    
    @discardableResult
    open func leave() -> Push<T>? {
        state = .Leaving
        
        return send(SocketEvent.Leave, payload: [:])?.receive("ok", callback: { response in
            self.callbacks.removeAll()
        })
    }
    
    @discardableResult
    open func send(_ event: String,
                   payload: [String: Any]) -> Push<T>? {
        let message = Push<T>(event, topic: topic, payload: payload)
        return socket?.send(message)
    }
    
    // MARK: - Raw events
    func received(_ response: WebsocketResponse<T>) {
        if let callback = callbacks[response.event] {
            callback(response)
        }
    }
    
    // MARK: - Callbacks
    
    @discardableResult
    open func on(_ event: String, callback: @escaping (WebsocketResponse<T>) -> ()) -> Self {
        callbacks[event] = callback
        return self
    }
    
    // MARK: - States
    
    public enum State: String {
        case Closed = "closed"
        case Errored = "errored"
        case Joined = "joined"
        case Joining = "joining"
        case Leaving = "leaving"
    }
}

