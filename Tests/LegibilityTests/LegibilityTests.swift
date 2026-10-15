//
//  LegibilityTests.swift
//  LegibilityTests
//
//  Created by David Sherlock on 2026.
//
//  Every measurement against a picture whose answer is known: a box drawn at
//  a known place, white letters on black and on near-white, and words drawn
//  large enough that recognition must read them.
//

import CoreGraphics
import CoreText
import Foundation
import Testing
@testable import Legibility

struct LegibilityTests {

    /// A transparent picture with `draw` run into it (CoreGraphics origin bottom-left).
    static func picture(width: Int, height: Int, fill: CGColor? = nil, _ draw: (CGContext) -> Void = { _ in }) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        if let fill {
            context.setFillColor(fill)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        draw(context)
        return context.makeImage()!
    }

    static func text(_ string: String, size: CGFloat, color: CGColor, in context: CGContext, at point: CGPoint) {
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
        let attributed = NSAttributedString(string: string, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        context.textPosition = point
        CTLineDraw(line, context)
    }

    @Test func theInkBoxIsWhereThePixelsAre() throws {
        let layer = Self.picture(width: 200, height: 100) { context in
            context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 20, y: 10, width: 50, height: 30))   // bottom-left origin
        }
        let box = try #require(InkBox.bounds(of: layer))
        #expect(box == CGRect(x: 20, y: 60, width: 50, height: 30))   // top-left origin
        let normal = try #require(InkBox.normalizedBounds(of: layer))
        #expect(abs(normal.minX - 0.1) < 1e-9 && abs(normal.minY - 0.6) < 1e-9)
        #expect(InkBox.bounds(of: Self.picture(width: 10, height: 10)) == nil, "nothing drawn, no box")
    }

    @Test func aFaintShadowTailIsNotInk() {
        let layer = Self.picture(width: 50, height: 50) { context in
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.05))
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
        }
        #expect(InkBox.bounds(of: layer) == nil)
    }

    @Test func overflowIsMeasuredPerSide() {
        let overflow = InkBox.overflow(CGRect(x: -5, y: 10, width: 100, height: 95), inside: CGRect(x: 0, y: 0, width: 90, height: 100))
        #expect(overflow == Overflow(top: 0, bottom: 5, left: 5, right: 5))
        #expect(overflow.worst == 5)
        #expect(InkBox.overflow(CGRect(x: 10, y: 10, width: 10, height: 10), inside: CGRect(x: 0, y: 0, width: 90, height: 100)).worst == 0)
    }

    @Test func wcagRatiosAreWCAGs() {
        #expect(abs(Contrast.ratio(1, 0) - 21) < 1e-9)
        #expect(Contrast.ratio(0.5, 0.5) == 1)
        #expect(abs(Contrast.luminance(red: 1, green: 1, blue: 1) - 1) < 1e-9)
        // #777777 on white is the textbook 4.48.
        let grey = Contrast.luminance(red: 0x77 / 255.0, green: 0x77 / 255.0, blue: 0x77 / 255.0)
        #expect(abs(Contrast.ratio(grey, 1) - 4.48) < 0.01)
    }

    @Test func aPlateIsAsLightAsItCanBe() throws {
        #expect(Contrast.plateAlpha(text: 1, background: 0) == 0, "white on black needs nothing")
        let alpha = try #require(Contrast.plateAlpha(text: 1, background: 0.8))
        #expect(alpha > 0 && alpha <= Contrast.maximumPlateAlpha)
        #expect(Contrast.ratio(1, Contrast.composited(background: 0.8, plate: 0, alpha: alpha)) >= Contrast.normalTextMinimum)
        #expect(Contrast.ratio(1, Contrast.composited(background: 0.8, plate: 0, alpha: alpha - 0.05)) < Contrast.normalTextMinimum)
        #expect(Contrast.plateLuminance(forText: 0) == 1, "dark text gets a white plate")
    }

    @Test func lettersAgainstTheirRing() throws {
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let letters = Self.picture(width: 400, height: 120) { Self.text("LEGIBLE", size: 80, color: white, in: $0, at: CGPoint(x: 20, y: 25)) }
        let mask = Pixels.mask(of: letters)
        let onBlack = Self.picture(width: 400, height: 120, fill: CGColor(red: 0, green: 0, blue: 0, alpha: 1)) {
            $0.draw(letters, in: CGRect(x: 0, y: 0, width: 400, height: 120))
        }
        let onCream = Self.picture(width: 400, height: 120, fill: CGColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)) {
            $0.draw(letters, in: CGRect(x: 0, y: 0, width: 400, height: 120))
        }
        let strong = try #require(LetterRing.measure(composite: onBlack, letters: mask, referenceScale: 1))
        let weak = try #require(LetterRing.measure(composite: onCream, letters: mask, referenceScale: 1))
        #expect(strong.ratio > 20)
        #expect(weak.ratio < 1.3)
        #expect(LetterRing.measure(composite: onBlack, letters: [Bool](repeating: false, count: 400 * 120), referenceScale: 1) == nil)
    }

    @Test func recognitionReadsLargeWordsBack() {
        let image = Self.picture(width: 900, height: 200, fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1)) {
            Self.text("NIGHT DRIVE", size: 110, color: CGColor(red: 0, green: 0, blue: 0, alpha: 1), in: $0, at: CGPoint(x: 30, y: 55))
        }
        #expect(ReadBack.readFraction(of: "Night Drive", in: image) == 1)
        #expect(ReadBack.readFraction(of: "Morning Walk", in: image) == 0)
        #expect(ReadBack.readFraction(of: "", in: image) == 1, "nothing expected, nothing missing")
        #expect(ReadBack.measure("Night Drive", in: image) == 1)
        let blank = Self.picture(width: 300, height: 100, fill: CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        #expect(ReadBack.measure("Night Drive", in: blank) == 0, "nothing to read is a measured zero, not a failure")
        #expect(ReadBack.words(in: "Night-Drive (Remix)!") == ["night", "drive", "remix"])
        // The fallback a busy Neural Engine forces: the same words, read on the CPU.
        let onCPU = ReadBack.recognisedLines(in: image, onCPU: true)?.flatMap(ReadBack.words(in:))
        #expect(onCPU == ["night", "drive"])
    }

    @Test func morphologyGrowsAndShrinks() {
        var mask = [Bool](repeating: false, count: 25)
        mask[12] = true
        #expect(Morphology.dilated(mask, width: 5, height: 5, by: 1).filter { $0 }.count == 9)
        #expect(Morphology.eroded(mask, width: 5, height: 5, by: 1).filter { $0 }.count == 0)
    }
}
