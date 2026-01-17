import SwiftUI
import ARKit
import RealityKit

// MARK: - Scanner View

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var mapName = "office"
    @State private var showingSaveAlert = false
    @State private var showingMapsList = false
    
    var body: some View {
        ZStack {
            ScannerARView(viewModel: viewModel)
                .ignoresSafeArea()
            
            VStack {
                // Status bar
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(viewModel.mappingStatus.color)
                            .frame(width: 12, height: 12)
                        Text("Mapping: \(viewModel.mappingStatus.description)")
                            .font(.headline)
                        Spacer()
                        if let count = viewModel.featureCount {
                            Text("\(count) features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(scanTip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Spacer()
                
                // Position display + controls
                VStack(spacing: 16) {
                    if let pose = viewModel.currentPose {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Position").font(.caption).foregroundColor(.secondary)
                                Text(pose.positionString).font(.system(.body, design: .monospaced))
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Rotation").font(.caption).foregroundColor(.secondary)
                                Text(pose.rotationString).font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                    
                    HStack(spacing: 20) {
                        Button { showingMapsList = true } label: {
                            Label("Maps", systemImage: "map")
                        }
                        .buttonStyle(.bordered)
                        
                        Button { viewModel.addAnchor() } label: {
                            Label("Anchor", systemImage: "mappin")
                        }
                        .buttonStyle(.bordered)
                        
                        Button { showingSaveAlert = true } label: {
                            Label("Save", systemImage: "square.and.arrow.down")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.mappingStatus.canSave)
                        
                        Button { viewModel.reset() } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .alert("Save Map", isPresented: $showingSaveAlert) {
            TextField("Map Name", text: $mapName)
            Button("Cancel", role: .cancel) { }
            Button("Save") { Task { await viewModel.saveMap(name: mapName) } }
        }
        .sheet(isPresented: $showingMapsList) {
            MapsListView(manager: viewModel.mapManager)
        }
    }
    
    var scanTip: String {
        switch viewModel.mappingStatus {
        case .notAvailable: return "Point camera at the environment"
        case .limited: return "Move slowly, scan walls and features"
        case .extending: return "Good! Keep scanning to expand coverage"
        case .mapped: return "✓ Ready to save!"
        @unknown default: return ""
        }
    }
}

// MARK: - Scanner AR View

struct ScannerARView: UIViewRepresentable {
    @ObservedObject var viewModel: ScannerViewModel
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        arView.session.delegate = context.coordinator
        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        
        viewModel.arView = arView
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ScannerViewModel
        init(viewModel: ScannerViewModel) { self.viewModel = viewModel }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            Task { @MainActor in
                viewModel.mappingStatus = frame.worldMappingStatus
                viewModel.featureCount = frame.rawFeaturePoints?.points.count
                viewModel.currentPose = CameraPose(from: frame)
            }
        }
    }
}

// MARK: - Scanner View Model

@MainActor
class ScannerViewModel: ObservableObject {
    @Published var mappingStatus: ARFrame.WorldMappingStatus = .notAvailable
    @Published var currentPose: CameraPose?
    @Published var featureCount: Int?
    
    let mapManager = WorldMapManager()
    var arView: ARView?
    private var anchorCount = 0
    
    func saveMap(name: String) async {
        guard let session = arView?.session else { return }
        try? await mapManager.saveMap(from: session, name: name)
    }
    
    func addAnchor() {
        guard let arView = arView, let frame = arView.session.currentFrame else { return }
        
        anchorCount += 1
        let anchor = ARAnchor(name: "anchor-\(anchorCount)", transform: frame.camera.transform)
        arView.session.add(anchor: anchor)
        
        // Visual marker
        let sphere = MeshResource.generateSphere(radius: 0.05)
        let entity = ModelEntity(mesh: sphere, materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.addChild(entity)
        arView.scene.addAnchor(anchorEntity)
    }
    
    func reset() {
        guard let arView = arView else { return }
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        anchorCount = 0
    }
}

// MARK: - Maps List View

struct MapsListView: View {
    @ObservedObject var manager: WorldMapManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let maps = manager.listMaps()
                if maps.isEmpty {
                    Text("No saved maps").foregroundColor(.secondary)
                } else {
                    ForEach(maps, id: \.self) { name in
                        Text(name)
                            .swipeActions {
                                Button(role: .destructive) { manager.deleteMap(name: name) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Saved Maps")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
