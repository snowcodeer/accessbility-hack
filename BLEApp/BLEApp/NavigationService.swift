import Foundation
import AVFoundation
import simd

@MainActor
class NavigationService: ObservableObject {
    // MARK: - Dependencies

    private let bluetoothManager: BluetoothManager
    private let planner = AStarPlanner()
    private let speech = AVSpeechSynthesizer()

    // MARK: - Published State

    @Published var isNavigating = false
    @Published var currentWaypointIndex = 0
    @Published var waypoints: [SIMD3<Float>] = []
    @Published var destination: POI?
    @Published var distanceToNextWaypoint: Float = 0
    @Published var distanceToDestination: Float = 0
    @Published var lastGuidanceMessage: String = ""

    // MARK: - Private State

    private var currentPose: CameraPose?
    private var lastServoUpdateTime: TimeInterval = 0
    private var offRouteStartTime: TimeInterval?
    private var lastServoAngle: Int = 90
    private var lastAnnouncedMilestone: Float = Float.infinity

    // MARK: - Configuration

    private let waypointProximityThreshold: Float = 1.5      // meters
    private let offRouteThreshold: Float = 3.0                // meters
    private let servoUpdateInterval: TimeInterval = 1.0       // 1 Hz
    private let servoAngleThreshold: Int = 30                 // degrees

    // MARK: - Initialization

    init(bluetoothManager: BluetoothManager) {
        self.bluetoothManager = bluetoothManager
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord so it's compatible with voice commands when they start
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true, options: [])
            print("✅ Audio session configured for speech synthesis")
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Navigation Lifecycle

    func startNavigation(from currentPosition: SIMD3<Float>, to poi: POI, graph: NavGraph) {
        guard !isNavigating else { return }

        // Plan route using A* planner
        guard let route = planner.planRoute(graph: graph, start: currentPosition, goal: poi.position) else {
            speak("Unable to find route to \(poi.name)")
            return
        }

        self.waypoints = route
        self.destination = poi
        self.currentWaypointIndex = 0
        self.isNavigating = true
        self.offRouteStartTime = nil
        self.lastAnnouncedMilestone = Float.infinity

        // Calculate total distance
        let totalDistance = calculateTotalDistance()

        // Initial announcement
        speak("Navigation started to \(poi.name). Distance: \(Int(totalDistance)) meters")

        // Center servo initially
        setServo(angle: 90)
        lastServoAngle = 90
    }

    func stopNavigation() {
        isNavigating = false
        waypoints = []
        currentWaypointIndex = 0
        destination = nil
        offRouteStartTime = nil
        lastAnnouncedMilestone = Float.infinity

        // Center servo
        setServo(angle: 90)
        lastServoAngle = 90

        speak("Navigation cancelled")
    }

    // MARK: - Pose Updates

    func updateWithPose(_ pose: CameraPose) {
        guard isNavigating else { return }
        guard pose.confidence == .high || pose.confidence == .medium else { return }

        currentPose = pose

        // Update distances
        updateDistances(from: pose.position)

        // Check waypoint proximity
        checkWaypointProximity(position: pose.position)

        // Check if off route
        checkOffRoute(position: pose.position)

        // Check distance milestones
        checkDistanceMilestones()

        // Update servo direction (throttled to 1 Hz with threshold)
        updateServoDirection(pose: pose)
    }

    // MARK: - Direction Calculation

    private func calculateServoAngle(userPosition: SIMD3<Float>,
                                     userYaw: Float,
                                     targetPosition: SIMD3<Float>) -> Int {
        // 1. Vector from user to target (XZ plane only)
        let dx = targetPosition.x - userPosition.x
        let dz = targetPosition.z - userPosition.z

        // 2. Absolute bearing to target (0 = -Z axis, clockwise)
        let targetBearing = atan2(dx, -dz)

        // 3. Relative bearing (target direction relative to user's facing)
        var relativeBearing = targetBearing - userYaw

        // 4. Normalize to [-π, π]
        while relativeBearing > Float.pi { relativeBearing -= 2 * Float.pi }
        while relativeBearing < -Float.pi { relativeBearing += 2 * Float.pi }

        // 5. Convert to degrees and map to servo
        let relativeDegrees = relativeBearing * 180 / Float.pi
        // Clamp to ±90° (front arc only for safety)
        let clampedDegrees = max(-90, min(90, relativeDegrees))
        // IMPORTANT: 90 MINUS clampedDegrees because 0°=right, 180°=left
        let servoAngle = Int(90 - clampedDegrees)

        return max(0, min(180, servoAngle))
    }

    private func updateServoDirection(pose: CameraPose) {
        guard currentWaypointIndex < waypoints.count else { return }

        // Throttle to 1 second intervals
        let now = pose.timestamp
        guard now - lastServoUpdateTime >= servoUpdateInterval else { return }

        let targetWaypoint = waypoints[currentWaypointIndex]
        let newAngle = calculateServoAngle(
            userPosition: pose.position,
            userYaw: pose.eulerAngles.y,
            targetPosition: targetWaypoint
        )

        // Apply 30° threshold - only update on significant changes
        if abs(newAngle - lastServoAngle) >= servoAngleThreshold {
            setServo(angle: newAngle)
            lastServoAngle = newAngle
            lastServoUpdateTime = now
        }
    }

