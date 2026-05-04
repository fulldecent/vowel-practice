// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI
import Charts
import AVFoundation

struct DetailPageView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var audioPlayer = AudioPlayer2()

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                introduction
                originalAudioSection
                resamplingSection
                voiceActivitySection
                vowelIsolationSection
                windowingAndLPCSection
                formantResultsSection
                synthesisSection
            }
            .padding(20)
        }
        .navigationTitle("Analysis details")
        .task {
            audioPlayer.setupAudioSession()
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }

    // MARK: - Pipeline Sections

    private var introduction: some View {
        VStack {
            Text("Formant detail and tuning")
                .font(.largeTitle)
                .multilineTextAlignment(.center)
            Text("This page shows how formants are calculated step-by-step and allows tuning the parameters in this calculation.")
                .bodyStyle()
        }
    }

    private var originalAudioSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "1. Original audio",
                description: "This is the raw signal captured by the microphone. It is the starting point for all analysis."
            )
            
            let analysis = viewModel.formantAnalysis
            KeyValueRow(key: "Samples", value: "\(analysis.originalSamples.count)")
            KeyValueRow(key: "Sample rate", value: "\(Int(analysis.originalSampleRate)) Hz")
            KeyValueRow(
                key: "Duration",
                value: String(format: "%.0f ms", 1000 * Double(analysis.originalSamples.count) / analysis.originalSampleRate)
            )
            
            PlayableWaveformView(
                audioPlayer: audioPlayer,
                samples: analysis.originalSamples,
                sampleRate: analysis.originalSampleRate,
                color: .green
            )
        }
    }

    private var resamplingSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "2. Resampling & pre-emphasis",
                description: "The audio is downsampled to focus on lower frequencies where vowels reside, and a pre-emphasis filter is applied to boost high-frequency formants."
            )
            
            // --- Configuration ---
            Picker("Downsample rate", selection: $viewModel.resampleRate) {
                ForEach([8000.0, 10000.0, 12000.0, 16000.0], id: \.self) { rate in
                    Text("\(Int(rate)) Hz").tag(rate)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Pre-emphasis coefficient", selection: $viewModel.preemphasisCoefficient) {
                ForEach([0.0, 0.93, 0.95, 0.97], id: \.self) { coeff in
                    Text(String(format: "%.2f", coeff)).tag(coeff)
                }
            }
            .pickerStyle(.segmented)
            
            // --- Output ---
            let analysis = viewModel.formantAnalysis
            PlayableWaveformView(
                audioPlayer: audioPlayer,
                samples: analysis.resampledSamples,
                sampleRate: analysis.configuration.resampleRate,
                color: .purple
            )
        }
    }
    
    private var voiceActivitySection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "3. Voice activity detection",
                description: "The resampled signal is broken into chunks. The energy (power) of each chunk is calculated to find the main 'voiced' part of the recording."
            )
            
            // --- Configuration ---
            Picker("Chunk duration", selection: $viewModel.framingChunkDuration) {
                ForEach([0.01, 0.025, 0.05], id: \.self) { duration in
                    Text("\(Int(duration * 1000)) ms").tag(duration)
                }
            }
            .pickerStyle(.segmented)
            
            Picker("Power threshold", selection: $viewModel.framingPowerThreshold) {
                ForEach([0.03, 0.08, 0.15, 0.25], id: \.self) { threshold in
                    Text("\(Int(threshold * 100))%").tag(threshold)
                }
            }
            .pickerStyle(.segmented)

            // --- Output ---
            let analysis = viewModel.formantAnalysis
            let chunkPowers = analysis.chunkPowers
            let maxPower = chunkPowers.map(\.rmsPower).max() ?? 0
            let threshold = maxPower * viewModel.framingPowerThreshold

            Chart {
                ForEach(Array(chunkPowers.enumerated()), id: \.offset) { index, chunk in
                    BarMark(
                        x: .value("Chunk", index),
                        y: .value("Power", chunk.rmsPower)
                    )
                }
                
                if maxPower > 0 {
                    RuleMark(y: .value("Threshold", threshold))
                        .foregroundStyle(.red)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Threshold")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.leading, 4)
                        }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 80)
            .padding(.vertical, 8)
        }
    }
    
    private var vowelIsolationSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "4. Vowel isolation",
                description: "The detected voiced section is trimmed from the beginning and end to isolate the most stable part of the vowel, removing consonant sounds."
            )
            
            // --- Configuration ---
            Picker("Trim factor", selection: $viewModel.framingTrimFactor) {
                ForEach([0.0, 0.05, 0.1, 0.15], id: \.self) { factor in
                    Text("\(Int(factor * 200))%").tag(factor) // Factor is from one side, so UI shows total
                }
            }
            .pickerStyle(.segmented)
            
            // --- Output ---
            let analysis = viewModel.formantAnalysis
            PlayableWaveformView(
                audioPlayer: audioPlayer,
                samples: analysis.vowelSamples,
                sampleRate: analysis.configuration.resampleRate,
                color: .blue
            )
        }
    }

    private var windowingAndLPCSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "5. Vocal tract modeling (LPC)",
                description: "A window function smooths the signal edges, then Linear Predictive Coding (LPC) creates a mathematical model of the vocal tract's filter shape."
            )

            // --- Configuration ---
            Picker("Window", selection: $viewModel.cosineWindowAlpha) {
                Text("Hamming").tag(Float(25.0/46.0))
                Text("Hann").tag(Float(0.5))
                Text("None").tag(Float(1.0)) // Rectangular window
            }
            .pickerStyle(.segmented)
            
            Picker("LPC Order", selection: $viewModel.lpcModelOrder) {
                ForEach([10, 12, 14, 16], id: \.self) { order in
                    Text("Order \(order)").tag(order)
                }
            }
            .pickerStyle(.segmented)

            // --- Output ---
            let analysis = viewModel.formantAnalysis
            let freqInputsHz = analysis.configuration.frequencyResponseInputsHz
            let windowedResp = analysis.windowedVowelFrequencyResponse
            let lpcResp = analysis.lpcFrequencyResponse

            Chart {
                // Series 1: The actual signal's frequency response (AFTER windowing)
                ForEach(Array(zip(freqInputsHz, windowedResp)), id: \.0) { freq, response in
                    LineMark(
                        x: .value("Frequency", freq),
                        y: .value("Response", response)
                    )
                    // This creates an entry in the legend titled "Windowed Signal"
                    .foregroundStyle(by: .value("Series", "Windowed Signal"))
                }
                
                // Series 2: The LPC model's frequency response
                ForEach(Array(zip(freqInputsHz, lpcResp)), id: \.0) { freq, response in
                    LineMark(
                        x: .value("Frequency", freq),
                        y: .value("Response", response)
                    )
                    // This creates an entry in the legend titled "LPC Model"
                    .foregroundStyle(by: .value("Series", "LPC Model"))
                    // Make the model line thicker to distinguish it visually
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
            }
            .chartXScale(type: .log) // Use a log scale, better for audio frequencies
            .chartXAxisLabel("Frequency (Hz)")
            .chartYAxisLabel("Magnitude (dB)")
            .chartForegroundStyleScale([ // Define distinct colors for our series
                "Windowed Signal": .blue.opacity(0.8),
                "LPC Model": .orange
            ])
            .chartLegend(position: .top, alignment: .center) // Explicitly add a legend
            .frame(height: 250)
        }
    }
    
    private var formantResultsSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "6. Formant identification",
                description: "The peaks of the LPC model are identified as formants. Their location on the F1/F2 vowel chart determines the vowel sound."
            )
            
            let analysis = viewModel.formantAnalysis
            
            VowelSpaceChart(
                formants: analysis.formants,
                targetVowels: viewModel.targetVowels
            )
            
            Text("Detected formants").font(.headline).padding(.top)
            if analysis.formants.isEmpty {
                Text("No formants detected.").bodyStyle()
            } else {
                ForEach(Array(analysis.formants.enumerated()), id: \.offset) { index, formant in
                    KeyValueRow(
                        key: "F\(index + 1)",
                        value: String(format: "%.0f Hz (Q: %.1f)", formant.frequency, formant.q)
                    )
                }
            }
        }
    }
    
    private var synthesisSection: some View {
        VStack(spacing: 16) {
            SectionHeader(
                title: "7. Synthesis",
                description: "Listen to the sound generated purely from the mathematical models to confirm the analysis."
            )
            
            let analysis = viewModel.formantAnalysis
            
            Text("From full LPC model").font(.headline)
            PlayableWaveformView(
                audioPlayer: audioPlayer,
                samples: analysis.lpcVoicedSamples,
                sampleRate: analysis.configuration.resampleRate,
                color: .orange
            )
            
            Text("From final formants").font(.headline).padding(.top)
            PlayableWaveformView(
                audioPlayer: audioPlayer,
                samples: analysis.formantsVoicedSamples,
                sampleRate: analysis.configuration.resampleRate,
                color: .red
            )
        }
    }
}

