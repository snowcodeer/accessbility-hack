import SwiftUI
import simd

// MARK: - Navigation Controls View

struct NavigationControlsView: View {
    @ObservedObject var viewModel: LocalizerViewModel
    @ObservedObject var navigationService: NavigationService

    var body: some View {
        VStack(spacing: 12) {
            if navigationService.isNavigating {
                NavigationActiveView(service: navigationService)
            } else {
                POISelectionView(
                    pois: viewModel.pois,
                    onSelect: { poi in
                        guard let pose = viewModel.currentPose else { return }
                        navigationService.startNavigation(
                            from: pose.position,
                            to: poi,
                            graph: viewModel.loadedGraph
                        )
                    }
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - POI Selection View

struct POISelectionView: View {
    let pois: [POI]
    let onSelect: (POI) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "signpost.right.fill")
                    .font(.title3)
                Text("Navigate to")
                    .font(.headline)
                Spacer()
            }

            if pois.isEmpty {
                Text("No POIs available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(pois) { poi in
                            Button {
                                onSelect(poi)
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.title2)
                                    Text(poi.name)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Navigation Active View

struct NavigationActiveView: View {
    @ObservedObject var service: NavigationService

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let destination = service.destination {
                        Text("Navigating to")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(destination.name)
                            .font(.headline)
                    }
                }
                Spacer()
                Button {
                    service.stopNavigation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }

            Divider()

            // Progress info
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Distance")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(service.distanceToDestination)) m")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Waypoint")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(service.currentWaypointIndex + 1) / \(service.waypoints.count)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }

                if !service.lastGuidanceMessage.isEmpty {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                        Text(service.lastGuidanceMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }

            // Cancel button
            Button {
                service.stopNavigation()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Navigation")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.2))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Navigation Status Bar (Compact)

struct NavigationStatusBar: View {
    @ObservedObject var service: NavigationService

    var body: some View {
        if service.isNavigating {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)

                if let destination = service.destination {
                    Text("→ \(destination.name)")
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                Text("\(Int(service.distanceToDestination))m")
                    .font(.caption)
                    .fontWeight(.semibold)

                Button {
                    service.stopNavigation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
