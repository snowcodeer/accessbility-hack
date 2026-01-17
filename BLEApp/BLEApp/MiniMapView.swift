import SwiftUI
import simd

/// Lightweight top-down mini-map drawing X/Z positions.
struct MiniMapView: View {
    var graph: NavGraph = NavGraph()
    var route: [SIMD3<Float>] = []
    var featurePoints: [SIMD3<Float>] = []
    var pois: [POI] = []
    var pathPoints: [SIMD3<Float>] = []
    var userPosition: SIMD3<Float>?
    var destination: SIMD3<Float>?
    
    private var allPoints: [SIMD3<Float>] {
        var points = graph.nodes.map { $0.position }
        points.append(contentsOf: route)
        points.append(contentsOf: featurePoints)
        points.append(contentsOf: pois.map { $0.position })
        points.append(contentsOf: pathPoints)
        if let userPosition { points.append(userPosition) }
        if let destination { points.append(destination) }
        return points
    }
    
    private var displayFeaturePoints: [SIMD3<Float>] {
        Array(featurePoints.prefix(5_000)) // lightweight cap for drawing
    }
    
    var body: some View {
        ZStack {
            if allPoints.isEmpty {
                Text("Mini-map appears after a map + point cloud are loaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                GeometryReader { geo in
                    let projector = MiniMapProjector(size: geo.size, points: allPoints)
                    
                    // Feature point cloud
                    Canvas { context, _ in
                        for point in displayFeaturePoints {
                            let cg = projector.project(point)
                            let rect = CGRect(x: cg.x - 1, y: cg.y - 1, width: 2, height: 2)
                            context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(0.5)))
                        }
                    }
                    
                    // Corridor edges (kept if graph is available)
                    Path { path in
                        for edge in graph.edges {
                            if let a = graph.node(id: edge.aNodeID)?.position,
                               let b = graph.node(id: edge.bNodeID)?.position {
                                path.move(to: projector.project(a))
                                path.addLine(to: projector.project(b))
                            }
                        }
                    }
                    .stroke(Color.gray.opacity(0.45), lineWidth: 1)
                    
                    // Route polyline (optional)
                    if route.count > 1 {
                        Path { path in
                            path.move(to: projector.project(route[0]))
                            for point in route.dropFirst() {
                                path.addLine(to: projector.project(point))
                            }
                        }
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    
                    // Walked path overlay
                    if pathPoints.count > 1 {
                        Path { path in
                            path.move(to: projector.project(pathPoints[0]))
                            for point in pathPoints.dropFirst() {
                                path.addLine(to: projector.project(point))
                            }
                        }
                        .stroke(Color.purple.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                    
                    // POI markers
                    ForEach(pois) { poi in
                        let projected = projector.project(poi.position)
                        VStack(spacing: 2) {
                            Text(poi.name)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(4)
                                .background(Color.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        }
                        .position(projected)
                    }
                    
                    // Destination marker (for compatibility with nav)
                    if let destination {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1))
                            .position(projector.project(destination))
                    }
                    
                    // User marker
                    if let userPosition {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .position(projector.project(userPosition))
                    }
                }
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Projection

private struct MiniMapProjector {
    let centerX: Float
    let centerZ: Float
    let spanX: Float
    let spanZ: Float
    let size: CGSize
    private let padding: CGFloat = 16
    
    init(size: CGSize, points: [SIMD3<Float>]) {
        self.size = size
        let xs = points.map { $0.x }
        let zs = points.map { $0.z }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 1
        let minZ = zs.min() ?? 0
        let maxZ = zs.max() ?? 1
        centerX = (minX + maxX) / 2
        centerZ = (minZ + maxZ) / 2
        spanX = max(maxX - minX, 0.5)
        spanZ = max(maxZ - minZ, 0.5)
    }
    
    func project(_ position: SIMD3<Float>) -> CGPoint {
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let scale = min(availableWidth / CGFloat(spanX), availableHeight / CGFloat(spanZ))
        
        let dx = CGFloat(position.x - centerX) * scale
        let dz = CGFloat(position.z - centerZ) * scale
        
        // X right, Z down (camera forward = -Z) for intuitive alignment
        let x = size.width / 2 + dx
        let y = size.height / 2 + dz
        return CGPoint(x: x, y: y)
    }
}
