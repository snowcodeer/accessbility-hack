import Foundation
import simd

// MARK: - Navigation Data Models

struct POI: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var position: SIMD3<Float> // World coordinates
    
    init(id: UUID = UUID(), name: String, position: SIMD3<Float>) {
        self.id = id
        self.name = name
        self.position = position
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let array = try container.decode([Float].self, forKey: .position)
        position = array.safeXYZ()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode([position.x, position.y, position.z], forKey: .position)
    }
}

struct NavNode: Identifiable, Codable, Equatable {
    var id: UUID
    var position: SIMD3<Float>
    
    init(id: UUID = UUID(), position: SIMD3<Float>) {
        self.id = id
        self.position = position
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, position
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let array = try container.decode([Float].self, forKey: .position)
        position = array.safeXYZ()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode([position.x, position.y, position.z], forKey: .position)
    }
}

struct NavEdge: Codable, Equatable, Identifiable {
    var id: UUID
    var aNodeID: UUID
    var bNodeID: UUID
    var costMeters: Float
    
    init(id: UUID = UUID(), aNodeID: UUID, bNodeID: UUID, costMeters: Float) {
        self.id = id
        self.aNodeID = aNodeID
        self.bNodeID = bNodeID
        self.costMeters = costMeters
    }
}

struct NavGraph: Codable, Equatable {
    var nodes: [NavNode]
    var edges: [NavEdge]
    
    init(nodes: [NavNode] = [], edges: [NavEdge] = []) {
        self.nodes = nodes
        self.edges = edges
    }
    
    mutating func mergeOrAddNode(position: SIMD3<Float>, mergeDistance: Float) -> (UUID, SIMD3<Float>) {
        if let existing = nodes.first(where: { simd_distance($0.position, position) < mergeDistance }) {
            return (existing.id, existing.position)
        }
        let node = NavNode(position: position)
        nodes.append(node)
        return (node.id, node.position)
    }
    
    mutating func addEdgeBetween(a: UUID, b: UUID) {
        guard a != b else { return }
        if edges.contains(where: { ($0.aNodeID == a && $0.bNodeID == b) || ($0.aNodeID == b && $0.bNodeID == a) }) {
            return
        }
        guard let aPos = node(id: a)?.position, let bPos = node(id: b)?.position else { return }
        let distance = simd_distance(aPos, bPos)
        let edge = NavEdge(aNodeID: a, bNodeID: b, costMeters: distance)
        edges.append(edge)
    }
    
    func nearestNode(to position: SIMD3<Float>) -> NavNode? {
        nodes.min(by: { simd_distance($0.position, position) < simd_distance($1.position, position) })
    }
    
    func node(id: UUID) -> NavNode? {
        nodes.first(where: { $0.id == id })
    }
    
    func neighbors(of nodeID: UUID) -> [(NavNode, Float)] {
        edges.compactMap { edge in
            if edge.aNodeID == nodeID, let node = node(id: edge.bNodeID) {
                return (node, edge.costMeters)
            } else if edge.bNodeID == nodeID, let node = node(id: edge.aNodeID) {
                return (node, edge.costMeters)
            }
            return nil
        }
    }
}

// MARK: - Helpers

private extension Array where Element == Float {
    func safeXYZ() -> SIMD3<Float> {
        if count >= 3 {
            return SIMD3(self[0], self[1], self[2])
        }
        // Fallback to zeros if data is malformed
        return SIMD3.zero
    }
}
