//
//  Response.swift
//  Pods
//
//  Created by Simon Manning on 23/06/2016.
//
//

import Foundation
import SwiftProtobuf

open class Response {
    open let ref: String
    open let topic: String
    open let event: String
    open let payload: Conversation
    
    init?(data: Data) {
        do {
            let object = try ChatMessage(serializedData: data)
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
