//
//  Response.swift
//  Pods
//
//  Created by Simon Manning on 23/06/2016.
//
//

import Foundation
import SwiftProtobuf

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
            self.payload = object.payload
        } catch {
            print("[Birdsong]: Error parsing Protobuf ")
            return nil
        }
    }
}

public protocol PayloadMessageProtocol { }
public protocol ChatMessageProtocol: SwiftProtobuf.Message {
    var topic: String               { get set }
    var event: String               { get set }
    var payload: PayloadMessageProtocol    { get set }
    var reference: String           { get set }
}
