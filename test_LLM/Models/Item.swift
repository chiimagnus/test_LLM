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
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
