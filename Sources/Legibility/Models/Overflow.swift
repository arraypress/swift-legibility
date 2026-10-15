//
//  Overflow.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//

import CoreGraphics
import Foundation

/// How far ink reaches past a rectangle on each side, in the units both were
/// measured in (pixels or fractions). Zero on a side the ink stays inside.
public struct Overflow: Codable, Equatable, Sendable {
    public var top: CGFloat
    public var bottom: CGFloat
    public var left: CGFloat
    public var right: CGFloat

    public init(top: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
    }

    /// The furthest any side reaches out.
    public var worst: CGFloat { max(top, bottom, left, right) }
}
