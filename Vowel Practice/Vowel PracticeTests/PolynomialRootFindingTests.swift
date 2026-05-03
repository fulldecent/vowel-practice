// Vowel Practice
// (c) William Entriken
// See LICENSE

import Testing
import Foundation
import Numerics
@testable import Vowel_Practice

struct PolynomialRootFindingTests {

    /// Linear polynomial: 2x + 4 = 0  =>  x = -2
    @Test func linearRoot() throws {
        let roots = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [4, 2])
        #expect(roots.count == 1)
        #expect(abs(roots[0].real - (-2)) < 1e-9)
        #expect(abs(roots[0].imaginary) < 1e-9)
    }

    /// Quadratic polynomial: x^2 - 5x + 6 = 0  =>  roots {2, 3}
    @Test func quadraticRealRoots() throws {
        let roots = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [6, -5, 1])
        #expect(roots.count == 2)
        let realParts = roots.map(\.real).sorted()
        #expect(abs(realParts[0] - 2) < 1e-9)
        #expect(abs(realParts[1] - 3) < 1e-9)
        for root in roots {
            #expect(abs(root.imaginary) < 1e-9)
        }
    }

    /// Quadratic polynomial with complex roots: x^2 + 1 = 0  =>  roots {i, -i}
    @Test func quadraticComplexRoots() throws {
        let roots = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [1, 0, 1])
        #expect(roots.count == 2)
        for root in roots {
            #expect(abs(root.real) < 1e-9)
            #expect(abs(abs(root.imaginary) - 1) < 1e-9)
        }
        let imaginaryParts = roots.map(\.imaginary).sorted()
        #expect(imaginaryParts[0] < 0 && imaginaryParts[1] > 0)
    }

    /// Polynomial with known roots {1, 2, 3, 4, 5} expanded:
    /// (x-1)(x-2)(x-3)(x-4)(x-5) = x^5 - 15x^4 + 85x^3 - 225x^2 + 274x - 120
    @Test func degreeFivePolynomial() throws {
        let coefficients: [Double] = [-120, 274, -225, 85, -15, 1]
        let roots = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: coefficients)
        #expect(roots.count == 5)
        let realParts = roots.map(\.real).sorted()
        let expected: [Double] = [1, 2, 3, 4, 5]
        for (got, want) in zip(realParts, expected) {
            #expect(abs(got - want) < 1e-7)
        }
        for root in roots {
            #expect(abs(root.imaginary) < 1e-7)
        }
    }

    /// An empty coefficient array is invalid input.
    @Test func emptyCoefficientsThrows() {
        #expect(throws: PolynomialError.self) {
            _ = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [])
        }
    }

    /// All-zero coefficients are invalid input.
    @Test func allZeroCoefficientsThrows() {
        #expect(throws: PolynomialError.self) {
            _ = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [0, 0, 0])
        }
    }

    /// A non-zero constant polynomial has no roots.
    @Test func constantPolynomialThrows() {
        // After trimming leading zeros, this is the constant polynomial 7.
        #expect(throws: PolynomialError.self) {
            _ = try CompanionMatrixRootFinder<Double>.findRoots(coefficients: [7])
        }
    }
}
