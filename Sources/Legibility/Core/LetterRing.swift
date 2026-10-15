//
//  LetterRing.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  How well letters stand out from what is around them, measured on the
//  finished picture: the WCAG ratio between the median luminance of the
//  letters' interior and the median of a thin ring of pixels just outside
//  them. A stroke, a plate or a shadow is in that ring and counts; so is a
//  bright patch of photograph pressing against thin white letters. A plain
//  average over the text's box would be wrong in both halves of a picture
//  that is dark on one side and bright on the other.
//

import CoreGraphics
import Foundation

public enum LetterRing {

    /// The contrast between `letters` (a mask over `composite`, top row
    /// first: the letters' fill alone, no outline or plate) and the ring
    /// touching them in `composite`, out to 3 reference points (at least 2
    /// pixels) — `referenceScale` is pixels per reference point. `nil` when
    /// there are no letters.
    public static func measure(composite: CGImage, letters: [Bool], referenceScale: Double) -> LetterContrast? {
        guard let parts = regions(letters: letters, width: composite.width, height: composite.height,
                                  referenceScale: referenceScale) else { return nil }
        let luminance = Pixels.luminances(of: composite)
        guard luminance.count == composite.width * composite.height,
              let text = Contrast.percentile(parts.interior.map { luminance[$0] }, 0.5),
              let surround = Contrast.percentile(parts.ring.map { luminance[$0] }, 0.5) else { return nil }
        return LetterContrast(ratio: Contrast.ratio(text, surround), text: text, surround: surround)
    }

    /// The letters' interior (one pixel in from the edge, where there is one)
    /// and the ring touching them, as pixel indexes; `nil` when there are no
    /// letters.
    public static func regions(letters: [Bool], width: Int, height: Int, referenceScale: Double)
        -> (interior: [Int], ring: [Int])? {
        guard letters.count == width * height, letters.contains(true) else { return nil }
        let outer = max(2, Int((3 * referenceScale).rounded()))
        let core = Morphology.eroded(letters, width: width, height: height, by: 1)
        let interior = core.contains(true) ? core : letters
        let far = Morphology.dilated(letters, width: width, height: height, by: outer)
        let ring = far.indices.filter { far[$0] && !letters[$0] }
        guard !ring.isEmpty else { return nil }
        return (interior.indices.filter { interior[$0] }, ring)
    }
}
