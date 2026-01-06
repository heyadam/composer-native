//
//  PreviewSidebarTypes.swift
//  composer
//
//  Data model for preview sidebar entries
//

import Foundation

/// Entry representing output from a PreviewOutput node
struct PreviewEntry: Identifiable, Sendable {
    let id: UUID
    let nodeId: UUID
    let nodeLabel: String
    var status: ExecutionStatus
    var timestamp: Date
    var stringOutput: String?
    var imageOutput: Data?
    var audioOutput: Data?
    var error: String?

    init(
        id: UUID = UUID(),
        nodeId: UUID,
        nodeLabel: String,
        status: ExecutionStatus = .idle,
        timestamp: Date = Date(),
        stringOutput: String? = nil,
        imageOutput: Data? = nil,
        audioOutput: Data? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.nodeId = nodeId
        self.nodeLabel = nodeLabel
        self.status = status
        self.timestamp = timestamp
        self.stringOutput = stringOutput
        self.imageOutput = imageOutput
        self.audioOutput = audioOutput
        self.error = error
    }

    /// Whether this entry has any output content
    var hasOutput: Bool {
        stringOutput != nil || imageOutput != nil || audioOutput != nil
    }
}
