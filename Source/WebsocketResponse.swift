//
//  Response.swift
//  Pods
//
//  Created by Simon Manning on 23/06/2016.
//
//

import Foundation

open class WebsocketResponse<M: ChatMessageProtocol> {
    open let ref: String
    open let topic: String
    open let event: String
    let payload: PayloadMessageProtocol
    
    init?(data: Data) {
        do {
            let object = try M(serializedData: data)
            self.ref = object.reference
            self.topic = object.topic
            self.event = object.event
            self.payload = object.payloadMessage
        } catch {
            print("[Birdsong]: Error parsing Protobuf ")
            return nil
        }
    }
}

public protocol PayloadMessageProtocol { }
public protocol ChatMessageProtocol {
    init(webSocketData: Data) throws
    var topic: String                               { get }
    var event: String                               { get }
    var payloadMessage: PayloadMessageProtocol      { get }
    var reference: String                           { get }
}
