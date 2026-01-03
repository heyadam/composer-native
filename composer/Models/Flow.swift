//
//  Flow.swift
//  composer
//
//  SwiftData model for a flow (workflow graph)
//

import Foundation
import SwiftData

@Model
final class Flow {
    var id: UUID
    var name: String
    var flowDescription: String  // 'description' is reserved in Swift
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FlowNode.flow)
    var nodes: [FlowNode] = []

    @Relationship(deleteRule: .cascade, inverse: \FlowEdge.flow)
    var edges: [FlowEdge] = []

    init(
        id: UUID = UUID(),
        name: String = "Untitled Flow",
        flowDescription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.flowDescription = flowDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Update the timestamp when flow is modified
    func touch() {
        updatedAt = Date()
    }
}
