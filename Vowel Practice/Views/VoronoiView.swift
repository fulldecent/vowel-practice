// Vowel Practice
// (c) William Entriken
// See LICENSE

import SwiftUI
// log() is natural logarithm

// MARK: - Constants

private let spatialTolerance = 1e-8
private let evaluationTolerance = 1e-9
private let parallelTolerance = 1e-12

// MARK: - Voronoi diagram

/// Computes and renders a Voronoi diagram from labeled 2D points.
struct VoronoiDiagram {
    
    // MARK: - Basic types
    
    /// Simple 2D point in canvas coordinate space.
    /// Origin (0,0) is top-left, y increases downward.
    struct Point {
        let x: Double
        let y: Double
    }
    
    /// Each site has a label (`text`) and a 2D location (`position`).
    struct Site {
        let text: String
        let position: Point
    }
    
    /// A single Voronoi cell: contains one `site` and the polygon vertices (CCW order).
    struct Cell {
        let site: Site
        let vertices: [Point]
    }
    
    /// A line in the form a·x + b·y + c = 0.
    struct Line {
        let a: Double
        let b: Double
        let c: Double
        
        /// Evaluate the line equation at point p: returns a·p.x + b·p.y + c.
        /// If > 0 → one side, < 0 → the other side, = 0 → exactly on the line.
        func evaluate(at point: Point) -> Double {
            return a * point.x + b * point.y + c
        }
        
        /// Intersect this line with another line. Returns nil if parallel.
        func intersect(with other: Line) -> Point? {
            let determinant = a * other.b - b * other.a
            guard abs(determinant) >= parallelTolerance else {
                return nil
            }
            // Cramer's rule:
            //   a1·x + b1·y + c1 = 0
            //   a2·x + b2·y + c2 = 0
            let x = (b * other.c - c * other.b) / determinant
            let y = (c * other.a - a * other.c) / determinant
            return Point(x: x, y: y)
        }
    }
    
    // MARK: - Properties
    
    let sites: [Site]
    let width: Double
    let height: Double
    
    // MARK: - Cell computation
    
    /// Compute Voronoi cells by starting with the full rectangle [0..width]×[0..height],
    /// then clipping by each perpendicular-bisector half-plane for every other site.
    func computeCells() -> [Cell] {
        guard !sites.isEmpty else { return [] }
        guard width > 0, height > 0 else { return [] }
        
        let initialRectangle: [Point] = [
            Point(x: 0, y: 0),
            Point(x: width, y: 0),
            Point(x: width, y: height),
            Point(x: 0, y: height)
        ]
        
        var cells: [Cell] = []
        cells.reserveCapacity(sites.count)
        
        for site in sites {
            var polygon = initialRectangle
            
            for other in sites where other.text != site.text {
                let perpendicularBisector = computePerpendicularBisector(
                    between: site.position,
                    and: other.position
                )
                let evaluationAtSite = perpendicularBisector.evaluate(at: site.position)
                let keepLessOrEqual = (evaluationAtSite <= 0)
                
                polygon = clipPolygon(
                    polygon,
                    by: perpendicularBisector,
                    keepingSideIsLessEqual: keepLessOrEqual
                )
                
                guard polygon.count >= 3 else {
                    break
                }
            }
            
            let cleanedVertices = removeNearDuplicateVertices(from: polygon)
            if cleanedVertices.count >= 3 {
                cells.append(Cell(site: site, vertices: cleanedVertices))
            }
        }
        return cells
    }
    
    // MARK: - Private helpers
    
    /// Compute the perpendicular bisector between two points.
    private func computePerpendicularBisector(between p1: Point, and p2: Point) -> Line {
        let midX = (p1.x + p2.x) / 2.0
        let midY = (p1.y + p2.y) / 2.0
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        // The normal vector to the perpendicular bisector is (dx, dy).
        // For the line equation a·x + b·y + c = 0, we have a = dx and b = dy.
        let a = dx
        let b = dy
        let c = -(a * midX + b * midY)
        
        return Line(a: a, b: b, c: c)
    }
    
