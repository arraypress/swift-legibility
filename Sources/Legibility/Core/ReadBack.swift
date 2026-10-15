//
//  ReadBack.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Whether text in a picture can be read, measured rather than judged: the
//  share of the expected words that on-device text recognition reads back.
//  Words a recogniser cannot find are words a reader will struggle with too;
//  ones it reads in full are at least not lost in the picture.
//

import CoreGraphics
import Foundation
import Vision

public enum ReadBack {

    /// The share (`0…1`) of `expected`'s words that text recognition finds in
    /// `image` inside `rect` (normalized, top-left; the whole image when
    /// `nil`). Words compare as letters and digits only, case ignored.
    public static func readFraction(of expected: String, in image: CGImage, rect: CGRect? = nil) -> Double {
        let wanted = words(in: expected)
        guard !wanted.isEmpty else { return 1 }
        let read = Set(recognisedWords(in: image, rect: rect))
        return Double(wanted.filter(read.contains).count) / Double(wanted.count)
    }

    /// The words text recognition reads in `image` inside `rect`, normalized.
    public static func recognisedWords(in image: CGImage, rect: CGRect? = nil) -> [String] {
        var target = image
        if let rect {
            let pixels = CGRect(x: rect.minX * CGFloat(image.width), y: rect.minY * CGFloat(image.height),
                                width: rect.width * CGFloat(image.width), height: rect.height * CGFloat(image.height))
                .integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !pixels.isNull, pixels.width >= 4, pixels.height >= 4, let crop = image.cropping(to: pixels) else { return [] }
            target = crop
        }
        // Asked twice when the first answer is nothing at all: the first
        // request in a process can come back empty while Vision is still
        // loading its recogniser (measured: a fresh binary read 0% of four
        // plain, high-contrast lines, then 100% on the next run).
        for _ in 0..<2 {
            let lines = recognisedLines(in: target)
            if !lines.isEmpty { return lines.flatMap(words(in:)) }
        }
        return []
    }

    /// One recognition pass: the top candidate of every line found.
    static func recognisedLines(in image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    /// `text` as comparable words: letters and digits only, lowercased.
    public static func words(in text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
