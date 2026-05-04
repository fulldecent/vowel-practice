// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI
import AVFoundation
import Charts
import Combine

// MARK: - Recorded audio

struct RecordedAudio: Sendable {
    let samples: [Double]
    let sampleRate: Double
    
    var isEmpty: Bool { samples.isEmpty }
    var duration: TimeInterval {
        guard sampleRate > 0 else { return 0 }
        return Double(samples.count) / sampleRate
    }
}

// MARK: - Audio recorder

@MainActor
final class AudioRecorder: ObservableObject {
    enum Status: Equatable, Sendable {
        case idle
        case recording
        case error(String)
    }
    
    @Published var status: Status = .idle
    
    private let audioEngine = AVAudioEngine()
    private var recordedSamples: [Double] = []
    private var recordedSampleRate: Double = 0
    private var recordingTask: Task<Void, Never>?
    
    // MARK: - Public API
    
    nonisolated func requestPermission() async -> Bool {
        #if os(macOS)
        // macOS uses AVCaptureDevice for microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return await AVCaptureDevice.requestAccess(for: .audio)
        @unknown default:
            return await AVCaptureDevice.requestAccess(for: .audio)
        }
        #else
        // iOS 17+ uses AVAudioApplication
        let audioApp = AVAudioApplication.shared
        
        switch audioApp.recordPermission {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
        #endif
    }
    
    func startRecording(duration: TimeInterval, onComplete: @escaping @MainActor (RecordedAudio) -> Void) async throws {
        guard status == .idle else {
            throw RecorderError.alreadyRecording
        }
        
        // Configure audio session (iOS/iPadOS only)
        #if !os(macOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])
        try audioSession.setActive(true)
        #endif
        
        // Reset state
        recordedSamples.removeAll()
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        recordedSampleRate = inputFormat.sampleRate
        
        print("🎤 Recording started - Sample Rate: \(recordedSampleRate) Hz, Channels: \(inputFormat.channelCount)")
        
        // Install tap - critical to capture on the correct thread
        let weakSelf = WeakBox(self)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, time in
            guard let channelData = buffer.floatChannelData else {
                print("⚠️ No channel data in buffer")
                return
            }
            
            let channelDataPointer = channelData.pointee
            let frameLength = Int(buffer.frameLength)
            
            // Convert to Double array immediately
            var samples: [Double] = []
            samples.reserveCapacity(frameLength)
            for i in 0..<frameLength {
                samples.append(Double(channelDataPointer[i]))
            }
            
            // Schedule on MainActor
            Task { @MainActor in
                weakSelf.value?.recordedSamples.append(contentsOf: samples)
            }
        }
        
        // Start engine
        audioEngine.prepare()
        try audioEngine.start()
        status = .recording
        
        print("🎤 Audio engine started successfully")
        
        // Auto-stop after duration
        recordingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if !Task.isCancelled {
                let audio = await self.stopRecording()
                print("🎤 Recording completed - \(audio.samples.count) samples captured")
                onComplete(audio)
            }
        }
    }
    
    @discardableResult
    func stopRecording() async -> RecordedAudio {
        recordingTask?.cancel()
        recordingTask = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        let audio = RecordedAudio(samples: recordedSamples, sampleRate: recordedSampleRate)
        
        print("🎤 Stopped recording - Total samples: \(audio.samples.count), Duration: \(audio.duration)s")
        
        status = .idle
        return audio
    }
    
    func reset() {
        recordedSamples.removeAll()
        recordedSampleRate = 0
        status = .idle
    }
    
    enum RecorderError: LocalizedError {
        case alreadyRecording
        
        var errorDescription: String? {
            "Recording is already in progress"
        }
    }
}

// Weak reference box to avoid retain cycles
private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - Audio player

@MainActor
final class AudioPlayer2: ObservableObject {
    @Published var isPlaying = false
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    nonisolated func setupAudioSession() {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .defaultToSpeaker)
        #endif
    }
    
    func play(samples: [Double], sampleRate: Double) {
        guard !samples.isEmpty else {
            print("🔊 Cannot play - no samples")
            return
        }
        
        print("🔊 Playing \(samples.count) samples at \(sampleRate) Hz")
        
        stop()
        
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("🔊 Failed to create audio format")
            return
        }
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            print("🔊 Failed to create PCM buffer")
            return
        }
        
        buffer.frameLength = buffer.frameCapacity
        // TODO: do I HAVE to convert to 32bit float to play it?
        let floatSamples = samples.map(Float.init)
        buffer.floatChannelData?.pointee.initialize(from: floatSamples, count: floatSamples.count)
        
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
            
            let weakSelf = WeakBox(self)
            player.scheduleBuffer(buffer, at: nil, options: .interrupts) {
                Task { @MainActor in
                    print("🔊 Playback completed")
                    weakSelf.value?.stop()
                }
            }
            player.play()
            
            self.audioEngine = engine
            self.playerNode = player
            self.isPlaying = true
            
            print("🔊 Playback started")
        } catch {
            print("🔊 AudioPlayer error: \(error.localizedDescription)")
            stop()
        }
    }
    
    func stop() {
        playerNode?.stop()
        audioEngine?.stop()
        
        if let player = playerNode {
            audioEngine?.detach(player)
        }
        
        playerNode = nil
        audioEngine = nil
        isPlaying = false
    }
}