    private func setServo(angle: Int) {
        let clampedAngle = max(0, min(180, angle))
        bluetoothManager.sendText("centre = \(clampedAngle)\r\n")
    }

    // MARK: - Waypoint Progression

    private func checkWaypointProximity(position: SIMD3<Float>) {
        guard currentWaypointIndex < waypoints.count else { return }

        let waypoint = waypoints[currentWaypointIndex]
        let distance = simd_distance(position, waypoint)

        if distance < waypointProximityThreshold {
            advanceToNextWaypoint()
        }
    }

    private func advanceToNextWaypoint() {
        currentWaypointIndex += 1

        if currentWaypointIndex >= waypoints.count {
            // Reached destination
            arriveAtDestination()
        }
    }

    private func arriveAtDestination() {
        isNavigating = false
        setServo(angle: 90)  // Center servo

        guard let dest = destination else { return }
        speak("You have arrived at \(dest.name)")

        destination = nil
        waypoints = []
        currentWaypointIndex = 0
    }

    // MARK: - Distance Tracking

    private func updateDistances(from position: SIMD3<Float>) {
        guard currentWaypointIndex < waypoints.count else { return }

        // Distance to next immediate waypoint
        let nextWaypoint = waypoints[currentWaypointIndex]
        distanceToNextWaypoint = simd_distance(position, nextWaypoint)

        // Total remaining distance (sum of segments)
        var totalDistance: Float = distanceToNextWaypoint
        for i in currentWaypointIndex..<(waypoints.count - 1) {
            totalDistance += simd_distance(waypoints[i], waypoints[i + 1])
        }
        distanceToDestination = totalDistance
    }

    private func calculateTotalDistance() -> Float {
        guard !waypoints.isEmpty else { return 0 }
        var total: Float = 0
        for i in 0..<(waypoints.count - 1) {
            total += simd_distance(waypoints[i], waypoints[i + 1])
        }
        return total
    }

    private func checkDistanceMilestones() {
        let milestones: [Float] = [50, 20, 10, 5, 2]

        for milestone in milestones {
            if distanceToDestination < milestone && lastAnnouncedMilestone >= milestone {
                if milestone >= 10 {
                    speak("\(Int(milestone)) meters to destination")
                } else {
                    speak("Destination is very close")
                }
                lastAnnouncedMilestone = milestone
                break
            }
        }
    }

    // MARK: - Off-Route Detection

    private func checkOffRoute(position: SIMD3<Float>) {
        guard currentWaypointIndex < waypoints.count else { return }

        // Find distance to current route segment
        let segmentStart = currentWaypointIndex > 0 ? waypoints[currentWaypointIndex - 1] : position
        let segmentEnd = waypoints[currentWaypointIndex]
        let segmentDistance = distanceToRouteSegment(
            position: position,
            segmentStart: segmentStart,
            segmentEnd: segmentEnd
        )

        if segmentDistance > offRouteThreshold {
            // User is off route
            if offRouteStartTime == nil {
                offRouteStartTime = currentPose?.timestamp ?? 0
            } else if let startTime = offRouteStartTime,
                      let currentTime = currentPose?.timestamp,
                      (currentTime - startTime) > 3.0 {
                // Been off route for 3 seconds
                handleOffRoute(position: position)
                offRouteStartTime = nil  // Reset to avoid repeated warnings
            }
        } else {
            offRouteStartTime = nil  // Back on route
        }
    }

    private func distanceToRouteSegment(position: SIMD3<Float>,
                                        segmentStart: SIMD3<Float>,
                                        segmentEnd: SIMD3<Float>) -> Float {
        // Project point onto line segment
        let segmentVector = segmentEnd - segmentStart
        let pointVector = position - segmentStart

        let segmentLength = simd_length(segmentVector)
        guard segmentLength > 0 else { return simd_distance(position, segmentStart) }

        let t = max(0, min(1, simd_dot(pointVector, segmentVector) / (segmentLength * segmentLength)))
        let projection = segmentStart + t * segmentVector

        return simd_distance(position, projection)
    }

    private func handleOffRoute(position: SIMD3<Float>) {
        let lastWaypoint = currentWaypointIndex > 0 ?
            waypoints[currentWaypointIndex - 1] : waypoints[0]

        let distanceBack = simd_distance(position, lastWaypoint)

        speak("You are off route. Return to path. \(Int(distanceBack)) meters back")
    }

    // MARK: - Voice Guidance

    func speak(_ text: String) {
        lastGuidanceMessage = text
        speech.stopSpeaking(at: .immediate)  // Stop current speech
        speech.speak(AVSpeechUtterance(string: text))  // Speak immediately
        print("🔊 Voice: \(text)")
    }
}