    /// Given a segment from p1 → p2, returns the supporting line (a·x + b·y + c = 0).
    private func lineFromSegment(_ p1: Point, _ p2: Point) -> Line {
        // Standard formula: (y2 – y1)·x + (x1 – x2)·y + [x2·y1 – x1·y2] = 0
        let a = p2.y - p1.y
        let b = p1.x - p2.x
        let c = p2.x * p1.y - p1.x * p2.y
        return Line(a: a, b: b, c: c)
    }
    
    /// Clip a convex polygon using the Sutherland–Hodgman algorithm.
    /// This is a one-pass clipping against a single half-plane defined by `line`.
    ///
    /// - Parameters:
    ///   - polygon: Input convex polygon (vertices in CCW order)
    ///   - line: Clipping line in form a·x + b·y + c = 0
    ///   - keepLessOrEqual: If true, keep points where evaluate(at:) ≤ 0; else keep ≥ 0
    /// - Returns: Clipped polygon (still CCW), possibly empty
    private func clipPolygon(
        _ polygon: [Point],
        by line: Line,
        keepingSideIsLessEqual keepLessOrEqual: Bool
    ) -> [Point] {
        guard !polygon.isEmpty else { return [] }
        var result: [Point] = []
        
        func isInside(_ point: Point) -> Bool {
            let value = line.evaluate(at: point)
            return keepLessOrEqual ? (value <= evaluationTolerance) : (value >= -evaluationTolerance)
        }
        
        for i in 0..<polygon.count {
            let current = polygon[i]
            let next = polygon[(i + 1) % polygon.count]
            let currentInside = isInside(current)
            let nextInside = isInside(next)
            
            switch (currentInside, nextInside) {
            case (true, true):
                result.append(next)
            case (true, false):
                if let intersection = lineFromSegment(current, next).intersect(with: line) {
                    result.append(intersection)
                }
            case (false, true):
                if let intersection = lineFromSegment(current, next).intersect(with: line) {
                    result.append(intersection)
                }
                result.append(next)
            case (false, false):
                break
            }
        }
        return result
    }
    
    /// Remove any two consecutive vertices that are within tolerance of each other,
    /// and also drop the final if it duplicates the first. Assumes vertices are in CCW order.
    private func removeNearDuplicateVertices(from vertices: [Point]) -> [Point] {
        guard !vertices.isEmpty else { return [] }
        var result: [Point] = [vertices[0]]
        
        for i in 1..<vertices.count {
            let previous = result.last!
            let current = vertices[i]
            let distance = hypot(previous.x - current.x, previous.y - current.y)
            if distance > spatialTolerance {
                result.append(current)
            }
        }
        
        // Drop last if nearly the same as first
        guard result.count >= 2 else { return result }
        
        let firstPoint = result[0]
        guard let lastPoint = result.last else { return result }
        
        let distance = hypot(firstPoint.x - lastPoint.x, firstPoint.y - lastPoint.y)
        if distance < spatialTolerance {
            result.removeLast()
        }
        
        return result
    }
}

// MARK: - SwiftUI view

/// The SwiftUI view that draws the Voronoi diagram.
struct VoronoiView: View {
    
    // MARK: - Input
    
    /// Input points with labels and normalized coordinates in [0...1] range.
    let points: [(text: String, x: Double, y: Double)]
    
    // MARK: - Styling
    
    private let cellOpacity: Double = 0.4
    private let labelFontSize: CGFloat = 14
    
    private let baseColors: [Color] = [
        .red, .blue, .green, .purple, .cyan,
        .yellow, .orange, .brown, .pink, .teal,
        Color(red: 0.20, green: 0.8, blue: 0.19),
        .gray, Color(red: 0.5, green: 0.5, blue: 0),
        Color(red: 0, green: 0, blue: 0.5), Color(red: 0.5, green: 0, blue: 0),
        Color(red: 0.93, green: 0.51, blue: 0.93), Color(red: 1, green: 0.84, blue: 0),
        Color(red: 1, green: 0.5, blue: 0.31), Color(red: 0.53, green: 0.81, blue: 0.92),
        Color(red: 0.8, green: 0.47, blue: 0.65)
    ]
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            let canvasWidth = Double(geometry.size.width)
            let canvasHeight = Double(geometry.size.height)
            
