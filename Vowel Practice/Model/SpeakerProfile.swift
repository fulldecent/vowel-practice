// Vowel Practice
// (c) William Entriken
// See LICENSE

/// Models a speaker's vocal characteristics for formant classification.
struct SpeakerProfile {
    /// Available English dialect transformations.
    enum Dialect {
        case generalAmerican
        case northernCities(intensity: Double)      // Chicago, Detroit, Buffalo
        case southern(intensity: Double)            // Southern US
        case california                             // West Coast (cot-caught merger)
        case canadian                               // Canadian English
        case midAtlantic(intensity: Double)         // Philadelphia, Baltimore
        
        /// Apply dialect-specific transformations to formant values.
        /// Based on Labov, William & Ash, Sharon & Boberg, Charles. (2006). The Atlas of North American English: Phonetics, Phonology and Sound Change. 10.1515/9783110206838.
        func transform(vowel: String, f1: Double, f2: Double) -> (f1: Double, f2: Double) {
            switch self {
            case .generalAmerican:
                return (f1, f2)
                
            case .northernCities(let intensity):
                switch vowel {
                case "æ": return (f1 - 100 * intensity, f2 + 200 * intensity)  // Raised & fronted
                case "ɑ": return (f1, f2 + 150 * intensity)                    // Fronted
                case "ɔ": return (f1 + 50 * intensity, f2 + 100 * intensity)   // Fronted & lowered
                case "ʌ": return (f1, f2 - 150 * intensity)                    // Backed
                case "ɛ": return (f1 + 60 * intensity, f2 - 100 * intensity)   // Backed & lowered
                case "ɪ": return (f1 + 40 * intensity, f2 - 100 * intensity)   // Backed & lowered
                default: return (f1, f2)
                }
                
            case .southern(let intensity):
                // Front vowels backed and lowered
                switch vowel {
                case "ɪ", "ɛ", "æ": return (f1 + 50 * intensity, f2 - 100 * intensity)
                default: return (f1, f2)
                }
                
            case .california:
                switch vowel {
                case "ɑ", "ɔ":
                    // Cot-caught merger
                    let mergedF1 = (750 + 590) / 2.0  // Average of ɑ and ɔ
                    let mergedF2 = (940 + 880) / 2.0
                    return (mergedF1, mergedF2)
                case "u", "ʊ":
                    // Fronting
                    return (f1, f2 + 100)
                default: return (f1, f2)
                }
                
            case .canadian:
                switch vowel {
                case "æ": return (f1 + 50, f2 - 100)  // Backed & lowered
                case "ɛ": return (f1 + 40, f2 - 80)   // Backed & lowered
                case "ɪ": return (f1 + 30, f2)        // Lowered
                case "ɑ", "ɔ":
                    // Cot-caught merger
                    let mergedF1 = (750 + 590) / 2.0
                    let mergedF2 = (940 + 880) / 2.0
                    return (mergedF1, mergedF2)
                default: return (f1, f2)
                }
                
            case .midAtlantic(let intensity):
                switch vowel {
                case "æ":
                    // Raising before certain consonants
                    return (f1 - 80 * intensity, f2)
                default: return (f1, f2)
                }
            }
        }
    }
    
    enum VocalTractScalingDefaults: Double {
        case adultMale = 0.9
        case adultFemale = 1.1
        case child = 1.35
    }

    /// Vocal tract length scaling factor.
    /// - Males: 0.85–0.95 (longer vocal tract)
    /// - Females: 1.05–1.15 (shorter vocal tract)
    /// - Children: 1.25–1.40 (much shorter vocal tract)
    /// Based on tract size parameterization in Fitch WT, Giedd J. Morphology and development of the human vocal tract: a study using magnetic resonance imaging. J Acoust Soc Am. 1999 Sep;106(3 Pt 1):1511-22. doi: 10.1121/1.427148. PMID: 10489707.
    let vocalTractScaling: Double
    
    /// Dialect with optional intensity parameter (0.0 = none, 1.0 = maximum shift).
    let dialect: Dialect
    
