//
//  ARViewContainer.swift
//  BLEApp
//

import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ARViewRepresentable()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()

                // AR Instructions
                VStack(spacing: 8) {
                    Text("AR View Active")
                        .font(.headline)
                    Text("Move your device to detect surfaces")
                        .font(.caption)
                }
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - ARViewRepresentable
struct ARViewRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic

        // Enable people occlusion if available (iPhone 12+)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            configuration.frameSemantics.insert(.personSegmentationWithDepth)
        }

        arView.session.run(configuration)

        // Add tap gesture to place objects
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)

        context.coordinator.arView = arView

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Update view if needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator
    class Coordinator {
        weak var arView: ARView?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView else { return }

            let location = gesture.location(in: arView)

            // Perform raycast to find real-world surface
            if let result = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first {
                // Create a simple sphere at the tapped location
                let sphere = ModelEntity(
                    mesh: .generateSphere(radius: 0.05),
                    materials: [SimpleMaterial(color: .systemBlue, isMetallic: true)]
                )

                // Create anchor at the raycast result position
                let anchor = AnchorEntity(world: result.worldTransform)
                anchor.addChild(sphere)
                arView.scene.addAnchor(anchor)

                print("Placed object at: \(result.worldTransform.columns.3)")
            }
        }
    }
}

// MARK: - Preview
struct ARViewContainer_Previews: PreviewProvider {
    static var previews: some View {
        ARViewContainer()
    }
}
