// Vowel Practice
// (c) William Entriken
// See LICENSE

import Numerics
import Accelerate

/**
 * COMPANION MATRIX EIGENVALUE POLYNOMIAL ROOT FINDER
 *
 * This is a numerical method for finding all roots of a polynomial simultaneously
 * by constructing the companion matrix and computing its eigenvalues using iOS Accelerate.
 *
 * WHEN TO USE THIS METHOD:
 * ✅ Polynomial degree ≥ 5 (for degrees 1-4, use analytical formulas)
 * ✅ Less than 1,000 roots (because memory usage scales O(N^2)
 * ✅ When numerical stability is critical
 * ✅ When all roots are needed simultaneously
 * ✅ When leveraging optimized BLAS/LAPACK is preferred
 *
 * WHEN TO CHOOSE A DIFFERENT ALGORITHM:
 * - When less than 5 roots, use analytical formulas
 * - When over 1,000 use a method that is O(N)
 *
 * iOS COMPATIBILITY:
 * - Works with iOS 16.6+ using available Accelerate functions
 * - Uses cblas/clapack interface with proper memory management
 */

struct CompanionMatrixRootFinder<T: Real> where T: BinaryFloatingPoint {
    
    /// Tolerance for considering a coefficient effectively zero (relative to coefficient magnitude)
    private static var coefficientTolerance: T { T(1e-12) }
    
    /// Tolerance for root validation
    private static var rootValidationTolerance: T { T(1e-10) }
    
    /**
     * Find all roots of a polynomial using the companion matrix eigenvalue method.
     *
     * For polynomial: a₀ + a₁x + a₂x² + ... + aₙxⁿ = 0
     *
     * - Parameter coefficients: Polynomial coefficients [a₀, a₁, a₂, ..., aₙ]
     *   where aₙ is the leading coefficient (must be non-zero)
     * - Returns: Array of all polynomial roots as Complex numbers
     * - Throws: PolynomialError for invalid input or computation failures
     */
    static func findRoots(coefficients: [T]) throws -> [Complex<T>] {
        // Input validation
        guard !coefficients.isEmpty else {
            throw PolynomialError.invalidInput("Empty coefficient array")
        }
        
        guard coefficients.count >= 2 else {
            throw PolynomialError.invalidInput("Polynomial must have degree ≥ 1 for root finding")
        }
        
        // Check for all-zero coefficients before trimming
        let maxAbsCoeff = coefficients.map(abs).max() ?? T.zero
        guard maxAbsCoeff > T.zero else {
            throw PolynomialError.invalidInput("All coefficients are zero")
        }
        
        // Remove leading zeros with adaptive tolerance
        let trimmedCoeffs = trimLeadingZeros(coefficients, maxCoefficient: maxAbsCoeff)
        guard !trimmedCoeffs.isEmpty else {
            throw PolynomialError.invalidInput("All significant coefficients are zero")
        }
        
        let degree = trimmedCoeffs.count - 1
        
        // Handle constant polynomial
        if degree == 0 {
            // Check if the constant is actually zero
            let constant = trimmedCoeffs[0]
            let adaptiveTolerance = max(coefficientTolerance, maxAbsCoeff * T(1e-15))
            if abs(constant) <= adaptiveTolerance {
                throw PolynomialError.invalidInput("Zero polynomial has no well-defined roots")
            }
            return [] // Non-zero constant polynomial has no roots
        }
        
        // Check for zero leading coefficient with adaptive tolerance
        let leadingCoeff = trimmedCoeffs.last!
        let adaptiveTolerance = max(coefficientTolerance, maxAbsCoeff * T(1e-15))
        guard abs(leadingCoeff) > adaptiveTolerance else {
            throw PolynomialError.invalidInput("Leading coefficient is effectively zero")
        }
        
        // Normalize coefficients by dividing by leading coefficient
        let normalizedCoeffs = trimmedCoeffs.dropLast().map { $0 / leadingCoeff }
        
        // Construct companion matrix
        let companionMatrix = constructCompanionMatrix(normalizedCoeffs: Array(normalizedCoeffs))
        
        // Compute eigenvalues using available iOS Accelerate functions
        let eigenvalues = try computeEigenvalues(matrix: companionMatrix, size: degree)
        
        // Validate and return roots
        let validatedRoots = validateRoots(eigenvalues, originalCoefficients: trimmedCoeffs)
        return validatedRoots
    }
    
