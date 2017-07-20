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
            self.ref = object.referenceProtocol
            self.topic = object.topicProtocol
            self.event = object.eventProtocol
            self.payload = object.payloadProtocol
        } catch {
            print("[Birdsong]: Error parsing Protobuf ")
            return nil
        }
    }
}

public protocol PayloadMessageProtocol { }
public protocol ChatMessageProtocol: SwiftProtobuf.Message {
    var topicProtocol: String               { get }
    var eventProtocol: String               { get }
    var payloadProtocol: PayloadMessageProtocol    { get }
    var referenceProtocol: String           { get }
}
