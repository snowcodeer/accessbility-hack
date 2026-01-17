import SwiftUI
import ARKit
import RealityKit

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
                        .fill(trackingColor)
                        .frame(width: 10, height: 10)
                    Text(viewModel.trackingState.description)
                        .font(.subheadline)
                    
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
    
    var trackingColor: Color {
        switch viewModel.trackingState {
        case .normal: return .green
        case .limited: return .yellow
        case .notAvailable: return .red
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
                viewModel.currentPose = CameraPose(from: frame)
                viewModel.trackingState = frame.camera.trackingState
                
                if case .normal = frame.camera.trackingState, !viewModel.isRelocalized {
                    viewModel.isRelocalized = true
                    print("✅ Relocalization successful!")
                }
            }
        }
    }
}

// MARK: - Localizer View Model

@MainActor
class LocalizerViewModel: ObservableObject {
    @Published var isRelocalized = false
    @Published var trackingState: ARCamera.TrackingState = .notAvailable
    @Published var currentPose: CameraPose?
    @Published var loadedMapName: String?
    
    let mapManager = WorldMapManager()
    var arView: ARView?
    
    func loadMap(name: String) {
        guard let arView = arView else { return }
        do {
            try mapManager.loadMap(name: name, into: arView.session)
            loadedMapName = name
            isRelocalized = false
        } catch {
            print("❌ Failed to load map: \(error)")
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