    // MARK: - Private Implementation
    
    /**
     * Construct the companion matrix for polynomial coefficients.
     * Matrix is stored in column-major format for LAPACK compatibility.
     */
    private static func constructCompanionMatrix(normalizedCoeffs: [T]) -> [T] {
        let n = normalizedCoeffs.count // This is the degree
        var matrix = [T](repeating: T.zero, count: n * n)
        
        // Fill in column-major order
        for col in 0..<n {
            for row in 0..<n {
                let index = col * n + row
                
                if col == n - 1 {
                    // Last column: -cᵢ (negative of normalized coefficients)
                    matrix[index] = -normalizedCoeffs[row]
                } else if row == col + 1 {
                    // Subdiagonal: ones
                    matrix[index] = T(1.0)
                }
                // All other entries remain zero
            }
        }
        
        return matrix
    }
    
    /**
     * Compute eigenvalues using available iOS Accelerate functions.
     */
    private static func computeEigenvalues(matrix: [T], size: Int) throws -> [Complex<T>] {
        if T.self == Double.self {
            let doubleMatrix = matrix.map { Double($0) }
            let eigenvalues = try computeEigenvaluesDouble(matrix: doubleMatrix, size: size)
            return eigenvalues.map { Complex<T>(T($0.real), T($0.imaginary)) }
        } else if T.self == Float.self {
            let floatMatrix = matrix.map { Float($0) }
            let eigenvalues = try computeEigenvaluesFloat(matrix: floatMatrix, size: size)
            return eigenvalues.map { Complex<T>(T($0.real), T($0.imaginary)) }
        } else {
            throw PolynomialError.unsupportedPrecision("Only Float and Double precision supported")
        }
    }
    
    /**
     * Double-precision eigenvalue computation using available iOS CLAPACK interface.
     */
    private static func computeEigenvaluesDouble(matrix: [Double], size: Int) throws -> [Complex<Double>] {
        var matrixCopy = matrix
        var eigenvaluesReal = [Double](repeating: 0.0, count: size)
        var eigenvaluesImag = [Double](repeating: 0.0, count: size)
        
        // Parameters for DGEEV (must be var for inout parameters)
        var jobvl: Int8 = 78 // 'N' - don't compute left eigenvectors
        var jobvr: Int8 = 78 // 'N' - don't compute right eigenvectors
        var n = __CLPK_integer(size)
        var lda = __CLPK_integer(size)
        var ldvl = __CLPK_integer(size)
        var ldvr = __CLPK_integer(size)
        
        // Workspace query
        var workspaceSize: Double = 0
        var info: __CLPK_integer = 0
        var querySize: __CLPK_integer = -1
        
        // Query optimal workspace size
        dgeev_(&jobvl, &jobvr, &n, &matrixCopy, &lda,
               &eigenvaluesReal, &eigenvaluesImag,
               nil, &ldvl, nil, &ldvr,
               &workspaceSize, &querySize, &info)
        
        guard info == 0 else {
            throw PolynomialError.lapackError("DGEEV workspace query failed with info: \(info)")
        }
        
        // Allocate workspace and compute eigenvalues
        let optimalWorkspaceSize = Int(workspaceSize)
        var workspace = [Double](repeating: 0.0, count: optimalWorkspaceSize)
        var actualWorkspaceSize = __CLPK_integer(optimalWorkspaceSize)
        
        // Reset matrix for actual computation
        matrixCopy = matrix
        
        // Reset job parameters for second call
        jobvl = 78
        jobvr = 78
        
        dgeev_(&jobvl, &jobvr, &n, &matrixCopy, &lda,
               &eigenvaluesReal, &eigenvaluesImag,
               nil, &ldvl, nil, &ldvr,
               &workspace, &actualWorkspaceSize, &info)
        
        guard info == 0 else {
            throw PolynomialError.lapackError("DGEEV eigenvalue computation failed with info: \(info)")
        }
        
        return zip(eigenvaluesReal, eigenvaluesImag).map { Complex<Double>($0.0, $0.1) }
    }
    
