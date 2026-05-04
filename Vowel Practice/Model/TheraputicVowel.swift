// Vowel Practice
// (c) William Entriken
// See LICENSE

/// Represents a vowel with formant frequencies for speech therapy and accent training.
struct TherapeuticVowel {
    let symbol: String
    let wellsKeyword: String
    let commonWords: [String]
    let f1: Double  // First formant (Hz)
    let f2: Double  // Second formant (Hz)
}
