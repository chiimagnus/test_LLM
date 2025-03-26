//
//  Message.swift
//  test_LLM
//
//  Created by Trae AI on 2025/3/27.
//

import Foundation
import SwiftData

@Model
final class Message {
    var content: String
    var isUserMessage: Bool
    var timestamp: Date
    
    init(content: String, isUserMessage: Bool, timestamp: Date = Date()) {
        self.content = content
        self.isUserMessage = isUserMessage
        self.timestamp = timestamp
    }
}