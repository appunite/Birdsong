//
//  Socket.swift
//  Pods
//
//  Created by Simon Manning on 23/06/2016.
//
//

import Foundation
import Starscream

public final class Socket<T: ChatMessageProtocol> {
    // MARK: - Convenience aliases
    public typealias Payload = [String: Any]
    
    // MARK: - Properties
    
    fileprivate var socket: WebSocket
    public var enableLogging = true
    
    public var onConnect: (() -> ())?
    public var onDisconnect: ((NSError?) -> ())?
    
    fileprivate(set) public var channels: [String: Channel<T>] = [:]
    
    fileprivate var heartbeatQueue: DispatchQueue
    
    fileprivate var awaitingResponses = [String: Push<T>]()
    
    public var isConnected: Bool {
        return socket.isConnected
    }
    
    // MARK: - Initialisation
    
    public init(url: URL, params: [String: String]? = nil) {
        heartbeatQueue = DispatchQueue(label: "com.ecksd.birdsong.hbqueue", attributes: [])
        socket = WebSocket(url: buildURL(url, params: params))
        socket.delegate = self
    }
    
    public convenience init(url: String, params: [String: String]? = nil) {
        if let parsedURL = URL(string: url) {
            self.init(url: parsedURL, params: params)
        }
        else {
            print("[Birdsong] Invalid URL in init. Defaulting to localhost URL.")
            self.init()
        }
    }
    
    public convenience init(prot: String = "http", host: String = "localhost", port: Int = 4000,
                            path: String = "socket", transport: String = "websocket",
                            params: [String: String]? = nil, selfSignedSSL: Bool = false) {
        let url = "\(prot)://\(host):\(port)/\(path)/\(transport)"
        self.init(url: url, params: params)
    }
    
    // MARK: - Connection
    
    public func connect() {
        if socket.isConnected {
            return
        }
        
        log("Connecting to: \(socket.currentURL)")
        socket.connect()
    }
    
    public func disconnect() {
        if !socket.isConnected {
            return
        }
        
        log("Disconnecting from: \(socket.currentURL)")
        socket.disconnect()
    }
    
    // MARK: - Channels
    
    public func channel(_ topic: String, payload: Payload = [:]) -> Channel<T> {
        let channel = Channel<T>(socket: self, topic: topic, params: payload)
        channels[topic] = channel
        return channel
    }
    
    public func remove(_ channel: Channel<T>) {
        channel.leave()?.receive("ok") { [weak self] response in
            self?.channels.removeValue(forKey: channel.topic)
        }
    }
    
    // MARK: - Heartbeat
    
    func sendHeartbeat() {
        guard socket.isConnected else {
            return
        }
        
        let ref = Socket.HeartbeatPrefix + UUID().uuidString
        _ = send(Push<T>(SocketEvent.Heartbeat, topic: "phoenix", payload: [:], ref: ref))
        queueHeartbeat()
    }
    
    func queueHeartbeat() {
        let time = DispatchTime.now() + Double(Socket<T>.HeartbeatInterval) / Double(NSEC_PER_SEC)
        heartbeatQueue.asyncAfter(deadline: time) {
            self.sendHeartbeat()
        }
    }
    
    // MARK: - Sending data
    
    func send(_ event: String, topic: String, payload: Payload) -> Push<T> {
        let push = Push<T>(event, topic: topic, payload: payload)
        return send(push)
    }
    
    func send(_ message: Push<T>) -> Push<T> {
        if !socket.isConnected {
            message.handleNotConnected()
            return message
        }
        
        do {
            let data = try message.toJson()
            log("Sending: \(message.payload)")
            if let ref = message.ref {
                awaitingResponses[ref] = message
                socket.write(data: data, completion: nil)
            }
        } catch let error as NSError {
            log("Failed to send message: \(error)")
            message.handleParseError()
        }
        
        return message
    }
}

extension Socket: WebSocketDelegate {
    
    // MARK: - WebSocketDelegate
    
    public func websocketDidConnect(socket: WebSocket) {
        log("Connected to: \(socket.currentURL)")
        onConnect?()
        queueHeartbeat()
    }
    
    public func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        log("Disconnected from: \(socket.currentURL)")
        onDisconnect?(error)
        
        // Reset state.
        awaitingResponses.removeAll()
        channels.removeAll()
    }
    
    public func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        //we use PROTO so there's no message. just data
    }
    
    public func websocketDidReceiveData(socket: WebSocket, data: Data) {
        log("Received data: \(data)")
        let response = WebsocketResponse<T>(data: data)
        channels[(response?.topic)!]?.received(response!)           //TO:DO !!!
    }
}

// MARK: - Logging

extension Socket {
    fileprivate func log(_ message: String) {
        if enableLogging {
            print("[Birdsong]: \(message)")
        }
    }
}

// MARK: - Private URL helpers

private func buildURL(_ url: URL, params: [String: String]?) -> URL {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
        let params = params else {
            return url
    }
    
    var queryItems = [URLQueryItem]()
    params.forEach({
        queryItems.append(URLQueryItem(name: $0, value: $1))
    })
    
    components.queryItems = queryItems
    
    guard let url = components.url else { fatalError("Problem with the URL") }
    
    return url
}

fileprivate let HeartbeatInterval = Int64(30 * NSEC_PER_SEC)
fileprivate let HeartbeatPrefix = "hb-"

// MARK: - Event constants

struct SocketEvent {
    static let Heartbeat = "heartbeat"
    static let Join = "phx_join"
    static let Leave = "phx_leave"
    static let Reply = "phx_reply"
    static let Error = "phx_error"
    static let Close = "phx_close"
}
