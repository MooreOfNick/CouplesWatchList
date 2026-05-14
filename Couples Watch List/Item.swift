//
//  Item.swift
//  Couples Watch List
//
//  Created by Nick Moore on 5/13/26.
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
