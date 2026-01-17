import SwiftUI
import ARKit
import RealityKit

// MARK: - Scanner View

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @State private var mapName = "office"
    @State private var showingSaveAlert = false
    @State private var showingMapsList = false
    @State private var showingExtendMapPicker = false
    @State private var showingPOISheet = false
    @State private var showingAddPOI = false
    @State private var newPOIName = "Office 1"
    @State private var showingClearGraphConfirm = false
    
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
                            Text("Frame pts: \(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                        Text("POIs: \(viewModel.pois.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(scanTip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                if viewModel.isExtendingExistingMap && !viewModel.isRelocalized {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Extending existing map")
                                .font(.subheadline)
                            Text("Look around to relocalize before capturing new data.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                
                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
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
                        
                        Button {
                            showingExtendMapPicker = true
                        } label: {
                            Label("Extend Map", systemImage: "arrow.triangle.branch")
                        }
                        .buttonStyle(.bordered)
                        
                        Button { viewModel.addAnchor() } label: {
                            Label("Debug Anchor", systemImage: "mappin")
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
                    
                    Text("Debug Anchor adds an ARAnchor + marker saved into the map; helpful to sanity-check relocalization later.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Navigation Setup")
                                .font(.headline)
                            Spacer()
                            Text("\(viewModel.navGraph.nodes.count) nodes • \(viewModel.navGraph.edges.count) edges")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                if viewModel.isRecordingCorridor {
                                    viewModel.stopCorridorRecording()
                                } else {
                                    viewModel.startCorridorRecording(mapName: mapName)
                                }
                            } label: {
                                Label(viewModel.isRecordingCorridor ? "Stop Recording" : "Start Recording",
                                      systemImage: viewModel.isRecordingCorridor ? "stop.circle" : "dot.radiowaves.left.and.right")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(viewModel.isRecordingCorridor ? .red : .blue)
                            
                            Button(role: .destructive) { showingClearGraphConfirm = true } label: {
                                Label("Clear Graph", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                newPOIName = viewModel.defaultPOIName()
                                showingAddPOI = true
                            } label: {
                                Label("Add POI", systemImage: "plus.circle")
                            }
                            .buttonStyle(.bordered)
                            
                            Button { showingPOISheet = true } label: {
                                Label("POIs", systemImage: "list.bullet")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Text("Graph and POIs are saved with map \"\(mapName)\" under Documents/ARMaps.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if viewModel.isRecordingCorridor {
                            Text("Recording corridors... walk ~1 m between samples. Points snap to floor when available.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
            MapsListView(manager: viewModel.mapManager) { name in
                mapName = name
                viewModel.stopCorridorRecording()
                viewModel.isExtendingExistingMap = false
                viewModel.isRelocalized = true
                viewModel.loadNavigationData(mapName: name)
                viewModel.statusMessage = "Loaded data for \(name)."
            }
        }
        .sheet(isPresented: $showingExtendMapPicker) {
            MapsListView(manager: viewModel.mapManager) { name in
                mapName = name
                viewModel.extendExistingMap(named: name)
            }
        }
        .sheet(isPresented: $showingPOISheet) {
            POIListView(viewModel: viewModel, mapName: mapName)
        }
        .sheet(isPresented: $showingAddPOI) {
            AddPOIView(newPOIName: $newPOIName) { name in
                viewModel.addPOI(name: name.isEmpty ? viewModel.defaultPOIName() : name, mapName: mapName)
            }
        }
        .confirmationDialog("Clear navigation graph for \"\(mapName)\"?", isPresented: $showingClearGraphConfirm) {
            Button("Clear Graph", role: .destructive) {
                viewModel.clearGraph(for: mapName)
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            viewModel.loadNavigationData(mapName: mapName)
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
                viewModel.handleFrame(frame)
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
    @Published var navGraph: NavGraph = NavGraph()
    @Published var pois: [POI] = []
    @Published var isRecordingCorridor = false
    @Published var storedPointCount: Int = 0
    @Published var pointCloudFileSize: Int?
    @Published var isExtendingExistingMap = false
    @Published var isRelocalized = true
    @Published var statusMessage: String?
    
    let mapManager = WorldMapManager()
    let navStore = NavigationDataStore()
    let pointStore = PointCloudStore()
    var arView: ARView?
    private var anchorCount = 0
    private var recorder = GraphRecorder(sampleDistance: 1.0, mergeDistance: 1.0, junctionDistance: 1.0)
    private var recordingMapName: String?
    private var collector = PointCloudCollector(cellSize: 0.2, maxPoints: 50_000)
    private var expectsRelocalization = false
    private var stableRelocalizationFrames = 0
    
    func handleFrame(_ frame: ARFrame) {
        mappingStatus = frame.worldMappingStatus
        featureCount = frame.rawFeaturePoints?.points.count
        currentPose = CameraPose(from: frame)
        updateRelocalizationState(using: frame)
        sampleFeaturePoints(from: frame)
        processRecording(frame: frame)
    }
    
    func loadNavigationData(mapName: String) {
        navGraph = navStore.loadGraph(mapName: mapName)
        recorder.reset(with: navGraph)
        pois = navStore.loadPOIs(mapName: mapName)
        let existingPoints = pointStore.load(mapName: mapName)
        collector.reset(with: existingPoints)
        storedPointCount = collector.count
        pointCloudFileSize = pointStore.fileSizeBytes(mapName: mapName)
    }
    
    func saveMap(name: String) async {
        guard let session = arView?.session else { return }
        do {
            try await mapManager.saveMap(from: session, name: name)
            pointStore.save(points: collector.points, mapName: name)
            navStore.savePOIs(pois, mapName: name)
            pointCloudFileSize = pointStore.fileSizeBytes(mapName: name)
            storedPointCount = collector.count
            statusMessage = "Saved map \"\(name)\" (\(storedPointCount) pts)"
        } catch {
            statusMessage = "Failed to save map: \(error.localizedDescription)"
        }
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
        stopCorridorRecording()
        isExtendingExistingMap = false
        isRelocalized = true
        expectsRelocalization = false
        stableRelocalizationFrames = 0
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        anchorCount = 0
        collector.reset()
        storedPointCount = collector.count
        pointCloudFileSize = nil
        statusMessage = nil
    }
    
    func startCorridorRecording(mapName: String) {
        guard let arView = arView, let frame = arView.session.currentFrame else { return }
        recorder.reset(with: navGraph)
        recordingMapName = mapName
        isRecordingCorridor = true
        if let pos = floorSnappedPosition(frame: frame) {
            if recorder.addSample(position: pos) {
                navGraph = recorder.graph
                navStore.saveGraph(navGraph, mapName: mapName)
            }
        }
    }
    
    func stopCorridorRecording() {
        recordingMapName = nil
        isRecordingCorridor = false
    }
    
    func clearGraph(for mapName: String) {
        navGraph = NavGraph()
        recorder.reset(with: navGraph)
        navStore.saveGraph(navGraph, mapName: mapName)
    }
    
    func addPOI(name: String, mapName: String) {
        guard let position = currentFloorPosition() else { return }
        pois.append(POI(name: name, position: position))
        navStore.savePOIs(pois, mapName: mapName)
    }
    
    func deletePOI(_ poi: POI, mapName: String) {
        pois.removeAll(where: { $0.id == poi.id })
        navStore.savePOIs(pois, mapName: mapName)
    }
    
    func renamePOI(_ poi: POI, newName: String, mapName: String) {
        guard let index = pois.firstIndex(where: { $0.id == poi.id }) else { return }
        pois[index].name = newName
        navStore.savePOIs(pois, mapName: mapName)
    }
    
    func movePOIToCurrentPosition(_ poi: POI, mapName: String) {
        guard let newPosition = currentFloorPosition(),
              let index = pois.firstIndex(where: { $0.id == poi.id }) else { return }
        pois[index].position = newPosition
        navStore.savePOIs(pois, mapName: mapName)
    }
    
    func defaultPOIName() -> String {
        "POI \(pois.count + 1)"
    }
    
    func extendExistingMap(named mapName: String) {
        guard let arView = arView else { return }
        do {
            try mapManager.loadMap(name: mapName, into: arView.session)
            loadNavigationData(mapName: mapName)
            isExtendingExistingMap = true
            isRelocalized = false
            expectsRelocalization = true
            stableRelocalizationFrames = 0
            statusMessage = "Loaded map \(mapName). Look around to relocalize, then keep scanning."
        } catch {
            statusMessage = "Failed to load map for extension: \(error.localizedDescription)"
        }
    }
    
    private func processRecording(frame: ARFrame) {
        guard isRecordingCorridor, let mapName = recordingMapName else { return }
        guard isRelocalized || !isExtendingExistingMap else { return }
        guard let position = floorSnappedPosition(frame: frame) else { return }
        if recorder.addSample(position: position) {
            navGraph = recorder.graph
            navStore.saveGraph(navGraph, mapName: mapName)
        }
    }
    
    private func sampleFeaturePoints(from frame: ARFrame) {
        guard isRelocalized || !isExtendingExistingMap else { return }
        guard let rawPoints = frame.rawFeaturePoints?.points else { return }
        let stride = max(1, rawPoints.count / 400) // downsample per-frame to bound cost
        var sampled: [SIMD3<Float>] = []
        sampled.reserveCapacity(rawPoints.count / stride + 1)
        for (idx, point) in rawPoints.enumerated() where idx % stride == 0 {
            sampled.append(SIMD3(point.x, point.y, point.z))
        }
        collector.ingest(sampled)
        storedPointCount = collector.count
    }
    
    private func updateRelocalizationState(using frame: ARFrame) {
        guard isExtendingExistingMap else { isRelocalized = true; return }
        if case .normal = frame.camera.trackingState, frame.worldMappingStatus != .notAvailable {
            stableRelocalizationFrames += 1
        } else {
            stableRelocalizationFrames = 0
        }
        if stableRelocalizationFrames > 15 {
            isRelocalized = true
            expectsRelocalization = false
            statusMessage = "Relocalized. Continue scanning and add POIs, then save."
        }
    }
    
    private func floorSnappedPosition(frame: ARFrame) -> SIMD3<Float>? {
        guard let arView = arView else { return nil }
        let cameraTransform = frame.camera.transform
        let origin = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let downward = SIMD3<Float>(0, -1, 0)
        // Keep recorded points anchored to the floor plane when possible.
        let query = ARRaycastQuery(origin: origin, direction: downward, allowing: .estimatedPlane, alignment: .horizontal)
        
        if let result = arView.session.raycast(query).first {
            let transform = result.worldTransform
            return SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
        
        return origin
    }
    
    private func currentFloorPosition() -> SIMD3<Float>? {
        guard let arView = arView, let frame = arView.session.currentFrame else { return currentPose?.position }
        return floorSnappedPosition(frame: frame) ?? currentPose?.position
    }
}

// MARK: - POI Management

struct POIListView: View {
    @ObservedObject var viewModel: ScannerViewModel
    let mapName: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.pois.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No POIs yet")
                            .font(.headline)
                        Text("Add a POI from the Scan tab at your current position.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                } else {
                    ForEach(viewModel.pois) { poi in
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("Name", text: Binding(
                                get: { poi.name },
                                set: { newValue in viewModel.renamePOI(poi, newName: newValue, mapName: mapName) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            
                            Text(String(format: "(%.2f, %.2f, %.2f)", poi.position.x, poi.position.y, poi.position.z))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .swipeActions {
                            Button {
                                viewModel.movePOIToCurrentPosition(poi, mapName: mapName)
                            } label: {
                                Label("Move Here", systemImage: "arrow.up.right")
                            }
                            
                            Button(role: .destructive) {
                                viewModel.deletePOI(poi, mapName: mapName)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("POIs (\(mapName))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AddPOIView: View {
    @Binding var newPOIName: String
    var onAdd: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("POI Name")) {
                    TextField("Office 1", text: $newPOIName)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Add POI")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(newPOIName.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Maps List View

struct MapsListView: View {
    @ObservedObject var manager: WorldMapManager
    var onSelect: ((String) -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                let maps = manager.listMaps()
                if maps.isEmpty {
                    Text("No saved maps").foregroundColor(.secondary)
                } else {
                    ForEach(maps, id: \.self) { name in
                        Button {
                            if let onSelect = onSelect {
                                onSelect(name)
                            }
                            dismiss()
                        } label: {
                            HStack {
                                Text(name).foregroundColor(.primary)
                                Spacer()
                                if onSelect != nil {
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
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
