import Foundation
import simd

/// Persists sampled feature points per map as a compact JSON sidecar (<map>.pointcloud.json).
final class PointCloudStore {
    private let mapManager = WorldMapManager()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private func url(for mapName: String) -> URL {
        mapManager.mapsDirectory.appendingPathComponent("\(mapName).pointcloud.json")
    }
    
    func load(mapName: String) -> [SIMD3<Float>] {
        let url = url(for: mapName)
        guard let data = try? Data(contentsOf: url),
              let arrays = try? decoder.decode([[Float]].self, from: data) else {
            return []
        }
        return arrays.compactMap { $0.count >= 3 ? SIMD3($0[0], $0[1], $0[2]) : nil }
    }
    
    func save(points: [SIMD3<Float>], mapName: String) {
        let arrays = points.map { [$0.x, $0.y, $0.z] }
        guard let data = try? encoder.encode(arrays) else { return }
        try? data.write(to: url(for: mapName), options: [.atomic])
    }
    
    func fileSizeBytes(mapName: String) -> Int? {
        let url = url(for: mapName)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.intValue
    }
}

/// Downsamples/merges ARKit raw feature points into a voxel grid to keep file sizes bounded.
final class PointCloudCollector {
    private struct GridKey: Hashable {
        let x: Int
        let y: Int
        let z: Int
    }
    
    private let cellSize: Float
    private let maxPoints: Int
    private var grid: [GridKey: SIMD3<Float>] = [:]
    
    init(cellSize: Float = 0.2, maxPoints: Int = 50_000) {
        self.cellSize = cellSize
        self.maxPoints = maxPoints
    }
    
    func reset(with existing: [SIMD3<Float>] = []) {
        grid = [:]
        ingest(existing)
    }
    
    func ingest(_ points: [SIMD3<Float>]) {
        guard maxPoints > 0 else { return }
        for point in points {
            let key = gridKey(for: point)
            if grid[key] != nil {
                grid[key] = point // replace with latest sample in the same cell
            } else if grid.count < maxPoints {
                grid[key] = point
            }
        }
    }
    
    var points: [SIMD3<Float>] {
        Array(grid.values)
    }
    
    var count: Int { grid.count }
    
    private func gridKey(for point: SIMD3<Float>) -> GridKey {
        GridKey(
            x: Int(floor(point.x / cellSize)),
            y: Int(floor(point.y / cellSize)),
            z: Int(floor(point.z / cellSize))
        )
    }
}
