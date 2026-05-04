// MainView.swift
// (c) William Entriken
// See LICENSE

import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State var viewMode: ViewMode = MainView.initialViewMode()

    enum ViewMode: String, Identifiable {
        case formant = "Formants"
        case chart = "Charts"
        case help = "Help"

        var id: String { rawValue }
    }

    /// Allows UI tests (and tinkerers) to start the app on a particular page
    /// by passing `-viewMode formant|chart|help` on the command line.
    private static func initialViewMode() -> ViewMode {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-viewMode"), i + 1 < args.count else {
            return .formant
        }
        switch args[i + 1].lowercased() {
        case "formant", "formants": return .formant
        case "chart", "charts":     return .chart
        case "help":                return .help
        default:                    return .formant
        }
    }

    var body: some View {
        // Your existing ZStack and VStack structure is preserved.
        ZStack {
            VStack(spacing: 15) {
                // The toolbar is the only part that has been changed.
                toolbar
                    .padding(.horizontal)
                    .padding(.top)
                
                // This content switching logic remains exactly the same.
                ZStack {
                    switch viewMode {
                    case .formant:
                        // This view will now correctly update after a recording is processed.
                        FormantPageView(
                            formants: viewModel.formantAnalysis.formants,
                            vowels: viewModel.targetVowels
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity) // Apply frame directly
                    case .chart:
                        // The DetailPageView you already have.
                        DetailPageView()
                    case .help:
                        // The HelpPageView you already have.
                        HelpPageView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // The toolbar has been updated to be fully state-aware.
    private var toolbar: some View {
        HStack {
            Button {
                // The ACTION changes based on the current status.
                switch viewModel.status {
                case .idle, .ready, .error:
                    // If idle, ready, or after an error, start a new recording.
                    viewModel.startRecording()
                case .recording, .processing:
                    // Do nothing while processing. The button is disabled.
                    break
                }
            } label: {
                // The ICON also changes based on the current status.
                switch viewModel.status {
                case .idle, .ready, .error:
                    // "mic.fill" indicates "Ready to Record".
                    Image(systemName: "mic.fill")
                        .foregroundColor(.red)
                case .recording:
                    // "stop.fill" indicates "Tap to Stop". The pulse effect gives feedback.
                    Image(systemName: "stop.fill")
                        .foregroundColor(.red)
                        .symbolEffect(.pulse, options: .repeating)
                case .processing:
                    // A ProgressView provides clear feedback that work is happening.
                    ProgressView()
                        .frame(width: 44, height: 44) // Match size for layout consistency
                }
            }
            .font(.system(size: 44))
            // Disable the button while processing to prevent duplicate actions.
            .disabled(viewModel.status == .processing)

            Spacer()

            // Your view mode picker is preserved exactly as it was.
            Picker("Mode", selection: $viewMode) {
                Image(systemName: "waveform.path.ecg")
                    .tag(ViewMode.formant)
                Image(systemName: "chart.xyaxis.line")
                    .tag(ViewMode.chart)
                Image(systemName: "questionmark.circle.fill")
                    .tag(ViewMode.help)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)
        }
    }
}

// Preview remains the same.
#Preview {
    MainView()
        .environmentObject(AppViewModel())
}