// MARK: - Reusable Child Views

private struct SectionHeader: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .h1Style()
            Text(description)
                .bodyStyle()
        }
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .bold()
        }
    }
}

private struct PlayableWaveformView: View {
    @ObservedObject var audioPlayer: AudioPlayer2
    let samples: [Double]
    let sampleRate: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                if audioPlayer.isPlaying {
                    audioPlayer.stop()
                } else {
                    audioPlayer.play(samples: samples, sampleRate: sampleRate)
                }
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(color)
            }
            .buttonStyle(.plain)
            
            if samples.isEmpty {
                 RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.lightGray))
                    .frame(height: 80)
            } else {
                Chart(Array(samples.enumerated()), id: \.offset) { index, sample in
                    LineMark(
                        x: .value("Time", index),
                        y: .value("Amplitude", sample)
                    )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .foregroundStyle(color)
                .frame(height: 80)
            }
        }
        .padding(.top, 4)
    }
}

private struct VowelSpaceChart: View {
    let formants: [FormantAnalysis.Resonance]
    let targetVowels: [TherapeuticVowel]
    
    var body: some View {
        let f1 = formants.count > 0 ? formants[0].frequency : 0
        let f2 = formants.count > 1 ? formants[1].frequency : 0

        Chart {
            ForEach(targetVowels, id: \.symbol) { vowel in
                PointMark(x: .value("F2", vowel.f2), y: .value("F1", vowel.f1))
                    .foregroundStyle(.gray.opacity(0.5))
                    .annotation(position: .overlay) {
                        Text(vowel.symbol).font(.caption).foregroundStyle(.secondary)
                    }
            }
            if f1 > 0 && f2 > 0 {
                PointMark(x: .value("F2", f2), y: .value("F1", f1))
                    .symbol(.circle)
                    .symbolSize(180)
                    .foregroundStyle(.red)
                    .annotation(position: .bottom, alignment: .center, spacing: 8) {
                        Text("You")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
            }
        }
        .chartXScale(domain: 800...3000, range: .plotDimension(padding: 20)) // Reversed
        .chartYScale(domain: 200...900, range: .plotDimension(padding: 20))  // Reversed
        .chartXAxisLabel("F2 (Hz)")
        .chartYAxisLabel("F1 (Hz)")
        .frame(height: 300)
    }
}

// MARK: - Audio player

// Weak reference box to avoid retain cycles
private final class WeakBox<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

// MARK: - View modifiers & styles

private extension View {
    func h1Style() -> some View {
        self.font(.system(.title, design: .rounded, weight: .bold))
    }
    
    func bodyStyle() -> some View {
        self.font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
}

