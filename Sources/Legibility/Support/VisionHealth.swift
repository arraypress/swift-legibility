//
//  VisionHealth.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Whether Vision is answering in this process, and how long the next
//  request may take: the first one loads Vision's models; a request that
//  was abandoned stops Vision until any request answers. Pure.
//

import Foundation

struct VisionHealth: Sendable {

    /// Whether any request has come back in this process.
    private(set) var warm = false

    /// Whether a request was abandoned and none has answered since.
    private(set) var stalled = false

    /// A request came back, in time or late: Vision is answering.
    mutating func answered() {
        warm = true
        stalled = false
    }

    /// A request did not come back in time.
    mutating func abandoned() { stalled = true }

    /// How long the next request may take: `warmUp` until one has answered.
    func limit(timeout: Double, warmUp: Double) -> Double { warm ? timeout : warmUp }
}
