//
//  Pixels.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  A picture as bytes: premultiplied sRGB RGBA, top row first — the one
//  layout every measurement here reads.
//

import CoreGraphics
import Foundation

public enum Pixels {

    /// Premultiplied sRGB RGBA bytes of `image`, top row first; `nil` when it
    /// cannot be drawn.
    public static func rgba(of image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4,
                                          space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? bytes : nil
    }

    /// Pixels whose alpha is at least `threshold` (0…255), top row first.
    public static func mask(of image: CGImage, threshold: UInt8 = 128) -> [Bool] {
        rgba(of: image).map { pixels in stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] >= threshold } } ?? []
    }

    /// Every pixel's WCAG relative luminance, top row first.
    public static func luminances(of image: CGImage) -> [Double] {
        guard let pixels = rgba(of: image) else { return [] }
        return stride(from: 0, to: pixels.count, by: 4).map { offset in
            Contrast.luminance(red: Double(pixels[offset]) / 255, green: Double(pixels[offset + 1]) / 255,
                               blue: Double(pixels[offset + 2]) / 255)
        }
    }
}
