// Vowel Practice
// (c) William Entriken
// See LICENSE

import Foundation
import AVFoundation
import AVFAudio  // Required for AVAudioApplication
import Combine
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - App state
    enum Status: Equatable {
        case idle
        case recording
        case processing
        case ready
        case error(String)
    }
    
    @Published var status: Status = .idle
    @Published var formantAnalysis: FormantAnalysis = .empty
    @Published var targetVowels: [TherapeuticVowel] = SpeakerProfile.baseVowels
    
    // MARK: - Configuration properties
    @Published var resampleRate: Double = FormantAnalysis.Configuration.default.resampleRate
    @Published var preemphasisCoefficient: Double = FormantAnalysis.Configuration.default.preemphasisCoefficient
    @Published var framingChunkDuration: Double = FormantAnalysis.Configuration.default.framingChunkDuration
    @Published var framingPowerThreshold: Double = FormantAnalysis.Configuration.default.framingPowerThreshold
    @Published var framingTrimFactor: Double = FormantAnalysis.Configuration.default.framingTrimFactor
    @Published var cosineWindowAlpha: Double = FormantAnalysis.Configuration.default.cosineWindowAlpha
    @Published var lpcModelOrder: Int = FormantAnalysis.Configuration.default.lpcModelOrder
        
    // MARK: - Private properties
    private let audioRecorder = AudioRecorder()
    private var recordedAudio: RecordedAudio?
    private let recordingDuration: TimeInterval = 1.5
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init() {
        setupBindings()
        autoLoadMockAudioIfRequested()
    }
    
    // MARK: - Public methods (recording control)
    
    func startRecording() {
        // Test / screenshot hook: bypass the microphone entirely and analyze
        // a bundled wav file. Pass `-mockAudio arm` (or any other resource
        // name) on the command line.
        if let mockName = mockAudioResourceName(), loadMockAudio(named: mockName) {
            return
        }

        Task {
            let granted = await audioRecorder.requestPermission()
            guard granted else {
                status = .error("Microphone permission denied")
                return
            }
            
            do {
                status = .recording
                
                try await audioRecorder.startRecording(duration: recordingDuration) { [weak self] audio in
                    Task { @MainActor in
                        self?.handleRecordingComplete(audio)
                    }
                }
            } catch {
                status = .error("Failed to start recording: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording() async {
        let audio = await audioRecorder.stopRecording()
        handleRecordingComplete(audio)
    }
    
    func reset() {
        status = .idle
        formantAnalysis = .empty
        recordedAudio = nil
        audioRecorder.reset()
    }
    
    // MARK: - Private methods (recording)
    
    private func handleRecordingComplete(_ audio: RecordedAudio) {
        recordedAudio = audio
        
        guard !audio.isEmpty else {
            status = .error("No audio data recorded")
            return
        }
        
        status = .processing
        
        Task {
            await processRecording()
        }
    }
    
    // MARK: - Private methods (analysis pipeline)
    
    private func processRecording() async {
        guard let audio = recordedAudio else {
            status = .error("No audio data available")
            return
        }
        
        guard !audio.isEmpty else {
            status = .error("No audio data recorded")
            return
        }
        
        await rerunAnalysis()
    }
    
    /// Re-runs the formant analysis with current configuration and recorded samples.
    private func rerunAnalysis() async {
        guard let audio = recordedAudio, !audio.isEmpty else {
            formantAnalysis = .empty
            return
        }
        
        let config = FormantAnalysis.Configuration(
            resampleRate: resampleRate,
            preemphasisCoefficient: preemphasisCoefficient,
            framingChunkDuration: framingChunkDuration,
            framingPowerThreshold: framingPowerThreshold,
            framingTrimFactor: framingTrimFactor,
            cosineWindowAlpha: cosineWindowAlpha,
            lpcModelOrder: lpcModelOrder
        )
        
        // Capture values for background processing
        let samples = audio.samples
        let sampleRate = audio.sampleRate
        
        // Run analysis on a background task
        let newAnalysis = await Task.detached(priority: .userInitiated) {
            FormantAnalysis(
                samples: samples,
                sampleRate: sampleRate,
                configuration: config
            )
        }.value
        
        // Update UI (already on MainActor)
        self.formantAnalysis = newAnalysis
        self.status = .ready
    }
    
    /// Sets up a Combine pipeline that listens for changes to any configuration parameter and triggers a re-analysis.
    private func setupBindings() {
        let configurationPublishers: [AnyPublisher<Void, Never>] = [
            $resampleRate.map { _ in () }.eraseToAnyPublisher(),
            $preemphasisCoefficient.map { _ in () }.eraseToAnyPublisher(),
            $framingChunkDuration.map { _ in () }.eraseToAnyPublisher(),
            $framingPowerThreshold.map { _ in () }.eraseToAnyPublisher(),
            $framingTrimFactor.map { _ in () }.eraseToAnyPublisher(),
            $cosineWindowAlpha.map { _ in () }.eraseToAnyPublisher(),
            $lpcModelOrder.map { _ in () }.eraseToAnyPublisher()
        ]
        
        Publishers.MergeMany(configurationPublishers)
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Defer to next run loop to avoid "publishing changes from within view updates"
                DispatchQueue.main.async {
                    Task { @MainActor in
                        // Only re-run if we have recorded audio to analyze
                        if self?.recordedAudio?.isEmpty == false {
                            await self?.rerunAnalysis()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Mock audio (UI tests / screenshots)

    /// Returns the name of a bundled wav resource to use instead of the
    /// microphone, or nil. Pass `-mockAudio arm` on the command line.
    private func mockAudioResourceName() -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-mockAudio"), i + 1 < args.count else {
            return nil
        }
        return args[i + 1]
    }

    /// If `-mockAudio NAME` was passed on the command line, load that bundled
    /// wav file immediately so the app shows real formant data without
    /// requiring microphone access. Used for UI tests and screenshots.
    private func autoLoadMockAudioIfRequested() {
        guard let name = mockAudioResourceName() else { return }
        loadMockAudio(named: name)
    }

    /// Loads a bundled wav file, decodes it to mono Doubles, and pushes it
    /// through the analysis pipeline as if it had just been recorded.
    @discardableResult
    func loadMockAudio(named name: String) -> Bool {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            status = .error("Mock audio '\(name).wav' not found in bundle")
            return false
        }
        do {
            let audio = try Self.readWav(url: url)
            handleRecordingComplete(audio)
            return true
        } catch {
            status = .error("Failed to load mock audio: \(error.localizedDescription)")
            return false
        }
    }

    /// Reads a wav file and returns mono `Double` samples in `[-1, 1]`.
    private static func readWav(url: URL) throws -> RecordedAudio {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "Vowel Practice", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not allocate PCM buffer"])
        }
        try file.read(into: buffer)
        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "Vowel Practice", code: -2, userInfo: [NSLocalizedDescriptionKey: "wav file has no float channel data"])
        }
        let frames = Int(buffer.frameLength)
        let channels = Int(format.channelCount)
        var samples = [Double](repeating: 0, count: frames)
        for i in 0..<frames {
            var sum: Float = 0
            for c in 0..<channels {
                sum += channelData[c][i]
            }
            samples[i] = Double(sum / Float(max(channels, 1)))
        }
        return RecordedAudio(samples: samples, sampleRate: format.sampleRate)
    }
}
