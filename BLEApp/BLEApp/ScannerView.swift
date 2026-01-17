import SwiftUI
import ARKit
import RealityKit

// MARK: - Scanner View

struct ScannerView: View {
    @StateObject private var viewModel = ScannerViewModel()
    @AppStorage("selectedMapName") private var mapName: String = "office"
    @State private var showingSaveAlert = false
    @State private var showingMapsList = false
    @State private var showStatus = false
    @State private var showPosition = false
    @State private var showActions = false
    @State private var showNavigation = false
    @State private var showingExtendMapPicker = false
    @State private var showingPOISheet = false
    @State private var showingAddPOI = false
    @State private var newPOIName = "Office 1"
    @State private var showingClearGraphConfirm = false

    var body: some View {
        ZStack {
            ScannerARView(viewModel: viewModel)
                .ignoresSafeArea()

            VStack(spacing: 8) {
                // Compact header
                HStack(spacing: 12) {
                    Circle()
                        .fill(viewModel.mappingStatus.color)
                        .frame(width: 10, height: 10)
                    Text(viewModel.mappingStatus.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Button { showingSaveAlert = true } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                    }
                    .disabled(!viewModel.mappingStatus.canSave)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showStatus.toggle()
                        }
                    } label: {
                        Image(systemName: showStatus ? "chevron.up.circle.fill" : "info.circle")
                            .font(.title3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                // Relocalization warning
                if viewModel.isExtendingExistingMap && !viewModel.isRelocalized {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Relocalizing...")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Look around to find existing features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                // Status details dropdown
                if showStatus {
                    VStack(spacing: 8) {
                        HStack {
                            if let count = viewModel.featureCount {
                                Text("Frame pts: \(count)")
                                    .font(.caption)
                            }
                            Spacer()
                            Text("Cloud: \(viewModel.storedPointCount)")
                                .font(.caption)
                            if let size = viewModel.pointCloudFileSize {
                                Text("(\(size / 1024) KB)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        HStack {
                            Text("POIs: \(viewModel.pois.count)")
                                .font(.caption)
                            Spacer()
                            Text("Nodes: \(viewModel.navGraph.nodes.count)")
                                .font(.caption)
                        }
                        Text(scanTip)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Bottom controls - collapsible sections
                VStack(spacing: 8) {
                    // Position toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPosition.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                            Text("Position")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: showPosition ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    if showPosition, let pose = viewModel.currentPose {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Position").font(.caption2).foregroundColor(.secondary)
                                Text(pose.positionString).font(.system(.caption, design: .monospaced))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Rotation").font(.caption2).foregroundColor(.secondary)
                                Text(pose.rotationString).font(.system(.caption, design: .monospaced))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Actions toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showActions.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Actions")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: showActions ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    if showActions {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Button { showingMapsList = true } label: {
                                    Label("Maps", systemImage: "map")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button { showingExtendMapPicker = true } label: {
                                    Label("Extend", systemImage: "arrow.triangle.branch")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button { viewModel.addAnchor() } label: {
                                    Label("Anchor", systemImage: "mappin")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button { viewModel.reset() } label: {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .tint(.red)
                            }

                            Text("Debug Anchor adds an ARAnchor marker saved into the map")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Navigation toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNavigation.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.isRecordingCorridor ? "record.circle" : "point.3.connected.trianglepath.dotted")
                            Text("Navigation")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if viewModel.isRecordingCorridor {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 8, height: 8)
                            }
                            Spacer()
                            Text("\(viewModel.navGraph.nodes.count)N • \(viewModel.navGraph.edges.count)E")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Image(systemName: showNavigation ? "chevron.up" : "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    if showNavigation {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                Button {
                                    if viewModel.isRecordingCorridor {
                                        viewModel.stopCorridorRecording()
                                    } else {
                                        viewModel.startCorridorRecording(mapName: mapName)
                                    }
                                } label: {
                                    Label(viewModel.isRecordingCorridor ? "Stop" : "Record",
                                          systemImage: viewModel.isRecordingCorridor ? "stop.circle" : "record.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .tint(viewModel.isRecordingCorridor ? .red : .blue)

                                Button { showingClearGraphConfirm = true } label: {
                                    Label("Clear", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button {
                                    newPOIName = viewModel.defaultPOIName()
                                    showingAddPOI = true
                                } label: {
                                    Label("Add POI", systemImage: "plus.circle")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                                Button { showingPOISheet = true } label: {
                                    Label("POIs", systemImage: "list.bullet")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            if viewModel.isRecordingCorridor {
                                Text("Recording corridors... walk ~1 m between samples")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
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
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Map: \(mapName)")
                    .font(.caption2)
                Text(viewModel.poiFileInfoText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
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
    @Published var pathPoints: [SIMD3<Float>] = []
    @Published var storedPathCount: Int = 0
    @Published var poiFileInfoText: String = ""
    
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
    
    private func updatePOIFileInfo(for mapName: String) {
        let info = navStore.poiFileInfo(mapName: mapName)
        let path = "\(mapName).pois.json"
        if info.exists {
            if let size = info.size {
                poiFileInfoText = "\(path): \(size / 1024) KB"
            } else {
                poiFileInfoText = "\(path): exists"
            }
        } else {
            poiFileInfoText = "\(path): missing"
        }
    }
    
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
        pathPoints = navStore.loadPath(mapName: mapName)
        storedPathCount = pathPoints.count
        updatePOIFileInfo(for: mapName)
    }
    
    func saveMap(name: String) async {
        guard let session = arView?.session else { return }
        do {
            try await mapManager.saveMap(from: session, name: name)
            // Merge disk + memory POIs to avoid overwriting Locate-created POIs.
            let diskPOIs = navStore.loadPOIs(mapName: name)
            let mergedPOIs = mergePOIs(memory: pois, disk: diskPOIs)
            pois = mergedPOIs
            pointStore.save(points: collector.points, mapName: name)
            navStore.savePOIs(mergedPOIs, mapName: name)
            navStore.savePath(pathPoints, mapName: name)
            pointCloudFileSize = pointStore.fileSizeBytes(mapName: name)
            storedPointCount = collector.count
            storedPathCount = pathPoints.count
            statusMessage = "Saved map \"\(name)\" (\(storedPointCount) pts, \(pois.count) POIs)"
            updatePOIFileInfo(for: name)
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
        updatePOIFileInfo(for: mapName)
    }
    
    func deletePOI(_ poi: POI, mapName: String) {
        pois.removeAll(where: { $0.id == poi.id })
        navStore.savePOIs(pois, mapName: mapName)
        updatePOIFileInfo(for: mapName)
    }
    
    func renamePOI(_ poi: POI, newName: String, mapName: String) {
        guard let index = pois.firstIndex(where: { $0.id == poi.id }) else { return }
        pois[index].name = newName
        navStore.savePOIs(pois, mapName: mapName)
        updatePOIFileInfo(for: mapName)
    }
    
    func movePOIToCurrentPosition(_ poi: POI, mapName: String) {
        guard let newPosition = currentFloorPosition(),
              let index = pois.firstIndex(where: { $0.id == poi.id }) else { return }
        pois[index].position = newPosition
        navStore.savePOIs(pois, mapName: mapName)
        updatePOIFileInfo(for: mapName)
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
            updatePOIFileInfo(for: mapName)
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
        appendPathSample(position)
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
    
    private func appendPathSample(_ position: SIMD3<Float>) {
        if let last = pathPoints.last, simd_distance(last, position) < 0.3 { return }
        pathPoints.append(position)
        storedPathCount = pathPoints.count
        if let map = recordingMapName {
            navStore.savePath(pathPoints, mapName: map)
        }
    }
    
    private func mergePOIs(memory: [POI], disk: [POI]) -> [POI] {
        var dict: [UUID: POI] = [:]
        for poi in disk { dict[poi.id] = poi }
        for poi in memory { dict[poi.id] = poi } // in-memory edits win
        return Array(dict.values)
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
