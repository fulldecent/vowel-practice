// Vowel Practice
// (c) William Entriken
// See LICENSE

import Foundation
import Numerics
import AVFoundation
import Accelerate

/// The completed analysis from a speech signals to extract formants and related properties.
struct FormantAnalysis {
    // They are included here so the file is complete.
    struct Configuration {
        let resampleRate: Double
        let preemphasisCoefficient: Double
        let framingChunkDuration: Double
        let framingPowerThreshold: Double
        let framingTrimFactor: Double
        let cosineWindowAlpha: Double
        let lpcModelOrder: Int
        
        // About 20 Hz to 5100 Hz
        let frequencyResponseInputsHz = Array<Double>(stride(from: 30, to: 2400, by: 24)).map(melToHz)
        let minFormantSeparationMel: Double = 50.0
        let voicedSampleDuration: Double = 1.5

        static let `default`: Configuration = .init(
            resampleRate: 10_000,
            preemphasisCoefficient: 0.95,
            framingChunkDuration: 0.025,
            framingPowerThreshold: 0.1,
            framingTrimFactor: 0.1,
            cosineWindowAlpha: 25.0/46.0,
            lpcModelOrder: 12
        )
    }
    
    // TODO: add Resonance.amplitude based on the non-preemphasis frequency response
    struct Resonance: CustomStringConvertible {
        let frequency: Double
        let q: Double
        var description: String {
            String(format: "%.2f Hz / %.2f Q", frequency, q)
        }
        /// Bandwidth in Hz (full width half maximum); but really this FWHM should only be in log scale (Mels)
        var bandwidth: Double {
            frequency / q
        }
    }
    struct ChunkPower {
        let indicies: ClosedRange<Int>
        let rmsPower: Double
    }
    
    // MARK: Analysis inputs
    let originalSamples: [Double]
    let originalSampleRate: Double
    let configuration: Configuration
    static let silentDbLevel: Double = -100.0
    
    // MARK: Analysis outputs
    let resampledSamples: [Double]
    let resampledFrequencyResponse: [Double]
    let chunkPowers: [ChunkPower]
    let powerFrame: ClosedRange<Int>?
    let frame: ClosedRange<Int>?
    let vowelSamples: [Double]
    let windowedVowelFrequencyResponse: [Double]
    
    let lpcCoefficients: [Double]
    let lpcGain: Double
    let lpcPolynomialRoots: [Resonance]
    let lpcFrequencyResponse: [Double]
    let lpcVoicedSamples: [Double]
    
    let formants: [Resonance]
    let formantsFrequencyResponse: [Double]
    let formantsVoicedSamples: [Double]
    
