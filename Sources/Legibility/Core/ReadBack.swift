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
    /// `nil`). Words compare as letters and digits only, case ignored. `0`
    /// when recognition could not run — ``measure(_:in:rect:)`` tells the two apart.
    public static func readFraction(of expected: String, in image: CGImage, rect: CGRect? = nil) -> Double {
        measure(expected, in: image, rect: rect) ?? 0
    }

    /// ``readFraction(of:in:rect:)``, or `nil` when recognition could not run
    /// at all — which is not the same as finding nothing to read.
    public static func measure(_ expected: String, in image: CGImage, rect: CGRect? = nil) -> Double? {
        let wanted = words(in: expected)
        guard !wanted.isEmpty else { return 1 }
        guard let found = recognition(in: image, rect: rect) else { return nil }
        let read = Set(found)
        return Double(wanted.filter(read.contains).count) / Double(wanted.count)
    }

    /// The words text recognition reads in `image` inside `rect`, normalized;
    /// empty when it could not run.
    public static func recognisedWords(in image: CGImage, rect: CGRect? = nil) -> [String] {
        recognition(in: image, rect: rect) ?? []
    }

    /// The words read, or `nil` when recognition failed every time it was asked.
    ///
    /// Two things go wrong that are not the picture's fault, both measured on
    /// this machine. While another process holds the Neural Engine (an image
    /// model generating), a request can fail outright with an Espresso
    /// runtime error — 4 of 10 runs did. And the first request in a fresh
    /// process can come back empty while the recogniser loads. So a failed
    /// request is asked again after a growing pause (up to four times, 2.6 s
    /// in all), and an empty answer once more.
    public static func recognition(in image: CGImage, rect: CGRect? = nil) -> [String]? {
        var target = image
        if let rect {
            let pixels = CGRect(x: rect.minX * CGFloat(image.width), y: rect.minY * CGFloat(image.height),
                                width: rect.width * CGFloat(image.width), height: rect.height * CGFloat(image.height))
                .integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard !pixels.isNull, pixels.width >= 4, pixels.height >= 4, let crop = image.cropping(to: pixels) else { return [] }
            target = crop
        }
        var emptyAnswers = 0
        for pause in [0.0, 0.3, 0.8, 1.5] {
            if pause > 0 { Thread.sleep(forTimeInterval: pause) }
            guard let lines = recognisedLines(in: target) else { continue }
            if !lines.isEmpty { return lines.flatMap(words(in:)) }
            emptyAnswers += 1
            if emptyAnswers == 2 { return [] }
        }
        return emptyAnswers > 0 ? [] : nil
    }

    /// One recognition pass: the top candidate of every line found, or `nil`
    /// when the request failed.
    static func recognisedLines(in image: CGImage) -> [String]? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { return nil }
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
