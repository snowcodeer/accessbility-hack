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
    @StateObject private var navigationService: NavigationService
    @StateObject private var voiceCommandService: VoiceCommandService
    @State private var showingMapPicker = false
    @State private var showingAddPOI = false
    @State private var newPOIName = "POI 1"
    @AppStorage("selectedMapName") private var sharedMapName: String = "office"

    init(bluetoothManager: BluetoothManager) {
        let navService = NavigationService(bluetoothManager: bluetoothManager)
        _navigationService = StateObject(wrappedValue: navService)
        _voiceCommandService = StateObject(wrappedValue: VoiceCommandService(navigationService: navService))
    }

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
                
                Divider().frame(height: 12)
                Text("Map: \(viewModel.loadedMapName ?? "none")")
                    .font(.caption)
                    
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
                        Text("Path pts: \(viewModel.storedPathCount)")
                            .font(.caption2)
                    }
                    
                    Spacer()

                    // Voice command toggle
                    Button {
                        if voiceCommandService.isListening {
                            voiceCommandService.stopListening()
                        } else {
                            voiceCommandService.startListening()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: !voiceCommandService.isListening ? "mic.slash.fill" :
                                             (voiceCommandService.listeningForCommand ? "waveform" : "mic.fill"))
                                .foregroundColor(!voiceCommandService.isListening ? .gray :
                                               (voiceCommandService.listeningForCommand ? .red : .blue))
                            Text(!voiceCommandService.isListening ? "Muted" :
                                (voiceCommandService.listeningForCommand ? "Command" : "Wake word"))
                                .font(.caption2)
                        }
                    }

                    // Wake word detection indicator
                    if voiceCommandService.wakeWordDetected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("BEACON")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

                // Voice command debug info
                if voiceCommandService.isListening {
                    VStack(alignment: .leading, spacing: 4) {
                        if !voiceCommandService.lastRecognizedText.isEmpty {
                            Text("Heard: \(voiceCommandService.lastRecognizedText)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if !voiceCommandService.lastCommandResult.isEmpty {
                            Text("Result: \(voiceCommandService.lastCommandResult)")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }

                // Servo debug info
                if navigationService.isNavigating && !navigationService.lastServoCommand.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Servo: \(navigationService.lastServoCommand)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("BLE: \(navigationService.bleDeviceName)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
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
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Map View")
                                    .font(.headline)
                                Spacer()
                                Text("POIs: \(viewModel.pois.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        
                        if viewModel.isRelocalized {
                            Button {
                                newPOIName = viewModel.defaultPOIName()
                                showingAddPOI = true
                            } label: {
                                Label("Add POI (here)", systemImage: "plus.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            // Navigation Controls
                            if !viewModel.pois.isEmpty {
                                NavigationControlsView(
                                    viewModel: viewModel,
                                    navigationService: navigationService
                                )
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
                            Text(viewModel.isRelocalized ? "Relocalized" : "Not relocalized")
                                .font(.caption)
                                .foregroundColor(viewModel.isRelocalized ? .green : .red)
                        }
                        
                        Text(viewModel.poiFileInfoText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(viewModel.pathFileInfoText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        MiniMapView(
                            graph: NavGraph(),
                            route: [],
                            featurePoints: viewModel.pointCloud,
                            pois: viewModel.pois,
                            pathPoints: viewModel.pathPoints,
                            userPosition: viewModel.isRelocalized ? viewModel.currentPose?.position : nil
                        )
                        
                        if viewModel.pois.isEmpty {
                            Text("No POIs saved for \(mapName). Add them in the Scan tab.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(viewModel.pois) { poi in
                                    HStack {
                                        Text(poi.name)
                                            .font(.caption)
                                        Spacer()
                                        if viewModel.isRelocalized {
                                            Button {
                                                guard let pose = viewModel.currentPose else { return }
                                                navigationService.startNavigation(
                                                    from: pose.position,
                                                    to: poi,
                                                    graph: viewModel.loadedGraph
                                                )
                                            } label: {
                                                Image(systemName: "arrow.right.circle")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                        }
                        .padding()
                    }
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding()
        }
        .onAppear {
            // Connect navigation service to viewModel
            viewModel.navigationService = navigationService

            // Connect voice command service
            voiceCommandService.setViewModel(viewModel)
            voiceCommandService.requestAuthorization()

            // Auto-load most recent map, or refresh POIs/cloud for current map when returning to this tab.
            if let current = viewModel.loadedMapName {
                viewModel.loadData(for: current)
            } else {
                let initial = sharedMapName.isEmpty ? viewModel.mapManager.listMaps().first : sharedMapName
                if let name = initial {
                    viewModel.loadMap(name: name)
                    sharedMapName = name
                }
            }
        }
        .onDisappear {
            // Stop listening when leaving the view
            voiceCommandService.stopListening()
        }
        .sheet(isPresented: $showingMapPicker) {
            MapPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddPOI) {
            AddPOIInLocateView(newPOIName: $newPOIName) { name in
                viewModel.addPOI(name: name)
            }
        }
        .onDisappear {
            viewModel.persistPOIsIfNeeded()
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
        private let lock = NSLock()
        private var isProcessingFrame = false  // Throttle frame processing

        init(viewModel: LocalizerViewModel) { self.viewModel = viewModel }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Skip frame if we're still processing the previous one (thread-safe check)
            lock.lock()
            guard !isProcessingFrame else {
                lock.unlock()
                return
            }
            isProcessingFrame = true
            lock.unlock()

            // Extract data from frame synchronously to avoid retaining ARFrame
            let pose = CameraPose(from: frame)
            let trackingState = frame.camera.trackingState
            let mappingStatus = frame.worldMappingStatus
            let featureCount = frame.rawFeaturePoints?.points.count

            // Use DispatchQueue instead of Task to avoid frame retention
            DispatchQueue.main.async { [weak self, weak viewModel] in
                defer {
                    self?.lock.lock()
                    self?.isProcessingFrame = false
                    self?.lock.unlock()
                }
                viewModel?.handleFrameData(
                    pose: pose,
                    trackingState: trackingState,
                    mappingStatus: mappingStatus,
                    featureCount: featureCount
                )
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
    @Published var pathPoints: [SIMD3<Float>] = []
    @Published var storedPathCount: Int = 0
    @Published var poiFileInfoText: String = ""
    @Published var pathFileInfoText: String = ""
    @Published var loadedGraph: NavGraph = NavGraph()

    let mapManager = WorldMapManager()
    let navStore = NavigationDataStore()
    let pointStore = PointCloudStore()
    var arView: ARView?
    private var stableRelocalizationFrames = 0
    private var expectsRelocalization = false
    var navigationService: NavigationService?
    
    func defaultPOIName() -> String {
        "POI \(pois.count + 1)"
    }
    
    func handleFrameData(pose: CameraPose, trackingState: ARCamera.TrackingState, mappingStatus: ARFrame.WorldMappingStatus, featureCount: Int?) {
        currentPose = pose
        self.trackingState = trackingState
        self.mappingStatus = mappingStatus
        self.featureCount = featureCount
        updateRelocalizationState()

        // Forward pose to navigation service
        navigationService?.updateWithPose(pose)
    }
    
    func loadMap(name: String) {
        guard let arView = arView else { return }

        // Clear old data first
        pois = []
        pointCloud = []
        pathPoints = []
        loadedGraph = NavGraph()

        do {
            try mapManager.loadMap(name: name, into: arView.session)
            loadedMapName = name
            UserDefaults.standard.set(name, forKey: "selectedMapName")
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
        pathPoints = navStore.loadPath(mapName: mapName)
        loadedGraph = navStore.loadGraph(mapName: mapName)
        storedPointCount = pointCloud.count
        storedPathCount = pathPoints.count
        pointCloudFileSize = pointStore.fileSizeBytes(mapName: mapName)
        updateFileInfo(mapName: mapName)
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
    
    func addPOI(name: String) {
        guard let mapName = loadedMapName else {
            statusMessage = "Load a map before adding POIs."
            return
        }
        guard let position = floorSnappedPosition() else {
            statusMessage = "Need current pose to add POI."
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? defaultPOIName() : trimmed
        pois.append(POI(name: finalName, position: position))
        navStore.savePOIs(pois, mapName: mapName)
        UserDefaults.standard.set(mapName, forKey: "selectedMapName")
        updateFileInfo(mapName: mapName)
        // Reload to ensure on-disk persistence is reflected in-memory
        loadData(for: mapName)
        statusMessage = "Saved POI \"\(finalName)\" to \(mapName)"
    }
    
    func persistPOIsIfNeeded() {
        guard let mapName = loadedMapName else { return }
        navStore.savePOIs(pois, mapName: mapName)
        updateFileInfo(mapName: mapName)
    }
    
    private func floorSnappedPosition() -> SIMD3<Float>? {
        guard let arView = arView, let frame = arView.session.currentFrame else {
            return currentPose?.position
        }
        let cameraTransform = frame.camera.transform
        let origin = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let downward = SIMD3<Float>(0, -1, 0)
        let query = ARRaycastQuery(origin: origin, direction: downward, allowing: .estimatedPlane, alignment: .horizontal)
        if let result = arView.session.raycast(query).first {
            let transform = result.worldTransform
            return SIMD3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        }
        return origin
    }
    
    private func updateFileInfo(mapName: String) {
        let poiInfo = navStore.poiFileInfo(mapName: mapName)
        let path = "\(mapName).pois.json"
        if poiInfo.exists {
            if let size = poiInfo.size {
                poiFileInfoText = "\(path): \(size / 1024) KB"
            } else {
                poiFileInfoText = "\(path): exists"
            }
        } else {
            poiFileInfoText = "\(path): missing"
        }
        
        let pathInfo = navStore.pathFileInfo(mapName: mapName)
        let pathFile = "\(mapName).path.json"
        if pathInfo.exists {
            if let size = pathInfo.size {
                pathFileInfoText = "\(pathFile): \(size / 1024) KB"
            } else {
                pathFileInfoText = "\(pathFile): exists"
            }
        } else {
            pathFileInfoText = "\(pathFile): missing"
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

struct AddPOIInLocateView: View {
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
