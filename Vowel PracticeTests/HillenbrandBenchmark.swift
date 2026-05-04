// Vowel Practice
// (c) William Entriken
// See LICENSE

import Testing
import Foundation
@testable import Vowel_Practice
import Accelerate
import AVFoundation

struct HillenbrandBenchmark {
    let hillenbrandData: [Hillenbrand1995Reader.VowelData]

    init() {
        hillenbrandData = Hillenbrand1995Reader.loadVowelData()
    }

    @Test(.enabled(if: Hillenbrand1995Reader.isDataAvailable,
                   "Hillenbrand 1995 data is not bundled with the test target; see README"))
    func loadHillenBrandData() {
        #expect(!hillenbrandData.isEmpty)
    }

    /*
    @Test func checkDuration() {
        hillenbrandData.forEach { vowel, data in
            let expectedDuration = data.duration
            let wavFile = loadTestWavFile(vowel)
            let duration = Double(wavFile.samples.count) / wavFile.sampleRate
            #expect(abs(duration - expectedDuration) < 0.01)
        }
    }
    */

    @Test(.enabled(if: Hillenbrand1995Reader.isDataAvailable,
                   "Hillenbrand 1995 data is not bundled with the test target; see README"))
    func checkFormants() {
        hillenbrandData[..<10].forEach { data in
            let wavFile = loadTestWavFile(data.filename)
            let analysis = FormantAnalysis(samples: wavFile.samples, sampleRate: wavFile.sampleRate)
            print(data.filename)
            print(analysis.formants)
            #expect(analysis.formants.count > 0)
        }
    }
    
    // MARK: private

    private func loadTestWavFile(_ fileName: String) -> (samples: [Double], sampleRate: Double) {
        let bundle = Bundle(for: Hillenbrand1995Reader.self)
        let url = bundle.url(forResource: fileName, withExtension: nil)!
        let audioFile = try! AVAudioFile(forReading: url)

        let frameCount = audioFile.length
        let format = audioFile.processingFormat
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        try! audioFile.read(into: buffer)
        var samples = [Double](repeating: 0.0, count: Int(frameCount))
        vDSP_vspdp(buffer.floatChannelData![0], 1, &samples, 1, UInt(frameCount))
        return (samples: samples, sampleRate: audioFile.fileFormat.sampleRate)
    }
}
