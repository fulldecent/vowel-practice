// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI

// MARK: - Range scaling

/// Scales a closed range by expanding or contracting it from its center point.
/// A scale factor of 2.0 doubles the range size by extending both edges equally.
func scaleRange<T: BinaryFloatingPoint>(
    _ range: ClosedRange<T>,
    by scaleFactor: T
) -> ClosedRange<T> {
    let center = (range.lowerBound + range.upperBound) / 2
    let halfSpan = (range.upperBound - range.lowerBound) / 2
    let scaledHalfSpan = halfSpan * scaleFactor
    
    return (center - scaledHalfSpan)...(center + scaledHalfSpan)
}

// MARK: - Formant Plot View

struct FormantPlotView: View {
    let formants: [FormantAnalysis.Resonance]
    let vowels: [TherapeuticVowel]
    let margin: Double
    
    private let axisFraction: CGFloat = 0.06
    private let minOvalSize: CGFloat = 15  // Minimum oval dimension in points
    
    // MARK: - Computed plot ranges
    
    private var f1HzRange: ClosedRange<Double> {
        guard let minF1 = vowels.map(\.f1).min(),
              let maxF1 = vowels.map(\.f1).max() else {
            return 200...800
        }
        return scaleRange(minF1...maxF1, by: 1.0 + margin)
    }
    
    private var f2HzRange: ClosedRange<Double> {
        guard let minF2 = vowels.map(\.f2).min(),
              let maxF2 = vowels.map(\.f2).max() else {
            return 500...3000
        }
        return scaleRange(minF2...maxF2, by: 1.0 + margin)
    }
    
    private var plotF1MelRange: ClosedRange<Double> {
        hzToMels(f1HzRange.lowerBound)...hzToMels(f1HzRange.upperBound)
    }
    
    private var plotF2MelRange: ClosedRange<Double> {
        hzToMels(f2HzRange.lowerBound)...hzToMels(f2HzRange.upperBound)
    }
    
    // MARK: - Coordinate transformations
    
    private func hzToMels(_ hz: Double) -> Double {
        // log() is natural logarithm
        1125 * log(1 + (hz / 700))
    }
    
    private func formantToScaledCoordinates(_ f1: Double, _ f2: Double) -> (x: CGFloat, y: CGFloat) {
        let f1Mels = hzToMels(f1)
        let f2Mels = hzToMels(f2)
        
        return (
            x: 1 - CGFloat((f2Mels - plotF2MelRange.lowerBound) / (plotF2MelRange.upperBound - plotF2MelRange.lowerBound)),
            y: CGFloat((f1Mels - plotF1MelRange.lowerBound) / (plotF1MelRange.upperBound - plotF1MelRange.lowerBound))
        )
    }
    
