//
//  LetterContrast.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// The contrast between letters and what touches them, as measured.
public struct LetterContrast: Codable, Equatable, Sendable {

    /// WCAG ratio, `1…21`.
    public var ratio: Double

    /// Median relative luminance of the letters' interior.
    public var text: Double

    /// Median relative luminance of the ring of pixels around them.
    public var surround: Double

    public init(ratio: Double, text: Double, surround: Double) {
        self.ratio = ratio
        self.text = text
        self.surround = surround
    }
}
