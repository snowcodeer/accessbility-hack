import Foundation
import simd

// MARK: - Persistence

final class NavigationDataStore {
    private let mapManager = WorldMapManager()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private func navGraphURL(for mapName: String) -> URL {
        mapManager.mapsDirectory.appendingPathComponent("\(mapName).navgraph.json")
    }
    
    func poisURL(for mapName: String) -> URL {
        mapManager.mapsDirectory.appendingPathComponent("\(mapName).pois.json")
    }
    
    private func pathURL(for mapName: String) -> URL {
        mapManager.mapsDirectory.appendingPathComponent("\(mapName).path.json")
    }
    
    func loadGraph(mapName: String) -> NavGraph {
        let url = navGraphURL(for: mapName)
        guard let data = try? Data(contentsOf: url),
              let graph = try? decoder.decode(NavGraph.self, from: data) else {
            return NavGraph()
        }
        return graph
    }
    
    func saveGraph(_ graph: NavGraph, mapName: String) {
        guard let data = try? encoder.encode(graph) else { return }
        try? data.write(to: navGraphURL(for: mapName))
    }
    
    func loadPOIs(mapName: String) -> [POI] {
        let url = poisURL(for: mapName)
        guard let data = try? Data(contentsOf: url),
              let items = try? decoder.decode([POI].self, from: data) else {
            return []
        }
        return items
    }
    
    func savePOIs(_ pois: [POI], mapName: String) {
        guard let data = try? encoder.encode(pois) else { return }
        try? data.write(to: poisURL(for: mapName), options: [.atomic])
    }
    
    func loadPath(mapName: String) -> [SIMD3<Float>] {
        let url = pathURL(for: mapName)
        guard let data = try? Data(contentsOf: url),
              let arrays = try? decoder.decode([[Float]].self, from: data) else {
            return []
        }
        return arrays.compactMap { $0.count >= 3 ? SIMD3($0[0], $0[1], $0[2]) : nil }
    }
    
    func savePath(_ points: [SIMD3<Float>], mapName: String) {
        let arrays = points.map { [$0.x, $0.y, $0.z] }
        guard let data = try? encoder.encode(arrays) else { return }
        try? data.write(to: pathURL(for: mapName))
    }
    
    func poiFileInfo(mapName: String) -> (exists: Bool, size: Int?) {
        let url = poisURL(for: mapName)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
        return (exists, size)
    }
    
    func pathFileInfo(mapName: String) -> (exists: Bool, size: Int?) {
        let url = pathURL(for: mapName)
        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue
        return (exists, size)
    }
}

// MARK: - Graph Recording (scan-time)

final class GraphRecorder {
    private(set) var graph: NavGraph
    private var lastNodeID: UUID?
    private var lastSamplePosition: SIMD3<Float>?
    
    let sampleDistance: Float
    let mergeDistance: Float
    let junctionDistance: Float
    
    init(sampleDistance: Float = 1.0, mergeDistance: Float = 1.0, junctionDistance: Float = 1.0, initialGraph: NavGraph = NavGraph()) {
        self.sampleDistance = sampleDistance
        self.mergeDistance = mergeDistance
        self.junctionDistance = junctionDistance
        self.graph = initialGraph
    }
    
    func reset(with graph: NavGraph) {
        self.graph = graph
        lastNodeID = nil
        lastSamplePosition = nil
    }
    
    @discardableResult
    func addSample(position: SIMD3<Float>) -> Bool {
        if let last = lastSamplePosition, simd_distance(last, position) < sampleDistance {
            return false
        }
        
        let (nodeID, actualPosition) = graph.mergeOrAddNode(position: position, mergeDistance: mergeDistance)
        if let lastID = lastNodeID, lastID != nodeID {
            graph.addEdgeBetween(a: lastID, b: nodeID)
        }
        connectNearbyJunctions(nodeID: nodeID)
        lastNodeID = nodeID
        lastSamplePosition = actualPosition
        return true
    }
    
    private func connectNearbyJunctions(nodeID: UUID) {
        guard let node = graph.node(id: nodeID) else { return }
        for other in graph.nodes where other.id != nodeID {
            let distance = simd_distance(node.position, other.position)
            if distance < junctionDistance {
                graph.addEdgeBetween(a: nodeID, b: other.id)
            }
        }
    }
}

// MARK: - A* Planner

struct AStarPlanner {
    func planRoute(graph: NavGraph, start: SIMD3<Float>, goal: SIMD3<Float>) -> [SIMD3<Float>]? {
        guard let startNode = graph.nearestNode(to: start),
              let goalNode = graph.nearestNode(to: goal) else {
            return nil
        }
        
        let path = aStar(graph: graph, startID: startNode.id, goalID: goalNode.id)
        guard !path.isEmpty else { return nil }
        
        var positions: [SIMD3<Float>] = []
        positions.append(start) // start at current camera
        for id in path {
            if let node = graph.node(id: id) {
                positions.append(node.position)
            }
        }
        positions.append(goal) // finish at POI
        return positions
    }
    
    private func aStar(graph: NavGraph, startID: UUID, goalID: UUID) -> [UUID] {
        var openSet: Set<UUID> = [startID]
        var cameFrom: [UUID: UUID] = [:]
        
        var gScore: [UUID: Float] = Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0.id, Float.greatestFiniteMagnitude) })
        var fScore = gScore
        gScore[startID] = 0
        fScore[startID] = heuristic(graph: graph, from: startID, to: goalID)
        
        while !openSet.isEmpty {
            guard let current = openSet.min(by: { (fScore[$0] ?? .greatestFiniteMagnitude) < (fScore[$1] ?? .greatestFiniteMagnitude) }) else {
                break
            }
            
            if current == goalID {
                return reconstructPath(cameFrom: cameFrom, current: current)
            }
            
            openSet.remove(current)
            for (neighbor, cost) in graph.neighbors(of: current) {
                let tentative = (gScore[current] ?? .greatestFiniteMagnitude) + cost
                if tentative < (gScore[neighbor.id] ?? .greatestFiniteMagnitude) {
                    cameFrom[neighbor.id] = current
                    gScore[neighbor.id] = tentative
                    fScore[neighbor.id] = tentative + heuristic(graph: graph, from: neighbor.id, to: goalID)
                    openSet.insert(neighbor.id)
                }
            }
        }
        
        return []
    }
    
    private func heuristic(graph: NavGraph, from: UUID, to: UUID) -> Float {
        guard let start = graph.node(id: from)?.position,
              let goal = graph.node(id: to)?.position else { return 0 }
        return simd_distance(start, goal)
    }
    
    private func reconstructPath(cameFrom: [UUID: UUID], current: UUID) -> [UUID] {
        var path: [UUID] = [current]
        var currentNode = current
        while let parent = cameFrom[currentNode] {
            path.append(parent)
            currentNode = parent
        }
        return path.reversed()
    }
}
