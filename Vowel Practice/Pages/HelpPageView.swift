// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI

struct HelpPageView: View {
    var body: some View {
        ScrollView {
            Text(helpContent)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Help")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var helpContent: AttributedString {
        guard let url = Bundle.main.url(forResource: "help", withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8),
              let attributed = try? AttributedString(markdown: markdown, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) else {
            return AttributedString("Help content unavailable")
        }
        
        return attributed
    }
}

#Preview {
    NavigationStack {
        HelpPageView()
    }
}
