// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI

struct FormantPageView: View {
    let formants: [FormantAnalysis.Resonance]
    
    let vowels: [TherapeuticVowel]
    
    private let margin: CGFloat = 0.2
    
    var body: some View {
        VStack {
            FormantPlotView(formants: formants, vowels: vowels, margin: margin)
            if (formants.count > 0) {
                Text("Formant 1: \(String(format: "%.0f", formants[0].frequency)) Hz")
            }
            if (formants.count > 1) {
                Text("Formant 2: \(String(format: "%.0f", formants[1].frequency)) Hz")
            }
            if (formants.count > 2) {
                Text("Formant 3: \(String(format: "%.0f", formants[2].frequency)) Hz")
            }
        }
    }
}

fileprivate struct XAxisView: View {
    let f1AndNames: [(Double, String?)] = [
        (0, "closed"),
        (400, nil),
        (800, nil),
        (1200, "open"),
    ]
    
    private let tickLength: CGFloat = 10
    private let labelOffset: CGFloat = 25
    private let titleOffset: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                }
                .stroke(Color.black, lineWidth: 2)
                ForEach(f1AndNames, id: \.0) { value, name in
                    let scaledValue = (value - 0) / (1200 - 0)
                    let xPosition = geometry.size.width * CGFloat(scaledValue)
                    Path { path in
                        path.move(to: CGPoint(x: xPosition, y: 0))
                        path.addLine(to: CGPoint(x: xPosition, y: tickLength))
                    }
                    .stroke(Color.black, lineWidth: 1)
                    Text(name != nil ? "\(Int(value))\n\(name!)" : "\(Int(value))")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .position(x: xPosition, y: labelOffset)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                Text("formant 1 (Hz)")
                    .font(.caption)
                    .position(x: geometry.size.width / 2, y: titleOffset)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
        .frame(height: 60)
    }
}

fileprivate struct YAxisView: View {
    let f2AndNames: [(Double, String?)] = [
        (500, "back"),
        (1000, nil),
        (2000, nil),
        (4000, "front"),
    ]
    
    private let tickLength: CGFloat = 10
    private let labelOffset: CGFloat = 25
    private let titleOffset: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(Color.black, lineWidth: 2)
                ForEach(f2AndNames, id: \.0) { value, name in
                    let logValue = log10(value / 500) / log10(4000 / 500)
                    let yPosition = geometry.size.height * (1 - CGFloat(logValue))
                    Path { path in
                        path.move(to: CGPoint(x: geometry.size.width, y: yPosition))
                        path.addLine(to: CGPoint(x: geometry.size.width - tickLength, y: yPosition))
                    }
                    .stroke(Color.black, lineWidth: 1)
                    Text(name != nil ? "\(name!)\n\(Int(value))" : "\(Int(value))")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .rotationEffect(.degrees(-90))
                        .position(x: geometry.size.width - labelOffset, y: yPosition)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }
                Text("formant 2 (Hz)")
                    .font(.caption)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
                    .position(x: geometry.size.width - titleOffset, y: geometry.size.height / 2)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
            }
        }
        .frame(width: 60)
    }
}

#Preview {
    FormantPageView(
        formants: [
            .init(frequency: 600, q: 5),
            .init(frequency: 2000, q: 3),
            .init(frequency: 3000, q: 4),
        ],
        vowels: SpeakerProfile.baseVowels
    )
        //.frame(width: 400, height: 400)
}


// TODO: show the formant selected
/*
Circle()
    .fill(viewModel.status == .recording ? .red : (viewModel.currentInputSource == .microphone ? .green : .gray))
    .frame(width: 15, height: 15)
    .animation(.easeInOut, value: viewModel.status)
Picker("Input", selection: $viewModel.currentInputSource) {
    ForEach(InputSource.allCases) { source in
        Text(source.displayName).tag(source)
    }
}
 */