    init(samples: [Double], sampleRate: Double, configuration: Configuration = .default) {
        self.originalSamples = samples
        self.originalSampleRate = sampleRate
        self.configuration = configuration

        let rawResampledSamples = Self.resample(samples: samples, sampleRate: sampleRate, toSampleRate: configuration.resampleRate)
        self.resampledSamples = Self.preemphasis(rawResampledSamples, coefficient: configuration.preemphasisCoefficient)

        self.chunkPowers = Self.analyzeEnergyLevels(samples: resampledSamples, sampleRate: configuration.resampleRate, chunkDuration: configuration.framingChunkDuration)
        
        guard let powerFrame = Self.findSensitiveSampleRange(in: chunkPowers, powerThreshold: configuration.framingPowerThreshold) else {
            // TODO: HACK!!!!
            fatalError("Could not find a sensitive frame!")
        }
        self.powerFrame = powerFrame

        self.frame = Self.trimRange(powerFrame, byFactor: configuration.framingTrimFactor)
        let vowelSamplesSlice = self.frame != nil ? Array(resampledSamples[self.frame!]) : []
        self.vowelSamples = vowelSamplesSlice

        let windowedSamples = Self.applyCosineWindow(to: vowelSamplesSlice, alpha: configuration.cosineWindowAlpha)
        self.windowedVowelFrequencyResponse = Self.computeFrequencyResponse(samples: windowedSamples, sampleRate: configuration.resampleRate, frequencies: configuration.frequencyResponseInputsHz)

        let (lpcCoefficients, predictionError) = Self.computeLPCCoefficients(samples: windowedSamples, order: configuration.lpcModelOrder)
        self.lpcCoefficients = lpcCoefficients
        self.lpcGain = sqrt(predictionError)

        self.lpcPolynomialRoots = Self.findFormants(lpcCoefficients: lpcCoefficients, sampleRate: configuration.resampleRate)
        self.formants = Self.mergeNearbyFormants(lpcPolynomialRoots, minSeparationMel: configuration.minFormantSeparationMel)

        self.resampledFrequencyResponse = Self.computeFrequencyResponse(samples: resampledSamples, sampleRate: configuration.resampleRate, frequencies: configuration.frequencyResponseInputsHz)
        self.lpcFrequencyResponse = Self.computeLPCFrequencyResponse(lpcCoefficients: lpcCoefficients, gain: self.lpcGain, sampleRate: configuration.resampleRate, frequencies: configuration.frequencyResponseInputsHz)
        self.formantsFrequencyResponse = Self.computeResonanceFrequencyResponse(resonances: self.formants, sampleRate: configuration.resampleRate, frequencies: configuration.frequencyResponseInputsHz)

        self.lpcVoicedSamples = Self.generateVoicedSamples(resonances: lpcPolynomialRoots, sampleRate: configuration.resampleRate, duration: configuration.voicedSampleDuration, f0: 100.0)
        self.formantsVoicedSamples = Self.generateVoicedSamples(resonances: formants, sampleRate: configuration.resampleRate, duration: configuration.voicedSampleDuration, f0: 100.0)
    }

    private init() {
        let emptyFreqResponse = Array(repeating: Double(Self.silentDbLevel), count: Configuration.default.frequencyResponseInputsHz.count)
        originalSamples = []
        originalSampleRate = 10_000
        configuration = .default
        resampledSamples = []
        resampledFrequencyResponse = emptyFreqResponse
        chunkPowers = []
        powerFrame = nil
        frame = nil
        vowelSamples = []
        windowedVowelFrequencyResponse = emptyFreqResponse
        lpcCoefficients = []
        lpcGain = 0
        lpcPolynomialRoots = []
        lpcFrequencyResponse = emptyFreqResponse
        lpcVoicedSamples = []
        formants = []
        formantsFrequencyResponse = emptyFreqResponse
        formantsVoicedSamples = []
    }
    
    static let empty: FormantAnalysis = .init()
}

// MARK: - Standalone DSP Functions
extension FormantAnalysis {
    /// Do a low quality 32-bit downsample, there is no available library for 64-bit downsample
    static func resample(samples: [Double], sampleRate: Double, toSampleRate newSampleRate: Double) -> [Double] {
        guard !samples.isEmpty, sampleRate > 0, newSampleRate > 0 else { return [] }
        
        // Efficient downconvert to 32-bit
        var inFloats = [Float](repeating: 0, count: samples.count)
        vDSP.convertElements(of: samples, to: &inFloats)
        
        guard let inFormat  = AVAudioFormat(standardFormatWithSampleRate: sampleRate,    channels: 1),
              let outFormat = AVAudioFormat(standardFormatWithSampleRate: newSampleRate, channels: 1)
        else { return [] }
        
        // Build input buffer
        guard let inBuffer = AVAudioPCMBuffer(pcmFormat: inFormat,
                                              frameCapacity: AVAudioFrameCount(inFloats.count)) else { return [] }
        inBuffer.frameLength = inBuffer.frameCapacity
        inFloats.withUnsafeBufferPointer { src in
            let dst = inBuffer.floatChannelData![0]
            dst.update(from: src.baseAddress!, count: Int(inBuffer.frameLength))
        }
        
        // Configure high-quality converter
        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else { return [] }
        converter.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue  // highest quality
        
        // Conservative capacity (plus headroom for filter delay)
        let estimatedOutFrames = AVAudioFrameCount(ceil(Double(inBuffer.frameLength) * newSampleRate / sampleRate) + 64)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: estimatedOutFrames) else { return [] }
        
