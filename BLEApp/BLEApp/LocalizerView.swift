import SwiftUI
import ARKit
import RealityKit

/*
 Quick use:
 - Scan tab: record a map, feature-point cloud, and POIs; save as <name>. arworldmap + sidecar JSON files.
 - Extend: pick an existing map, relocalize, keep scanning to grow the point cloud, add/update POIs, then save to overwrite.
 - Locate tab: load the map, wait for relocalization, and view the stored point cloud + POIs on the mini-map with your current pose.
 */

// MARK: - Localizer View

struct LocalizerView: View {
    @StateObject private var viewModel = LocalizerViewModel()
    @State private var showingMapPicker = false
    
    var body: some View {
        ZStack {
            LocalizerARView(viewModel: viewModel)
                .ignoresSafeArea()
            
            VStack {
                // Top status
                HStack {
                    Circle()
                        .fill(viewModel.mappingStatus.color)
                        .frame(width: 10, height: 10)
                    Text(viewModel.mappingStatus.description)
                        .font(.subheadline)
                    
                    Divider().frame(height: 12)
                    
                    Text(viewModel.trackingState.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let featureCount = viewModel.featureCount {
                        Divider().frame(height: 12)
                        Text("Frame pts: \(featureCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider().frame(height: 12)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Stored pts: \(viewModel.storedPointCount)")
                            .font(.caption)
                        if let size = viewModel.pointCloudFileSize {
                            Text("(\(size / 1024) KB)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button { showingMapPicker = true } label: {
                        HStack {
                            Image(systemName: "map")
                            Text(viewModel.loadedMapName ?? "Select Map")
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Relocalization prompt
                if !viewModel.isRelocalized && viewModel.loadedMapName != nil {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Relocalizing...")
                            .font(.headline)
                        Text("Point camera at a scanned area")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                
                if let message = viewModel.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Position display
                if viewModel.isRelocalized, let pose = viewModel.currentPose {
                    VStack(spacing: 12) {
                        HStack(spacing: 24) {
                            // Position
                            VStack(alignment: .leading, spacing: 4) {
                                Text("POSITION").font(.caption).foregroundColor(.secondary)
                                HStack(spacing: 16) {
                                    AxisView(axis: "X", value: pose.position.x, color: .red)
                                    AxisView(axis: "Y", value: pose.position.y, color: .green)
                                    AxisView(axis: "Z", value: pose.position.z, color: .blue)
                                }
                            }
                            
                            Divider().frame(height: 50)
                            
                            // Rotation
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ROTATION").font(.caption).foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "Yaw: %.1f°", pose.eulerAngles.y * 180 / .pi))
                                    Text(String(format: "Pitch: %.1f°", pose.eulerAngles.x * 180 / .pi))
                                }
                                .font(.system(.caption, design: .monospaced))
                            }
                        }
                        
                        HStack {
                            Text("Confidence:").font(.caption).foregroundColor(.secondary)
                            Text(pose.confidence.rawValue.capitalized)
                                .font(.caption).fontWeight(.medium)
                                .foregroundColor(confidenceColor(pose.confidence))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if viewModel.loadedMapName == nil {
                    Text("Select a map to start localizing")
                        .foregroundColor(.secondary)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                if let mapName = viewModel.loadedMapName {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Map View")
                                .font(.headline)
                            Spacer()
                            Text("POIs: \(viewModel.pois.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Stored cloud: \(viewModel.storedPointCount)")
                                .font(.caption)
                            if let size = viewModel.pointCloudFileSize {
                                Text("(\(size / 1024) KB)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(viewModel.isRelocalized ? "Relocalized" : "Not relocalized")
                                .font(.caption)
                                .foregroundColor(viewModel.isRelocalized ? .green : .red)
                        }
                        
                        MiniMapView(
                            graph: NavGraph(),
                            route: [],
                            featurePoints: viewModel.pointCloud,
                            pois: viewModel.pois,
                            userPosition: viewModel.isRelocalized ? viewModel.currentPose?.position : nil
                        )
                        
                        if viewModel.pois.isEmpty {
                            Text("No POIs saved for \(mapName). Add them in the Scan tab.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(viewModel.pois) { poi in
                                    Text(poi.name)
                                        .font(.caption)
                                        .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-load most recent map
            if let first = viewModel.mapManager.listMaps().first {
                viewModel.loadMap(name: first)
            }
        }
        .sheet(isPresented: $showingMapPicker) {
            MapPickerView(viewModel: viewModel)
        }
    }
    
    func confidenceColor(_ conf: CameraPose.Confidence) -> Color {
        switch conf {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        case .notAvailable: return .red
        }
    }
}

// MARK: - Axis Display

struct AxisView: View {
    let axis: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(axis).font(.caption2).foregroundColor(color)
            Text(String(format: "%.2f", value))
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
        }
    }
}

// MARK: - Localizer AR View

struct LocalizerARView: UIViewRepresentable {
    @ObservedObject var viewModel: LocalizerViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        arView.debugOptions = [.showWorldOrigin]
        viewModel.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: LocalizerViewModel
        init(viewModel: LocalizerViewModel) { self.viewModel = viewModel }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor in
                viewModel.handleFrame(frame)
            }
        }
    }
}

// MARK: - Localizer View Model

@MainActor
class LocalizerViewModel: ObservableObject {
    @Published var isRelocalized = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published var currentPose: CameraPose?
    @Published var loadedMapName: String?
    @Published var pois: [POI] = []
    @Published var featureCount: Int?
    @Published var pointCloud: [SIMD3<Float>] = []
    @Published var storedPointCount: Int = 0
    @Published var pointCloudFileSize: Int?
    @Published var statusMessage: String?
    
    let mapManager = WorldMapManager()
    let navStore = NavigationDataStore()
    let pointStore = PointCloudStore()
    var arView: ARView?
    private var stableRelocalizationFrames = 0
    private var expectsRelocalization = false
    
    func handleFrame(_ frame: ARFrame) {
        currentPose = CameraPose(from: frame)
        trackingState = frame.camera.trackingState
        mappingStatus = frame.worldMappingStatus
        featureCount = frame.rawFeaturePoints?.points.count
        updateRelocalizationState()
    }
    
    func loadMap(name: String) {
        guard let arView = arView else { return }
        do {
            try mapManager.loadMap(name: name, into: arView.session)
            loadedMapName = name
            expectsRelocalization = true
            stableRelocalizationFrames = 0
            isRelocalized = false
            statusMessage = "Loaded map \(name). Look around to relocalize."
            loadData(for: name)
        } catch {
            statusMessage = "❌ Failed to load map: \(error.localizedDescription)"
        }
    }
    
    func loadData(for mapName: String) {
        pois = navStore.loadPOIs(mapName: mapName)
        pointCloud = pointStore.load(mapName: mapName)
        storedPointCount = pointCloud.count
        pointCloudFileSize = pointStore.fileSizeBytes(mapName: mapName)
    }
    
    private func updateRelocalizationState() {
        guard expectsRelocalization else { return }
        if case .normal = trackingState, mappingStatus != .notAvailable {
            stableRelocalizationFrames += 1
        } else {
            stableRelocalizationFrames = 0
        }
        if stableRelocalizationFrames > 10 {
            isRelocalized = true
            expectsRelocalization = false
            statusMessage = "Relocalized. Move around to view POIs and cloud."
        }
    }
}

// MARK: - Map Picker View

struct MapPickerView: View {
    @ObservedObject var viewModel: LocalizerViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let maps = viewModel.mapManager.listMaps()
                if maps.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map").font(.largeTitle).foregroundColor(.secondary)
                        Text("No maps available").font(.headline)
                        Text("Use Scanner to map your space first").font(.subheadline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    ForEach(maps, id: \.self) { name in
                        Button {
                            viewModel.loadMap(name: name)
                            dismiss()
                        } label: {
                            HStack {
                                Text(name).foregroundColor(.primary)
                                Spacer()
                                if viewModel.loadedMapName == name {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Map")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
