import Foundation
import Speech
import AVFoundation

enum ListeningMode {
    case wakeWord    // Listening for "beacon" or "hey beacon"
    case command     // Listening for actual commands (5 second window)
}

@MainActor
class VoiceCommandService: NSObject, ObservableObject {
    // MARK: - Dependencies

    private let navigationService: NavigationService
    private weak var viewModel: LocalizerViewModel?

    // MARK: - Speech Recognition

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Wake Word

    private let wakeWords = ["beacon", "hey beacon"]
    private var listeningMode: ListeningMode = .wakeWord
    private var commandWindowTask: Task<Void, Never>?

    // MARK: - Published State

    @Published var isListening = false
    @Published var listeningForCommand = false  // true when in 5-second command window
    @Published var lastRecognizedText = ""
    @Published var lastCommandResult = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Initialization

    init(navigationService: NavigationService) {
        self.navigationService = navigationService
        super.init()
    }

    func setViewModel(_ viewModel: LocalizerViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Authorization

    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                if status == .authorized {
                    self?.startListening()
                }
            }
        }
    }

    // MARK: - Listening Control

    func startListening() {
        guard authorizationStatus == .authorized else {
            requestAuthorization()
            return
        }

        guard !isListening else { return }

        do {
            try startWakeWordListening()
            isListening = true
            print("🎤 Voice commands: wake word listening started")
        } catch {
            print("❌ Failed to start listening: \(error)")
            lastCommandResult = "Microphone unavailable"
        }
    }

    func stopListening() {
        guard isListening else { return }

        commandWindowTask?.cancel()
        commandWindowTask = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        listeningForCommand = false
        listeningMode = .wakeWord

        print("🎤 Voice commands: listening stopped")
    }

    // MARK: - Wake Word Detection

    private func startWakeWordListening() throws {
        listeningMode = .wakeWord
        listeningForCommand = false
        try startRecognition()
    }

    private func switchToCommandMode() {
        guard listeningMode == .wakeWord else { return }

        listeningMode = .command
        listeningForCommand = true

        // Play confirmation sound
        AudioServicesPlaySystemSound(1519)  // Peek feedback

        print("🎤 Wake word detected! Listening for command...")
        lastCommandResult = "Listening for command..."

        // Restart recognition in command mode
        do {
            try restartRecognition()
        } catch {
            print("❌ Failed to switch to command mode: \(error)")
            returnToWakeWordMode()
        }

        // Return to wake word mode after 5 seconds
        commandWindowTask?.cancel()
        commandWindowTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
            guard !Task.isCancelled else { return }
            await self?.returnToWakeWordMode()
        }
    }

    private func returnToWakeWordMode() {
        guard listeningMode == .command else { return }

        commandWindowTask?.cancel()
        commandWindowTask = nil

        print("🎤 Returning to wake word listening")
        lastCommandResult = "Waiting for wake word..."

        do {
            try startWakeWordListening()
        } catch {
            print("❌ Failed to return to wake word mode: \(error)")
        }
    }

    // MARK: - Speech Recognition

    private func startRecognition() throws {
        // Cancel existing task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Remove any existing tap before installing a new one
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Configure audio session for both recording (voice commands) and playback (speech synthesis)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceCommand", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get audio input
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.lastRecognizedText = transcript

                    // Check for wake word or command based on mode
                    if self.listeningMode == .wakeWord {
                        self.checkForWakeWord(transcript)
                    } else if self.listeningMode == .command && result.isFinal {
                        self.processCommand(transcript)
                        self.returnToWakeWordMode()
                    }
                }
            }

            if error != nil {
                print("⚠️ Recognition error: \(error!.localizedDescription)")
                // Restart after error
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if self.isListening {
                        try? self.restartRecognition()
                    }
                }
            }
        }

        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
    }

    private func restartRecognition() throws {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil

        try startRecognition()
    }

    private func checkForWakeWord(_ text: String) {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespaces)

        // Check if any wake word is present
        for wakeWord in wakeWords {
            if lowercased.contains(wakeWord) {
                switchToCommandMode()
                break
            }
        }
    }

    // MARK: - Command Processing

    private func processCommand(_ text: String) {
        let lowercased = text.lowercased().trimmingCharacters(in: .whitespaces)
        print("🎤 Processing command: \"\(lowercased)\"")

        // Navigate to [location]
        if lowercased.contains("navigate to") || lowercased.contains("go to") || lowercased.contains("take me to") {
            handleNavigateCommand(lowercased)
        }
        // Stop navigation
        else if lowercased.contains("stop") || lowercased.contains("cancel") {
            handleStopCommand()
        }
        // Where am I
        else if lowercased.contains("where am i") || lowercased.contains("where's my location") {
            handleWhereAmICommand()
        }
        // Repeat
        else if lowercased.contains("repeat") || lowercased.contains("say again") || lowercased.contains("say that again") {
            handleRepeatCommand()
        }
        else {
            navigationService.speak("Command not understood")
            lastCommandResult = "Unknown command"
        }
    }

    private func handleNavigateCommand(_ text: String) {
        guard let viewModel = viewModel else {
            lastCommandResult = "Not ready"
            return
        }

        guard viewModel.isRelocalized else {
            navigationService.speak("Cannot navigate. Not relocalized yet.")
            lastCommandResult = "Not relocalized"
            return
        }

        // Extract location name after "navigate to", "go to", or "take me to"
        var locationName = text
        if let range = text.range(of: "navigate to") {
            locationName = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = text.range(of: "go to") {
            locationName = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        } else if let range = text.range(of: "take me to") {
            locationName = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }

        // Find matching POI (fuzzy match)
        guard let poi = findMatchingPOI(locationName, in: viewModel.pois) else {
            navigationService.speak("Location not found: \(locationName)")
            lastCommandResult = "POI not found: \(locationName)"
            return
        }

        // Start navigation
        guard let pose = viewModel.currentPose else {
            navigationService.speak("Position unavailable")
            lastCommandResult = "No pose"
            return
        }

        navigationService.startNavigation(from: pose.position, to: poi, graph: viewModel.loadedGraph)
        lastCommandResult = "Navigating to \(poi.name)"
    }

    private func handleStopCommand() {
        if navigationService.isNavigating {
            navigationService.stopNavigation()
            lastCommandResult = "Navigation stopped"
        } else {
            navigationService.speak("No active navigation")
            lastCommandResult = "Not navigating"
        }
    }

    private func handleWhereAmICommand() {
        guard let viewModel = viewModel else {
            navigationService.speak("Location unavailable")
            return
        }

        guard let pose = viewModel.currentPose else {
            navigationService.speak("Position unavailable")
            lastCommandResult = "No pose"
            return
        }

        // Find nearest POI
        if let nearestPOI = findNearestPOI(to: pose.position, in: viewModel.pois) {
            let distance = simd_distance(pose.position, nearestPOI.poi.position)
            if distance < 5.0 {
                navigationService.speak("You are near \(nearestPOI.poi.name), \(Int(distance)) meters away")
            } else {
                navigationService.speak("Nearest location is \(nearestPOI.poi.name), \(Int(distance)) meters away")
            }
            lastCommandResult = "Near \(nearestPOI.poi.name)"
        } else {
            navigationService.speak("No locations available")
            lastCommandResult = "No POIs"
        }
    }

    private func handleRepeatCommand() {
        let message = navigationService.lastGuidanceMessage
        if !message.isEmpty {
            navigationService.speak(message)
            lastCommandResult = "Repeated: \(message)"
        } else {
            navigationService.speak("No previous message")
            lastCommandResult = "Nothing to repeat"
        }
    }

    // MARK: - POI Matching

    private func findMatchingPOI(_ searchText: String, in pois: [POI]) -> POI? {
        let search = searchText.lowercased()

        // Exact match first
        if let exact = pois.first(where: { $0.name.lowercased() == search }) {
            return exact
        }

        // Contains match
        if let contains = pois.first(where: { $0.name.lowercased().contains(search) }) {
            return contains
        }

        // Fuzzy match (words in any order)
        let searchWords = search.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for poi in pois {
            let poiWords = poi.name.lowercased().components(separatedBy: .whitespaces)
            let matchCount = searchWords.filter { word in
                poiWords.contains(where: { $0.contains(word) || word.contains($0) })
            }.count

            if matchCount >= searchWords.count / 2 && matchCount > 0 {
                return poi
            }
        }

        return nil
    }

    private func findNearestPOI(to position: SIMD3<Float>, in pois: [POI]) -> (poi: POI, distance: Float)? {
        guard !pois.isEmpty else { return nil }

        let nearest = pois.min(by: { poi1, poi2 in
            simd_distance(position, poi1.position) < simd_distance(position, poi2.position)
        })

        if let nearest = nearest {
            return (nearest, simd_distance(position, nearest.position))
        }

        return nil
    }
}