    /// Base reference formant values for American English monophthongs.
    /// Values from adult male in  Hillenbrand, J., Getty, L. A., Clark, M. J., & Wheeler, K. (1995). Acoustic characteristics of American English vowels. Journal of the Acoustical Society of America, 97(5, Pt 1), 3099–3111. https://doi.org/10.1121/1.411872

    /// Including Wells keywords
    /// Based on Wells, J. C. (1982). Accents of English. Cambridge: Cambridge University Press. 
    static let baseVowels: [TherapeuticVowel] = [
        // High vowels
        TherapeuticVowel(
            symbol: "i",
            wellsKeyword: "FLEECE",
            commonWords: ["see", "beat", "me"],
            f1: 270, f2: 2290
        ),
        TherapeuticVowel(
            symbol: "ɪ",
            wellsKeyword: "KIT",
            commonWords: ["sit", "bit", "if"],
            f1: 390, f2: 1990
        ),
        TherapeuticVowel(
            symbol: "u",
            wellsKeyword: "GOOSE",
            commonWords: ["too", "boot", "food"],
            f1: 300, f2: 870
        ),
        TherapeuticVowel(
            symbol: "ʊ",
            wellsKeyword: "FOOT",
            commonWords: ["book", "put", "good"],
            f1: 380, f2: 950
        ),
        
        // Mid vowels
        TherapeuticVowel(
            symbol: "ɛ",
            wellsKeyword: "DRESS",
            commonWords: ["bed", "get", "tell"],
            f1: 610, f2: 1720
        ),
        TherapeuticVowel(
            symbol: "ə",
            wellsKeyword: "COMMA",
            commonWords: ["about", "sofa", "taken"],
            f1: 500, f2: 1500
        ),
        TherapeuticVowel(
            symbol: "ʌ",
            wellsKeyword: "STRUT",
            commonWords: ["but", "cup", "son"],
            f1: 640, f2: 1190
        ),
        
        // Low vowels
        TherapeuticVowel(
            symbol: "æ",
            wellsKeyword: "TRAP",
            commonWords: ["cat", "bad", "man"],
            f1: 660, f2: 1700
        ),
        TherapeuticVowel(
            symbol: "ɑ",
            wellsKeyword: "LOT",
            commonWords: ["cot", "on", "pot"],
            f1: 750, f2: 940
        ),
        TherapeuticVowel(
            symbol: "ɔ",
            wellsKeyword: "THOUGHT",
            commonWords: ["caught", "law", "fall"],
            f1: 590, f2: 880
        ),
        
        // ESL pedagogical vowels (not native American English monophthongs)
        // Uncomment these for learners whose L1 has pure /e/ and /o/ (Spanish, Italian, Japanese, etc.)
        // TherapeuticVowel(
        //     symbol: "e",
        //     wellsKeyword: "FACE (midpoint)",
        //     commonWords: ["Spanish: pese", "Italian: bene"],
        //     f1: 450, f2: 1900
        // ),
        // TherapeuticVowel(
        //     symbol: "o",
        //     wellsKeyword: "GOAT (midpoint)",
        //     commonWords: ["Spanish: poso", "Italian: dove"],
        //     f1: 400, f2: 800
        // ),
    ]
    
    /// Generate formant values for a specific vowel symbol using this speaker profile.
    func generateFormants(for symbol: String) -> (f1: Double, f2: Double)? {
        guard let baseVowel = Self.baseVowels.first(where: { $0.symbol == symbol }) else {
            return nil
        }
        
        // Step 1: Apply vocal tract length scaling
        var f1 = baseVowel.f1 * vocalTractScaling
        var f2 = baseVowel.f2 * vocalTractScaling
        
        // Step 2: Apply dialect transformation
        (f1, f2) = dialect.transform(vowel: symbol, f1: f1, f2: f2)
        
        return (f1, f2)
    }
    
    /// Generate all vowels with this speaker profile.
    func generateAllVowels() -> [TherapeuticVowel] {
        return Self.baseVowels.compactMap { vowel in
            guard let (f1, f2) = generateFormants(for: vowel.symbol) else {
                return nil
            }
            return TherapeuticVowel(
                symbol: vowel.symbol,
                wellsKeyword: vowel.wellsKeyword,
                commonWords: vowel.commonWords,
                f1: f1,
                f2: f2
            )
        }
    }
}