    /**
     * Single-precision eigenvalue computation using available iOS CLAPACK interface.
     */
    private static func computeEigenvaluesFloat(matrix: [Float], size: Int) throws -> [Complex<Float>] {
        var matrixCopy = matrix
        var eigenvaluesReal = [Float](repeating: 0.0, count: size)
        var eigenvaluesImag = [Float](repeating: 0.0, count: size)
        
        // Parameters for SGEEV (must be var for inout parameters)
        var jobvl: Int8 = 78 // 'N' - don't compute left eigenvectors
        var jobvr: Int8 = 78 // 'N' - don't compute right eigenvectors
        var n = __CLPK_integer(size)
        var lda = __CLPK_integer(size)
        var ldvl = __CLPK_integer(size)
        var ldvr = __CLPK_integer(size)
        
        // Workspace query
        var workspaceSize: Float = 0
        var info: __CLPK_integer = 0
        var querySize: __CLPK_integer = -1
        
        // Query optimal workspace size
        sgeev_(&jobvl, &jobvr, &n, &matrixCopy, &lda,
               &eigenvaluesReal, &eigenvaluesImag,
               nil, &ldvl, nil, &ldvr,
               &workspaceSize, &querySize, &info)
        
        guard info == 0 else {
            throw PolynomialError.lapackError("SGEEV workspace query failed with info: \(info)")
        }
        
        // Allocate workspace and compute eigenvalues
        let optimalWorkspaceSize = Int(workspaceSize)
        var workspace = [Float](repeating: 0.0, count: optimalWorkspaceSize)
        var actualWorkspaceSize = __CLPK_integer(optimalWorkspaceSize)
        
        // Reset matrix for actual computation
        matrixCopy = matrix
        
        // Reset job parameters for second call
        jobvl = 78
        jobvr = 78
        
        sgeev_(&jobvl, &jobvr, &n, &matrixCopy, &lda,
               &eigenvaluesReal, &eigenvaluesImag,
               nil, &ldvl, nil, &ldvr,
               &workspace, &actualWorkspaceSize, &info)
        
        guard info == 0 else {
            throw PolynomialError.lapackError("SGEEV eigenvalue computation failed with info: \(info)")
        }
        
        return zip(eigenvaluesReal, eigenvaluesImag).map { Complex<Float>($0.0, $0.1) }
    }
    
    /**
     * Remove leading zero coefficients from polynomial with adaptive tolerance.
     */
    private static func trimLeadingZeros(_ coefficients: [T], maxCoefficient: T) -> [T] {
        // Use adaptive tolerance based on the scale of coefficients
        let adaptiveTolerance = max(coefficientTolerance, maxCoefficient * T(1e-15))
        
        var trimmed = coefficients
        while trimmed.count > 1 && abs(trimmed.last!) <= adaptiveTolerance {
            trimmed.removeLast()
        }
        return trimmed
    }
    
    /**
     * Validate computed roots by substituting back into original polynomial.
     */
    private static func validateRoots(_ roots: [Complex<T>], originalCoefficients: [T]) -> [Complex<T>] {
        return roots.filter { root in
            let evaluation = evaluatePolynomial(coefficients: originalCoefficients, at: root)
            let magnitude = evaluation.length
            if magnitude > rootValidationTolerance {
                print("Warning: Root \(root) has large residual: \(magnitude)")
            }
            return magnitude <= T(100) * rootValidationTolerance
        }
    }
    
    /**
     * Evaluate polynomial at a given complex point using Horner's method.
     */
    private static func evaluatePolynomial(coefficients: [T], at point: Complex<T>) -> Complex<T> {
        guard !coefficients.isEmpty else { return Complex<T>.zero }
        
        var result = Complex<T>(coefficients.last!, T.zero)
        for i in stride(from: coefficients.count - 2, through: 0, by: -1) {
            result = result * point + Complex<T>(coefficients[i], T.zero)
        }
        return result
    }
}

// MARK: - Error Types

enum PolynomialError: Error, CustomStringConvertible {
    case invalidInput(String)
    case lapackError(String)
    case unsupportedPrecision(String)
    case numericalInstability(String)
    
    var description: String {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .lapackError(let message):
            return "LAPACK error: \(message)"
        case .unsupportedPrecision(let message):
            return "Unsupported precision: \(message)"
        case .numericalInstability(let message):
            return "Numerical instability: \(message)"
        }
    }
}
