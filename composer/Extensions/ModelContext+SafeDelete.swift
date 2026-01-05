//
//  ModelContext+SafeDelete.swift
//  composer
//
//  Safe deletion helpers for SwiftData models on iOS.
//
//  On iOS, SwiftData relationship arrays can contain "future" objects
//  (_FullFutureBackingData) that haven't been materialized. When cascade
//  delete tries to snapshot these for undo, it crashes. The solution is
//  to fetch fresh from ModelContext and force-materialize relationships
//  before deletion.
//

import SwiftData
import Foundation

extension ModelContext {

    // MARK: - Flow Deletion

    /// Safely delete a Flow by ID, avoiding the iOS _FullFutureBackingData crash.
    ///
    /// This method:
    /// 1. Fetches the Flow fresh from ModelContext
    /// 2. Force-materializes all relationships (nodes, edges)
    /// 3. Deletes the flow with cascade delete working correctly
    ///
    /// - Parameter flowId: The UUID of the flow to delete
    /// - Returns: `true` if deletion succeeded, `false` if flow not found
    @discardableResult
    func safeDelete(flowId: UUID) -> Bool {
        let predicate = #Predicate<Flow> { flow in
            flow.id == flowId
        }
        guard let flows = try? fetch(FetchDescriptor(predicate: predicate)),
              let flow = flows.first else {
            return false
        }

        // Force-materialize relationships to prevent _FullFutureBackingData crash
        materializeFlowRelationships(flow)

        delete(flow)
        return true
    }

    /// Safely delete a Flow object, avoiding the iOS _FullFutureBackingData crash.
    ///
    /// - Parameter flow: The Flow to delete (will be re-fetched fresh)
    /// - Returns: `true` if deletion succeeded, `false` if flow not found
    @discardableResult
    func safeDelete(flow: Flow) -> Bool {
        safeDelete(flowId: flow.id)
    }

    // MARK: - Node Deletion

    /// Safely delete nodes by IDs.
    ///
    /// - Parameter nodeIds: Set of node UUIDs to delete
    /// - Returns: The deleted nodes' labels (for logging), empty if none found
    @discardableResult
    func safeDelete(nodeIds: Set<UUID>) -> [String] {
        let predicate = #Predicate<FlowNode> { node in
            nodeIds.contains(node.id)
        }
        guard let nodes = try? fetch(FetchDescriptor(predicate: predicate)),
              !nodes.isEmpty else {
            return []
        }

        let labels = nodes.map { $0.label }
        let freshFlow = nodes.first?.flow

        for node in nodes {
            delete(node)
        }
        freshFlow?.touch()

        return labels
    }

    // MARK: - Edge Deletion

    /// Safely delete edges by IDs.
    ///
    /// - Parameter edgeIds: Set of edge UUIDs to delete
    /// - Returns: Number of edges deleted
    @discardableResult
    func safeDelete(edgeIds: Set<UUID>) -> Int {
        let predicate = #Predicate<FlowEdge> { edge in
            edgeIds.contains(edge.id)
        }
        guard let edges = try? fetch(FetchDescriptor(predicate: predicate)),
              !edges.isEmpty else {
            return 0
        }

        let freshFlow = edges.first?.flow

        for edge in edges {
            delete(edge)
        }
        freshFlow?.touch()

        return edges.count
    }

    // MARK: - Private Helpers

    /// Force SwiftData to materialize all lazy relationships on a Flow.
    ///
    /// This converts "future" proxy objects into real objects so cascade
    /// delete can snapshot them for undo without crashing.
    private func materializeFlowRelationships(_ flow: Flow) {
        // Touch each node to materialize
        for node in flow.nodes {
            _ = node.id
            // Also materialize node's edge relationships
            for edge in node.incomingEdges {
                _ = edge.id
            }
            for edge in node.outgoingEdges {
                _ = edge.id
            }
        }
        // Touch each edge to materialize
        for edge in flow.edges {
            _ = edge.id
        }
    }
}