            let sites: [VoronoiDiagram.Site] = points.map { point in
                let pixelX = point.x * canvasWidth
                let pixelY = point.y * canvasHeight
                return VoronoiDiagram.Site(
                    text: point.text,
                    position: VoronoiDiagram.Point(x: pixelX, y: pixelY)
                )
            }
            
            let diagram = VoronoiDiagram(sites: sites, width: canvasWidth, height: canvasHeight)
            let cells = diagram.computeCells()
            
            Canvas { context, size in
                // White background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.white)
                )
                
                // Draw Voronoi cells
                for (index, cell) in cells.enumerated() {
                    let shape = CellShape(vertices: cell.vertices)
                    let color = baseColors[index % baseColors.count].opacity(cellOpacity)
                    context.fill(
                        shape.path(in: CGRect(origin: .zero, size: size)),
                        with: .color(color)
                    )
                }
                
                // Draw each site's label at its position
                for site in sites {
                    let pixelX = site.position.x
                    let pixelY = site.position.y
                    
                    let text = Text(site.text)
                        .font(.system(size: labelFontSize, weight: .bold))
                        .foregroundColor(.black)
                    
                    context.draw(text, at: CGPoint(x: pixelX, y: pixelY))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    // MARK: - Cell shape
    
    /// A Shape that draws a single Voronoi cell (polygon) from vertices.
    private struct CellShape: Shape {
        let vertices: [VoronoiDiagram.Point]
        
        func path(in rect: CGRect) -> Path {
            var path = Path()
            guard vertices.count >= 3 else { return path }
            path.move(to: CGPoint(x: vertices[0].x, y: vertices[0].y))
            for vertex in vertices.dropFirst() {
                path.addLine(to: CGPoint(x: vertex.x, y: vertex.y))
            }
            path.closeSubpath()
            return path
        }
    }
}

// MARK: - Preview

struct VoronoiView_Previews: PreviewProvider {
    
    /// Converts frequency to mel scale.
    static func frequencyToMel(_ frequency: Double) -> Double {
        return 1125 * log(1 + frequency / 700)
    }
    
    /// Normalizes vowels to a 2D point in [0...1] Mel space.
    struct VowelNormalizer {
        let f1HzRange: ClosedRange<Double>
        let f2HzRange: ClosedRange<Double>
        
        // Computed Mel ranges from Hz ranges
        private var f1MelRange: ClosedRange<Double> {
            let minMel = frequencyToMel(f1HzRange.lowerBound)
            let maxMel = frequencyToMel(f1HzRange.upperBound)
            return minMel...maxMel
        }
        
        private var f2MelRange: ClosedRange<Double> {
            let minMel = frequencyToMel(f2HzRange.lowerBound)
            let maxMel = frequencyToMel(f2HzRange.upperBound)
            return minMel...maxMel
        }
        
        /// Normalize a therapeutic vowel to [0...1] coordinates using Mel-scale spacing.
        func normalize(_ vowel: TherapeuticVowel) -> (text: String, x: Double, y: Double) {
            let melF1 = frequencyToMel(vowel.f1)
            let melF2 = frequencyToMel(vowel.f2)
            
            let x = (melF1 - f1MelRange.lowerBound) / (f1MelRange.upperBound - f1MelRange.lowerBound)
            let y = (melF2 - f2MelRange.lowerBound) / (f2MelRange.upperBound - f2MelRange.lowerBound)
            
            return (text: vowel.symbol, x: x, y: y)
        }
    }

    // MARK: - Vowel data
    static let vowels = SpeakerProfile(
        vocalTractScaling: SpeakerProfile.VocalTractScalingDefaults.adultMale.rawValue,
        dialect: .generalAmerican
    ).generateAllVowels()
    
    // MARK: - Preview
    
    static var previews: some View {
        // Normalize
        let normalizer = VowelNormalizer(
            f1HzRange: 150...1200,
            f2HzRange: 600...3500
        )
        
        let normalizedPoints = vowels.map { normalizer.normalize($0) }
        
        return AnyView(
            VoronoiView(points: normalizedPoints)
                .frame(width: 400, height: 400)
        )
    }
}