        var outFloats: [Float] = []
        outFloats.reserveCapacity(Int(estimatedOutFrames))
        
        var error: NSError? = nil
        var inputProvided = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputProvided {
                outStatus.pointee = .endOfStream
                return nil
            } else {
                inputProvided = true
                outStatus.pointee = .haveData
                return inBuffer
            }
        }
        
        // Pull from converter until it signals endOfStream
        while true {
            outBuffer.frameLength = outBuffer.frameCapacity
            let status = converter.convert(to: outBuffer, error: &error, withInputFrom: inputBlock)
            
            if let _ = error { return [] }
            
            if outBuffer.frameLength > 0 {
                let ptr = outBuffer.floatChannelData![0]
                outFloats.append(contentsOf: UnsafeBufferPointer(start: ptr, count: Int(outBuffer.frameLength)))
            }
            
            if status == .endOfStream || status == .error { break }
            // status .haveData or .inputRanDry: keep draining tail until .endOfStream
        }
        
        // Convert back to Double
        var outDoubles = [Double](repeating: 0, count: outFloats.count)
        vDSP.convertElements(of: outFloats, to: &outDoubles)
        return outDoubles
    }
    
    /// Simple preemphasis FIR filter
    static func preemphasis(_ samples: [Double], coefficient: Double) -> [Double] {
        let kernel: [Double] = [1.0, -coefficient]  // FIR filter coefficients
        return vDSP.convolve(samples, withKernel: kernel)
    }
    
    /// Chunk based analysis
    static func analyzeEnergyLevels(samples: [Double], sampleRate: Double, chunkDuration: Double) -> [ChunkPower] {
        let samplesPerChunk = Int(chunkDuration * sampleRate)
        guard !samples.isEmpty, samplesPerChunk > 0 else { return [] }
        var chunkPowers: [ChunkPower] = []
        var start = 0
        while start < samples.count {
            let end = min(start + samplesPerChunk - 1, samples.count - 1)
            let chunkSamples = Array(samples[start...end])
            var rmsPower: Double = 0
            vDSP_rmsqvD(chunkSamples, 1, &rmsPower, vDSP_Length(chunkSamples.count))
            chunkPowers.append(ChunkPower(indicies: start...end, rmsPower: Double(rmsPower)))
            start += samplesPerChunk
        }
        return chunkPowers
    }
    
    static func findSensitiveSampleRange(in chunkPowers: [ChunkPower], powerThreshold: Double) -> ClosedRange<Int>? {
        guard !chunkPowers.isEmpty else { return nil }
        let maxPower = chunkPowers.map { $0.rmsPower }.max() ?? 0.0
        guard maxPower > 0 else { return nil }
        let threshold = maxPower * powerThreshold
        guard let firstIndex = chunkPowers.firstIndex(where: { $0.rmsPower >= threshold }),
              let lastIndex = chunkPowers.lastIndex(where: { $0.rmsPower >= threshold }) else {
            return nil
        }
        let firstChunk = chunkPowers[firstIndex]
        let lastChunk = chunkPowers[lastIndex]
        return firstChunk.indicies.lowerBound...lastChunk.indicies.upperBound
    }
    
    static func trimRange(_ range: ClosedRange<Int>, byFactor trimFactor: Double) -> ClosedRange<Int> {
        let totalLength = Double(range.count)
        let trimAmount = Int(totalLength * trimFactor)
        let trimmedStart = range.lowerBound + trimAmount
        let trimmedEnd = range.upperBound - trimAmount
        return trimmedStart <= trimmedEnd ? trimmedStart...trimmedEnd : trimmedStart...trimmedStart
    }
    
    /// Apply a Hamming or Hanning window
    static func applyCosineWindow(to samples: [Double], alpha: Double) -> [Double] {
        let n = samples.count; guard n > 0 else { return [] }
        var window = [Double](repeating: 0.0, count: n)
        if alpha == 25.0/46.0 { vDSP_hamm_windowD(&window, vDSP_Length(n), 0) }
        else if alpha == 0.5 { vDSP_hann_windowD(&window, vDSP_Length(n), 0) }
        else { vDSP_vfillD([1.0], &window, 1, vDSP_Length(n)) }
        var result = [Double](repeating: 0.0, count: n)
        vDSP_vmulD(samples, 1, window, 1, &result, 1, vDSP_Length(n))
        return result
    }
    
    static func computeFrequencyResponse(samples: [Double], sampleRate: Double, frequencies: [Double]) -> [Double] {
        guard !samples.isEmpty else {
            return Array(repeating: Double(Self.silentDbLevel), count: frequencies.count)
        }
        
        let n = Double(samples.count)
        let twoPi = 2.0 * Double.pi
        
        return frequencies.map { freq in
            let omega = twoPi * freq / sampleRate
            
            // Vectorized computation using vDSP
            var cosValues = (0..<samples.count).map { i in cos(-omega * Double(i)) }
            var sinValues = (0..<samples.count).map { i in sin(-omega * Double(i)) }
            
            var realSum = 0.0
            var imagSum = 0.0
            
            vDSP.multiply(samples, cosValues, result: &cosValues)
            vDSP.multiply(samples, sinValues, result: &sinValues)
            
            realSum = vDSP.sum(cosValues)
            imagSum = vDSP.sum(sinValues)
            
            let magnitude = sqrt(realSum * realSum + imagSum * imagSum) / n
            guard magnitude > 1e-6 else { return Double(Self.silentDbLevel) }
            return 20.0 * log10(magnitude)
        }
    }

    /// Computes LPC coefficients using the stable Levinson-Durbin algorithm.
    static func computeLPCCoefficients(samples: [Double], order: Int) -> (coefficients: [Double], predictionError: Double) {
        guard samples.count > order else {
            var a = [Double](repeating: 0, count: order + 1); a[0] = 1
            return (coefficients: a, predictionError: 1.0)
        }
        
        // Step 1: Compute autocorrelation
        let r = computeAutocorrelation(samples: samples, maxLag: order)
        
        guard r.count > order, r[0] > 0 else {
            var a = [Double](repeating: 0, count: order + 1); a[0] = 1
            return (coefficients: a, predictionError: 1.0)
        }
        
        // Step 2: Solve the Yule-Walker equations using Levinson-Durbin recursion.
        var a = [Double](repeating: 0, count: order + 1)
        // REMOVED: var k = [Double](repeating: 0, count: order + 1)
        var E = r[0]
        
        a[0] = 1.0
        
        for i in 1...order {
            var sum: Double = 0
            if i > 1 {
                let a_slice = Array(a[1..<i])
                let r_slice = Array(r[1..<i].reversed())
                vDSP_dotprD(a_slice, 1, r_slice, 1, &sum, vDSP_Length(a_slice.count))
            }
            
            // Calculate reflection coefficient k
            let k = -(r[i] + sum) / E
            
            let a_prev = Array(a[1..<i])

            // Update coefficients for the current order i
            for j in 1..<i {
                a[j] += k * a_prev[i - 1 - j]
            }
            a[i] = k

            // Update prediction error
            E *= (1 - k * k)
            if E.isNaN || E.isInfinite || E <= 0 { E = 1e-9 }
        }
        
        return (coefficients: a, predictionError: E)
    }
    
    static func computeAutocorrelation(samples: [Double], maxLag: Int) -> [Double] {
        let n = samples.count
        guard n > maxLag else { return [] }
        
        var correlations = [Double]()
        correlations.reserveCapacity(maxLag + 1)
        
        // Use direct pointer access instead of creating new arrays
        samples.withUnsafeBufferPointer { samplePtr in
            for lag in 0...maxLag {
                let length = n - lag
                var sum = 0.0
                
                // Direct pointer arithmetic - much more efficient
                let firstPtr = samplePtr.baseAddress!
                let secondPtr = samplePtr.baseAddress!.advanced(by: lag)
                
                vDSP_dotprD(firstPtr, 1, secondPtr, 1, &sum, vDSP_Length(length))
                correlations.append(sum)
            }
        }
        
        // Normalize by R[0]
        guard let r0 = correlations.first, r0 > 0 else { return correlations }
        return correlations.map { $0 / r0 }
    }
    
    static func computeLPCFrequencyResponse(lpcCoefficients: [Double], gain: Double, sampleRate: Double, frequencies: [Double]) -> [Double] {
        guard gain.isFinite && gain > 0 else {
            return Array(repeating: Double(Self.silentDbLevel), count: frequencies.count)
        }
        let gainDb = 20 * log10(gain)

        return frequencies.map { freq -> Double in
            let omega = 2.0 * Double.pi * freq / sampleRate
            
            // Start with 1.0 for the LPC polynomial A(z) = 1 + a₁z⁻¹ + a₂z⁻² + ...
            var responseSum = Complex<Double>(1.0)
            
            for (k, a_k) in lpcCoefficients.enumerated() {
                // k+1 because LPC coefficients typically start from a₁ (index 1)
                let z_inv_k = Complex(length: 1.0, phase: -Double(k + 1) * omega)
                responseSum += Complex<Double>(a_k) * z_inv_k
            }
            
            let mag = responseSum.length
            guard mag > 1e-9 else { return Double(Self.silentDbLevel) }
            
            // H(e^jω) = G / A(e^jω), so |H| = G / |A|
            // In dB: 20*log10(G) - 20*log10(|A|)
            return gainDb - (20.0 * log10(mag))
        }
    }
    
    static func computeResonanceFrequencyResponse(resonances: [Resonance], sampleRate: Double, frequencies: [Double]) -> [Double] {
        guard !resonances.isEmpty else { return Array(repeating: Double(Self.silentDbLevel), count: frequencies.count) }
        
        return frequencies.map { freq -> Double in
            var complexSum: Complex<Double> = .zero
            let omega = 2.0 * Double.pi * freq / sampleRate
            
            // Represents z⁻¹ = e⁻ʲʷ. Calculate it once per frequency.
            let z_inv = Complex(length: 1.0, phase: -omega)
            
            for res in resonances {
                let omega0 = 2.0 * Double.pi * res.frequency / sampleRate
                
                // This calculation for 'r' (pole radius) is an approximation.
                // A more direct formula is r = exp(-pi * bandwidth / sampleRate)
                // Since bandwidth = frequency / q, this becomes:
                let r = exp(-Double.pi * res.frequency / (res.q * sampleRate))
                
                // Create the pole p = r * e^(jω₀) using the polar initializer.
                let pole = Complex(length: r, phase: omega0)
                
                // The transfer function for a resonant filter is H(z) = 1 / ((1 - p*z⁻¹)(1 - p̄*z⁻¹))
                // where p̄ is the conjugate of p.
                let denominator = (Complex.one - pole * z_inv) * (Complex.one - pole.conjugate * z_inv)

                // Avoid division by zero if the denominator is tiny
                if denominator.magnitude > 1e-12 {
                    let response = Complex.one / denominator
                    complexSum += response
                }
            }

            let mag = complexSum.magnitude
            guard mag > 1e-9 else { return Double(Self.silentDbLevel) }
            
            // The summing of complex responses models a parallel filter bank. [ccrma.stanford.edu/~jos/fp/First_Order_Complex_Resonators.html]
            // This requires normalization for reasonable display.
            return 20.0 * log10(mag) - 40.0
        }
    }
    
    static func generateVoicedSamples(resonances: [Resonance], sampleRate: Double, duration: Double, f0: Double) -> [Double] {
        guard sampleRate > 0, duration >= 0, f0 > 0 else { return [] }
        let nSamples = Int(duration * sampleRate)
        guard nSamples > 0 else { return [] }
        let samplesPerPeriod = Int(sampleRate / f0)
        guard samplesPerPeriod > 0 else { return [] }
        
        // 1. Create impulse train
        var impulseTrain = [Double](repeating: 0.0, count: nSamples)
        for i in stride(from: 0, to: nSamples, by: samplesPerPeriod) {
            impulseTrain[i] = 1.0
        }
        
        var signalToFilter = impulseTrain
        
        // 2. Apply resonant filters
        // Using modern Swift vDSP API for cleaner code
        for resonance in resonances {
            let freq = resonance.frequency
            let q = resonance.q
            guard freq > 0, freq < sampleRate / 2, q > 0 else { continue }
            
            let r = exp(-Double.pi * freq / (q * sampleRate))
            let omega = 2.0 * Double.pi * freq / sampleRate
            let b0 = 1.0 - r * r
            let a1 = -2.0 * r * cos(omega)
            let a2 = r * r
            
            // Coefficients for single biquad section: [b0, b1, b2, a1, a2]
            let coefficients: [Double] = [b0, 0.0, 0.0, a1, a2]
            
            guard var biquad = vDSP.Biquad(
                coefficients: coefficients,
                channelCount: 1,        // Single channel
                sectionCount: 1,        // Single biquad section
                ofType: Double.self
            ) else { continue }
            
            signalToFilter = biquad.apply(input: signalToFilter)
        }

        // 3. Normalize
        var maxAmp: Double = 0.0
        vDSP_maxvD(signalToFilter, 1, &maxAmp, vDSP_Length(nSamples))
        
        if maxAmp > 1e-5 {
            var scale = 0.9 / maxAmp
            vDSP_vsmulD(signalToFilter, 1, &scale, &signalToFilter, 1, vDSP_Length(nSamples))
        }
        
        return signalToFilter
    }
    
    static func findFormants(lpcCoefficients: [Double], sampleRate: Double) -> [Resonance] {
        let order = lpcCoefficients.count - 1
        guard order > 0 else { return [] }
        
        let reversedCoefficients = lpcCoefficients.reversed() as [Double]
        do {
            let roots = try CompanionMatrixRootFinder.findRoots(coefficients: reversedCoefficients)
            
            var resonances: [Resonance] = []
            for root in roots {
                if root.imaginary >= 0 && root.length > 0.7 && root.length < 1.0 {
                    let angle = root.phase
                    if angle > 0 {
                        let frequency = angle * sampleRate / (2.0 * Double.pi)
                        let bandwidth = -2.0 * log(root.length) * (sampleRate / (2.0 * Double.pi))
                        if frequency > 70 && bandwidth > 0 {
                            let q = frequency / bandwidth
                            if q > 2 && q < 80 {
                                resonances.append(Resonance(frequency: frequency, q: q))
                            }
                        }
                    }
                }
            }
            return resonances.sorted { $0.frequency < $1.frequency }
        } catch {
            print("Root finding error in findFormants: \(error)")
            return []
        }
    }

    static func mergeNearbyFormants(_ formants: [Resonance], minSeparationMel: Double) -> [Resonance] {
        guard !formants.isEmpty else { return [] }
        var merged: [Resonance] = [formants[0]]
        for formant in formants.dropFirst() {
            let last = merged.last!; let lastMel = hzToMel(last.frequency); let currentMel = hzToMel(formant.frequency)
            if currentMel - lastMel < minSeparationMel {
                let wLast = 1.0 / last.q; let wCurr = 1.0 / formant.q
                let mergedFreq = (last.frequency * wLast + formant.frequency * wCurr) / (wLast + wCurr)
                let mergedQ = min(last.q, formant.q)
                merged[merged.count - 1] = Resonance(frequency: mergedFreq, q: mergedQ)
            } else { merged.append(formant) }
        }
        return merged
    }
    
    static func hzToMel(_ hz: Double) -> Double { 2595.0 * log10(1.0 + hz / 700.0) }
    static func melToHz(_ mel: Double) -> Double { 700.0 * (pow(10.0, mel / 2595.0) - 1.0) }
}
