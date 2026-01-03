//
//  Item.swift
//  composer
//
//  Created by Adam Presson on 1/3/26.
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