// MARK: - Audio manager test view

struct AudioRecorderTestView: View {
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var player = AudioPlayer2()
    @State private var recordedAudio: RecordedAudio?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var recordingDuration: Double = 3.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusSection
                    durationPicker
                    recordingControls
                    
                    if let audio = recordedAudio, !audio.isEmpty {
                        Divider()
                        audioInfoSection(audio)
                        waveformSection(audio)
                        playbackControls
                    } else if recordedAudio != nil {
                        Divider()
                        Text("⚠️ Recording captured but no audio data")
                            .foregroundColor(.orange)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Audio recorder")
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .task {
                player.setupAudioSession()
            }
            .onDisappear {
                player.stop()
            }
        }
    }
    
    // MARK: - Status section
    
    private var statusSection: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            Text(statusText)
                .font(.headline)
            
            Spacer()
        }
        .padding()
        .background(statusColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var statusColor: Color {
        switch recorder.status {
        case .idle: return .gray
        case .recording: return .red
        case .error: return .orange
        }
    }
    
    private var statusText: String {
        switch recorder.status {
        case .idle: return "Ready to record"
        case .recording: return "Recording..."
        case .error(let message): return "Error: \(message)"
        }
    }
    
    // MARK: - Duration picker
    
    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recording duration")
                .font(.headline)
            
            Picker("Duration", selection: $recordingDuration) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("3 seconds").tag(3.0)
                Text("5 seconds").tag(5.0)
                Text("10 seconds").tag(10.0)
            }
            .pickerStyle(.segmented)
            .disabled(recorder.status == .recording)
        }
    }
    
    // MARK: - Recording controls
    
    private var recordingControls: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    do {
                        if recorder.status == .recording {
                            // Manual stop
                            let audio = await recorder.stopRecording()
                            recordedAudio = audio
                        } else {
                            // Request permission
                            let hasPermission = await recorder.requestPermission()
                            if !hasPermission {
                                errorMessage = "Microphone permission denied. Please enable in System Settings."
                                showError = true
                                return
                            }
                            
                            // Start recording with auto-stop callback
                            try await recorder.startRecording(duration: recordingDuration) { audio in
                                recordedAudio = audio
                            }
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
            } label: {
                Label(
                    recorder.status == .recording ? "Stop Recording" : "Start Recording (Auto-Stop)",
                    systemImage: recorder.status == .recording ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(recorder.status == .recording ? Color.red : Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            if recorder.status == .recording {
                Text("Recording will auto-stop after \(Int(recordingDuration)) seconds")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if recordedAudio != nil {
                Button(role: .destructive) {
                    recordedAudio = nil
                    recorder.reset()
                    player.stop()
                } label: {
                    Label("Clear Recording", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    // MARK: - Audio info section
    
    private func audioInfoSection(_ audio: RecordedAudio) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recording Info")
                .font(.headline)
            
            InfoRow(icon: "clock", label: "Duration", value: String(format: "%.2f sec", audio.duration))
            InfoRow(icon: "waveform", label: "Samples", value: "\(audio.samples.count)")
            InfoRow(icon: "chart.bar", label: "Sample Rate", value: "\(Int(audio.sampleRate)) Hz")
            
            if !audio.samples.isEmpty {
                let maxAmplitude = audio.samples.map(abs).max() ?? 0
                InfoRow(icon: "waveform.path", label: "Peak Amplitude", value: String(format: "%.3f", maxAmplitude))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Waveform section
    
    private func waveformSection(_ audio: RecordedAudio) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waveform")
                .font(.headline)
            
            let displaySamples = downsample(audio.samples, to: 300)
            
            Chart(Array(displaySamples.enumerated()), id: \.offset) { index, sample in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Amplitude", sample)
                )
                .foregroundStyle(.blue)
            }
            .chartXAxis(.hidden)
            .chartYScale(domain: -1...1)
            .frame(height: 100)
            .padding()
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Playback controls
    
    private var playbackControls: some View {
        Button {
            guard let audio = recordedAudio else { return }
            
            if player.isPlaying {
                player.stop()
            } else {
                player.play(samples: audio.samples, sampleRate: audio.sampleRate)
            }
        } label: {
            Label(
                player.isPlaying ? "Stop Playback" : "Play Recording",
                systemImage: player.isPlaying ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(player.isPlaying ? Color.orange : Color.green)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    // MARK: - Helper views
    
    private struct InfoRow: View {
        let icon: String
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                Text(value)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func downsample(_ samples: [Double], to count: Int) -> [Double] {
        guard samples.count > count else { return samples }
        let step = Double(samples.count) / Double(count)
        return (0..<count).map { samples[Int(Double($0) * step)] }
    }
}

#Preview {
    AudioRecorderTestView()
}
