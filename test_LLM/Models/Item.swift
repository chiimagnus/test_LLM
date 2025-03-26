//
//  Item.swift
//  test_LLM
//
//  Created by chii_magnus on 2025/3/27.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var activityDescription: String
    var summary: String?
    
    init(timestamp: Date = Date(), activityDescription: String = "活动记录", summary: String? = nil) {
        self.timestamp = timestamp
        self.activityDescription = activityDescription
        self.summary = summary
    }
}
