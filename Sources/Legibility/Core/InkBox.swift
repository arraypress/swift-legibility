//
//  InkBox.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Where something actually drew, measured on its pixels rather than on its
//  layout box. A text block sits inside its frame; its outline, shadow, glow
//  or plate reaches past it, and that difference is what ends up clipped or
//  under a platform's buttons.
//

import CoreGraphics
import Foundation

public enum InkBox {

    /// Alpha above which a pixel counts as drawn (about 8%: a soft shadow's
    /// faint tail does not count, its body does).
    public static let alphaFloor: UInt8 = 20

    /// The bounds of the drawn pixels of `layer` (a picture of one thing on
    /// transparency), in pixels, top-left origin; `nil` when nothing drew.
    public static func bounds(of layer: CGImage, alphaFloor: UInt8 = alphaFloor) -> CGRect? {
        guard let pixels = Pixels.rgba(of: layer) else { return nil }
        return bounds(rgba: pixels, width: layer.width, height: layer.height, alphaFloor: alphaFloor)
    }

    /// ``bounds(of:alphaFloor:)`` over bytes already read.
    public static func bounds(rgba pixels: [UInt8], width: Int, height: Int, alphaFloor: UInt8 = alphaFloor) -> CGRect? {
        guard pixels.count == width * height * 4 else { return nil }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where pixels[(row + x) * 4 + 3] > alphaFloor {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The same, as fractions of the picture (`0…1`, top-left).
    public static func normalizedBounds(of layer: CGImage, alphaFloor: UInt8 = alphaFloor) -> CGRect? {
        bounds(of: layer, alphaFloor: alphaFloor).map {
            CGRect(x: $0.minX / CGFloat(layer.width), y: $0.minY / CGFloat(layer.height),
                   width: $0.width / CGFloat(layer.width), height: $0.height / CGFloat(layer.height))
        }
    }

    /// How far `ink` reaches past `area` (both in the same units and origin).
    public static func overflow(_ ink: CGRect, inside area: CGRect) -> Overflow {
        Overflow(top: max(0, area.minY - ink.minY), bottom: max(0, ink.maxY - area.maxY),
                 left: max(0, area.minX - ink.minX), right: max(0, ink.maxX - area.maxX))
    }
}
