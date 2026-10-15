//
//  Contrast.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Contrast as WCAG 2 defines it: relative luminance of sRGB colours and the
//  (L1 + 0.05) / (L2 + 0.05) ratio. The thresholds are WCAG's own — 3:1 for
//  large text, 4.5:1 for normal text — not numbers tuned here.
//

import CoreGraphics
import Foundation

public enum Contrast {

    /// WCAG's minimum for large text (AA).
    public static let largeTextMinimum = 3.0

    /// WCAG's minimum for normal text (AA): what a plate is sized to reach.
    public static let normalTextMinimum = 4.5

    /// The darkest a plate is allowed to get (alpha) — beyond this it reads as
    /// a black box rather than a tint.
    public static let maximumPlateAlpha = 0.85

    /// The relative luminance of an sRGB colour (`0…1` channels).
    public static func luminance(red: Double, green: Double, blue: Double) -> Double {
        0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// The contrast ratio between two relative luminances, `1…21`.
    public static func ratio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The background luminance once a plate of `plate` luminance and
    /// `alpha` opacity is laid over `background`.
    public static func composited(background: Double, plate: Double, alpha: Double) -> Double {
        alpha * plate + (1 - alpha) * background
    }

    /// The least plate opacity (in steps of 0.05) that lifts `text` against
    /// `background` to `target`, with the plate black for light text and white
    /// for dark text; `nil` when even ``maximumPlateAlpha`` cannot, `0` when
    /// no plate is needed.
    public static func plateAlpha(text: Double, background: Double, target: Double = normalTextMinimum) -> Double? {
        if ratio(text, background) >= target { return 0 }
        let plate = plateLuminance(forText: text)
        var alpha = 0.0
        while alpha <= maximumPlateAlpha + 1e-9 {
            if ratio(text, composited(background: background, plate: plate, alpha: alpha)) >= target { return alpha }
            alpha += 0.05
        }
        return nil
    }

    /// Black behind light text, white behind dark text.
    public static func plateLuminance(forText text: Double) -> Double {
        ratio(text, 0) >= ratio(text, 1) ? 0 : 1
    }

    /// The relative luminance of the pixels of `image` inside `rect` (pixel
    /// coordinates, top-left origin), sampled on a grid of at most `grid`
    /// points a side.
    public static func luminances(in image: CGImage, rect: CGRect, grid: Int = 48) -> [Double] {
        let width = image.width, height = image.height
        guard let pixels = Pixels.rgba(of: image) else { return [] }
        let area = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !area.isNull, area.width >= 1, area.height >= 1 else { return [] }
        let steps = max(1, grid)
        var values: [Double] = []
        values.reserveCapacity(steps * steps)
        for row in 0..<steps {
            let y = min(height - 1, Int(area.minY + (Double(row) + 0.5) * area.height / Double(steps)))
            for column in 0..<steps {
                let x = min(width - 1, Int(area.minX + (Double(column) + 0.5) * area.width / Double(steps)))
                let offset = (y * width + x) * 4
                values.append(luminance(red: Double(pixels[offset]) / 255,
                                        green: Double(pixels[offset + 1]) / 255,
                                        blue: Double(pixels[offset + 2]) / 255))
            }
        }
        return values
    }

    /// The value at `fraction` (`0…1`) through `values` sorted ascending.
    public static func percentile(_ values: [Double], _ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let index = Int((Double(sorted.count - 1) * min(1, max(0, fraction))).rounded())
        return sorted[index]
    }

    private static func linear(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}
