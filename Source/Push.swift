//
//  Message.swift
//  Pods
//
//  Created by Simon Manning on 23/06/2016.
//
//

import Foundation

public class Push {
    public let topic: String
    public let event: String
    public let payload: Conversation
    let ref: String?

    var receivedStatus: String?
    var receivedResponse: Conversation

    fileprivate var callbacks: [String: [(Conversation) -> ()]] = [:]
    fileprivate var alwaysCallbacks: [() -> ()] = []

    // MARK: - JSON parsing

    func toJson() throws -> Data {
        let dict = [
            "topic": topic,
            "event": event,
            "payload": payload,
            "ref": ref ?? ""
        ] as [String : Any]

        return try JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions())
    }

    init(_ event: String, topic: String, payload: Conversation, ref: String = UUID().uuidString) {
        (self.topic, self.event, self.payload, self.ref) = (topic, event, payload, ref)
    }

    // MARK: - Callback registration

    @discardableResult
    public func receive(_ status: String, callback: @escaping (Conversation) -> ()) -> Self {
        if receivedStatus == status,
            let receivedResponse = receivedResponse {
            callback(receivedResponse)
        }
        else {
            if (callbacks[status] == nil) {
                callbacks[status] = [callback]
            }
            else {
                callbacks[status]?.append(callback)
            }
        }

        return self
    }

    @discardableResult
    public func always(_ callback: @escaping () -> ()) -> Self {
        alwaysCallbacks.append(callback)
        return self
    }

    // MARK: - Response handling

    func handleResponse(_ response: Response) {
        receivedStatus = "ok" //response.payload["status"] as? String
        receivedResponse = response.payload

        fireCallbacksAndCleanup()
    }

    func handleParseError() {
        receivedStatus = "error"
        receivedResponse = ["reason": "Invalid payload request." as AnyObject]

        fireCallbacksAndCleanup()
    }

    func handleNotConnected() {
        receivedStatus = "error"
        receivedResponse = ["reason": "Not connected to socket." as AnyObject]

        fireCallbacksAndCleanup()
    }

    func fireCallbacksAndCleanup() {
        defer {
            callbacks.removeAll()
            alwaysCallbacks.removeAll()
        }

        guard let status = receivedStatus else {
            return
        }

        alwaysCallbacks.forEach({$0()})

        if let matchingCallbacks = callbacks[status],
            let receivedResponse = receivedResponse {
            matchingCallbacks.forEach({$0(receivedResponse)})
        }
    }
}
