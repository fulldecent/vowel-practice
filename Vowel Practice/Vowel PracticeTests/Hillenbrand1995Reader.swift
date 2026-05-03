// Vowel Practice
// (c) William Entriken
// See LICENSE

import Foundation

class Hillenbrand1995Reader {
    struct VowelData {
        /// The base name of the file
        let filename: String
        
        /// Time in seconds
        let duration: Double
        
        /// Fundamental frequency in Hz
        let f0: Double?
        
        /// First formant frequency in Hz
        let f1: Double?
        
        /// Second formant frequency in Hz
        let f2: Double?
        
        /// Third formant frequency in Hz
        let f3: Double?
        
        /// Fourth formant frequency in Hz
        let f4: Double?
    }
    
    /// True when the Hillenbrand 1995 data set is bundled with the test target.
    /// The data set is not redistributable and is excluded from the repository,
    /// so tests that depend on it should be conditionally enabled on this flag.
    static var isDataAvailable: Bool {
        let bundle = Bundle(for: Hillenbrand1995Reader.self)
        return bundle.url(forResource: "vowdata", withExtension: "dat") != nil
    }

    static func loadVowelData() -> [VowelData] {
        let bundle = Bundle(for: Hillenbrand1995Reader.self)
        guard let resourceURL = bundle.url(forResource: "vowdata", withExtension: "dat"),
              let fileContents = try? String(contentsOf: resourceURL, encoding: .utf8) else {
            return []
        }
        let dataLineRegex = /(?<filename>[mwbg]\d\d\w\w)(?<columns>(\W+\d+){15}?)/
        let dataLines = fileContents.split(whereSeparator: \.isNewline).compactMap { line in
            try! dataLineRegex.prefixMatch(in: line)?.output
        }

        return dataLines.map { dataLine in
            let filename = String(dataLine.filename + ".wav")
            let columnStrings = dataLine.columns.split(separator: " ")
            let columnNumbers = columnStrings.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            
            return VowelData(
                filename: filename,
                duration: columnNumbers[0] / 1000.0,
                f0: columnNumbers[1],
                f1: columnNumbers[2],
                f2: columnNumbers[3],
                f3: columnNumbers[4],
                f4: columnNumbers[5]
            )
        }
    }
}
