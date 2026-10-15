//
//  Morphology.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Growing and shrinking a pixel mask: the ring around letters is the
//  letters grown, minus the letters; their interior is the letters shrunk.
//

import Foundation

public enum Morphology {

    /// `mask` grown by `radius` pixels (a square neighbourhood).
    public static func dilated(_ mask: [Bool], width: Int, height: Int, by radius: Int) -> [Bool] {
        morph(mask, width: width, height: height, radius: radius, grow: true)
    }

    /// `mask` shrunk by `radius` pixels.
    public static func eroded(_ mask: [Bool], width: Int, height: Int, by radius: Int) -> [Bool] {
        morph(mask, width: width, height: height, radius: radius, grow: false)
    }

    /// Separable square max (grow) or min (shrink) filter.
    static func morph(_ mask: [Bool], width: Int, height: Int, radius: Int, grow: Bool) -> [Bool] {
        guard radius > 0, mask.count == width * height, width > 0, height > 0 else { return mask }
        var rows = mask
        for y in 0..<height {
            let base = y * width
            for x in 0..<width {
                var hit = !grow
                for dx in max(0, x - radius)...min(width - 1, x + radius) where mask[base + dx] == grow {
                    hit = grow
                    break
                }
                rows[base + x] = hit
            }
        }
        var result = rows
        for x in 0..<width {
            for y in 0..<height {
                var hit = !grow
                for dy in max(0, y - radius)...min(height - 1, y + radius) where rows[dy * width + x] == grow {
                    hit = grow
                    break
                }
                result[y * width + x] = hit
            }
        }
        return result
    }
}
