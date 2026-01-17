import SwiftUI
import ARKit
import RealityKit
import Combine
import simd

// MARK: - App Entry Point

@main
struct OfficeLocalizerApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            TabView {
                ScannerView()
                    .tabItem {
                        Label("Scan", systemImage: "viewfinder")
                    }
                
                LocalizerView()
                    .tabItem {
                        Label("Locate", systemImage: "location.fill")
                    }
            }
        }
    }
}

// MARK: - Camera Pose

struct CameraPose {
    let timestamp: TimeInterval
    let position: SIMD3<Float>  // (x, y, z) in meters
    let rotation: simd_quatf     // quaternion
    let eulerAngles: SIMD3<Float> // (pitch, yaw, roll) in radians
    let confidence: Confidence
    
    enum Confidence: String {
        case high, medium, low, notAvailable
    }
    
    var positionString: String {
        String(format: "(%.2f, %.2f, %.2f)", position.x, position.y, position.z)
    }
    
    var rotationString: String {
        String(format: "Y:%.1f° P:%.1f°", 
               eulerAngles.y * 180 / .pi,
               eulerAngles.x * 180 / .pi)
    }
    
    init(from frame: ARFrame) {
        let camera = frame.camera
        let t = camera.transform
        
        self.timestamp = frame.timestamp
        self.position = SIMD3(t.columns.3.x, t.columns.3.y, t.columns.3.z)
        self.eulerAngles = SIMD3(camera.eulerAngles.x, camera.eulerAngles.y, camera.eulerAngles.z)
        
        let rotMatrix = simd_float3x3(
            SIMD3(t.columns.0.x, t.columns.0.y, t.columns.0.z),
            SIMD3(t.columns.1.x, t.columns.1.y, t.columns.1.z),
            SIMD3(t.columns.2.x, t.columns.2.y, t.columns.2.z)
        )
        self.rotation = simd_quatf(rotMatrix)
        
        switch camera.trackingState {
        case .normal: self.confidence = .high
        case .limited(let reason):
            self.confidence = (reason == .initializing || reason == .relocalizing) ? .medium : .low
        case .notAvailable: self.confidence = .notAvailable
        }
    }
}

// MARK: - World Map Manager

class WorldMapManager: ObservableObject {
    @Published var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    
    private let fileManager = FileManager.default
    
    var mapsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("ARMaps")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    func saveMap(from session: ARSession, name: String) async throws {
        let worldMap = try await session.currentWorldMap()
        let data = try NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true)
        let url = mapsDirectory.appendingPathComponent("\(name).arworldmap")
        try data.write(to: url)
        print("✅ Saved map: \(name) (\(worldMap.anchors.count) anchors)")
    }
    
    func loadMap(name: String, into session: ARSession) throws {
        let url = mapsDirectory.appendingPathComponent("\(name).arworldmap")
        let data = try Data(contentsOf: url)
        guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw NSError(domain: "WorldMap", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid map"])
        }
        
        let config = ARWorldTrackingConfiguration()
        config.initialWorldMap = worldMap
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        print("📍 Loaded map: \(name)")
    }
    
    func listMaps() -> [String] {
        (try? fileManager.contentsOfDirectory(at: mapsDirectory, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "arworldmap" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted() ?? []
    }
    
    func deleteMap(name: String) {
        try? fileManager.removeItem(at: mapsDirectory.appendingPathComponent("\(name).arworldmap"))
        try? fileManager.removeItem(at: mapsDirectory.appendingPathComponent("\(name).pointcloud.json"))
        try? fileManager.removeItem(at: mapsDirectory.appendingPathComponent("\(name).pois.json"))
        try? fileManager.removeItem(at: mapsDirectory.appendingPathComponent("\(name).navgraph.json"))
    }
}

// MARK: - Extensions

extension ARFrame.WorldMappingStatus {
    var description: String {
        switch self {
        case .notAvailable: return "Not Available"
        case .limited: return "Limited"
        case .extending: return "Extending"
        case .mapped: return "Mapped ✓"
        @unknown default: return "Unknown"
        }
    }
    
    var canSave: Bool { self == .mapped || self == .extending }
    
    var color: Color {
        switch self {
        case .notAvailable: return .red
        case .limited: return .orange
        case .extending: return .yellow
        case .mapped: return .green
        @unknown default: return .gray
        }
    }
}

extension ARCamera.TrackingState {
    var description: String {
        switch self {
        case .notAvailable: return "Not Available"
        case .limited(.initializing): return "Initializing"
        case .limited(.relocalizing): return "Relocalizing"
        case .limited(.excessiveMotion): return "Move Slower"
        case .limited(.insufficientFeatures): return "Low Features"
        case .limited: return "Limited"
        case .normal: return "Tracking"
        }
    }
}