    /// Convert a bandwidth in Hz to a fractional size in Mel-scaled coordinates.
    private func bandwidthToMelFraction(
        centerFreq: Double,
        bandwidth: Double,
        melRange: ClosedRange<Double>
    ) -> CGFloat {
        let lowerFreq = max(centerFreq - bandwidth / 2, 1.0)
        let upperFreq = centerFreq + bandwidth / 2
        
        let lowerMel = hzToMels(lowerFreq)
        let upperMel = hzToMels(upperFreq)
        let bandwidthMels = upperMel - lowerMel
        
        let melSpan = melRange.upperBound - melRange.lowerBound
        
        return CGFloat(bandwidthMels / melSpan)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    YAxisView2()
                        .frame(width: size * axisFraction)
                    
                    ZStack(alignment: .bottomLeading) {
                        VoronoiView(points: vowels.map { vowel in
                            let scaledCoordinates = formantToScaledCoordinates(vowel.f1, vowel.f2)
                            return (text: vowel.symbol, x: scaledCoordinates.x, y: scaledCoordinates.y)
                        })
                        
                        GeometryReader { geometry in
                            // Draw F1-F2 point (black oval)
                            if formants.count > 1 {
                                let f1 = formants[0]
                                let f2 = formants[1]
                                let scaledLocation = formantToScaledCoordinates(f1.frequency, f2.frequency)
                                
                                let widthFraction = bandwidthToMelFraction(
                                    centerFreq: f2.frequency,
                                    bandwidth: f2.bandwidth,
                                    melRange: plotF2MelRange
                                )
                                let heightFraction = bandwidthToMelFraction(
                                    centerFreq: f1.frequency,
                                    bandwidth: f1.bandwidth,
                                    melRange: plotF1MelRange
                                )
                                
                                Ellipse()
                                    .fill(Color.black)
                                    .opacity(0.7)
                                    .frame(
                                        width: max(geometry.size.width * widthFraction, minOvalSize),
                                        height: max(geometry.size.height * heightFraction, minOvalSize)
                                    )
                                    .position(
                                        x: geometry.size.width * scaledLocation.x,
                                        y: geometry.size.height * scaledLocation.y
                                    )
                            }
                            
                            // Draw F1-F3 point (gray oval)
                            if formants.count > 2 {
                                let f1 = formants[0]
                                let f3 = formants[2]
                                let scaledLocation = formantToScaledCoordinates(f1.frequency, f3.frequency)
                                
                                let widthFraction = bandwidthToMelFraction(
                                    centerFreq: f3.frequency,
                                    bandwidth: f3.bandwidth,
                                    melRange: plotF2MelRange
                                )
                                let heightFraction = bandwidthToMelFraction(
                                    centerFreq: f1.frequency,
                                    bandwidth: f1.bandwidth,
                                    melRange: plotF1MelRange
                                )
                                
                                Ellipse()
                                    .fill(Color.gray)
                                    .frame(
                                        width: max(geometry.size.width * widthFraction, minOvalSize),
                                        height: max(geometry.size.height * heightFraction, minOvalSize)
                                    )
                                    .position(
                                        x: geometry.size.width * scaledLocation.x,
                                        y: geometry.size.height * scaledLocation.y
                                    )
                            }
                        }
                    }
                }
                
                GridRow {
                    Spacer()
                        .frame(width: size * axisFraction)
                    XAxisView2()
                }
                .frame(height: size * axisFraction)
            }
            .frame(width: size, height: size)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Axis Views

fileprivate struct XAxisView2: View {
    var body: some View {
        HStack {
            Text("Front")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("<-- Formant 2")
                .frame(maxWidth: .infinity, alignment: .center)
            Text("Back")
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .foregroundStyle(.blue)
    }
}

fileprivate struct YAxisView2: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Closed")
                .rotated()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Text("<-- Formant 1")
                .rotated()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            Text("Open")
                .rotated()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .foregroundStyle(.blue)
    }
}

// MARK: - Preview

#Preview {
    FormantPlotView(
        formants: [
            FormantAnalysis.Resonance(frequency: 600, q: 10),   // F1: 60 Hz bandwidth
            FormantAnalysis.Resonance(frequency: 2000, q: 15),  // F2: 133 Hz bandwidth
            FormantAnalysis.Resonance(frequency: 3000, q: 20)   // F3: 150 Hz bandwidth
        ],
        vowels: SpeakerProfile.baseVowels,
        margin: 0.2
    )
}

// MARK: - Rotation helper

private struct SizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func captureSize(in binding: Binding<CGSize>) -> some View {
        overlay(GeometryReader { proxy in
            Color.clear.preference(key: SizeKey.self, value: proxy.size)
        })
        .onPreferenceChange(SizeKey.self) { size in binding.wrappedValue = size }
    }
}

struct Rotated<Rotated: View>: View {
    var view: Rotated
    var angle: Angle

    init(_ view: Rotated, angle: Angle = .degrees(-90)) {
        self.view = view
        self.angle = angle
    }

    @State private var size: CGSize = .zero

    var body: some View {
        let newFrame = CGRect(origin: .zero, size: size)
            .offsetBy(dx: -size.width/2, dy: -size.height/2)
            .applying(.init(rotationAngle: CGFloat(angle.radians)))
            .integral

        view
            .fixedSize()
            .captureSize(in: $size)
            .rotationEffect(angle)
            .frame(width: newFrame.width, height: newFrame.height)
    }
}

extension View {
    func rotated(angle: Angle = .degrees(-90)) -> some View {
        Rotated(self, angle: angle)
    }
}
