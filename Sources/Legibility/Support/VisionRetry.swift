//
//  VisionRetry.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Running a Vision request so that a failure that is not the picture's
//  fault is not reported as an answer. While another process holds the
//  Neural Engine (an image model generating), a request can fail outright
//  with an Espresso runtime error — 4 of 10 text-recognition runs did on
//  this machine, and waiting a few seconds did not clear it. So a failed
//  request is asked again, then on the CPU, which the Neural Engine's other
//  tenant does not hold.
//
//  A request can also never come back. With the Neural Engine's compiler
//  service wedged, every text-recognition request blocked inside
//  `performRequests` at 0 % CPU and a test run hung for 2 h 25 min — on the
//  CPU too: Vision itself waits on the stuck service, system-wide. So every
//  request runs on its own thread under a wall-clock limit (``timeout``);
//  past it the request is abandoned (its thread cannot be stopped), and the
//  process sends Vision nothing more (``isStalled``): every later request
//  fails at once, which callers report as not measured, never as an answer.
//  A slow answer is not a stuck one: the first request in a process loads
//  Vision's models and took longer than 20 s on a cold start, so it gets
//  ``warmUpTimeout``; and an abandoned request that does come back lifts the
//  stall. Only a request that never answers keeps Vision stopped.
//  `LEGIBILITY_VISION_CPU=1` keeps every request on the CPU from the start.
//

import CoreGraphics
import CoreML
import Foundation
import os
import Vision

public enum VisionRetry {

    /// The attempts, in order: a pause before each, and whether it runs on
    /// the CPU only.
    public static let attempts: [(pause: Double, onCPU: Bool)] = [(0, false), (0.3, false), (0, true), (0.5, true)]

    /// How long one request is waited for before it is abandoned, seconds.
    public static let timeout = 20.0

    /// How long the first request in a process is waited for, seconds: it
    /// loads Vision's models, which took longer than ``timeout`` on a cold start.
    public static let warmUpTimeout = 120.0

    /// Whether every request runs on the CPU: `LEGIBILITY_VISION_CPU=1`.
    public static var cpuOnly: Bool {
        ProcessInfo.processInfo.environment["LEGIBILITY_VISION_CPU"] == "1"
    }

    /// Whether a request in this process has not come back: Vision may be
    /// stuck (a wedged Neural Engine service holds it system-wide), and
    /// nothing more is sent to it until that request answers.
    public static var isStalled: Bool { health.withLock { $0.stalled } }

    private static let health = OSAllocatedUnfairLock(initialState: VisionHealth())

    /// For tests: a request abandoned, with none left running.
    static func markStalled() { health.withLock { $0.abandoned() } }

    /// For tests: forget a stall.
    static func resetStall() { health.withLock { $0.answered() } }

    /// `request` performed once on `handler`; `false` when Vision refused,
    /// did not answer within ``timeout``, or has stalled in this process.
    /// `onCPU` keeps every stage off the Neural Engine and the GPU.
    public static func perform(_ request: VNRequest, on handler: VNImageRequestHandler, onCPU: Bool) -> Bool {
        guard !isStalled else { return false }
        if onCPU || cpuOnly { runOnCPU(request) }
        return perform(request, on: handler, within: health.withLock { $0.limit(timeout: timeout, warmUp: warmUpTimeout) })
    }

    /// `request` on `handler` on a thread of its own, waited for at most
    /// `seconds`; past that it is cancelled and abandoned, and Vision is
    /// sent nothing more until it answers.
    static func perform(_ request: VNRequest, on handler: VNImageRequestHandler, within seconds: Double) -> Bool {
        let done = DispatchSemaphore(value: 0)
        let outcome = OSAllocatedUnfairLock<Bool?>(initialState: nil)
        // The request and handler are only touched by the worker until it
        // signals, or never again here once abandoned.
        nonisolated(unsafe) let request = request, handler = handler
        DispatchQueue.global(qos: .userInitiated).async {
            let ok: Bool
            do { try handler.perform([request]); ok = true } catch { ok = false }
            outcome.withLock { $0 = ok }
            health.withLock { $0.answered() }
            done.signal()
        }
        guard done.wait(timeout: .now() + seconds) == .success else {
            health.withLock { $0.abandoned() }
            request.cancel()
            return false
        }
        return outcome.withLock { $0 } ?? false
    }

    /// A request from `make` performed on `image` through ``attempts`` until
    /// one succeeds — with the handler it ran on, which some results need to
    /// be read — or `nil` when every attempt failed.
    public static func perform<Request: VNRequest>(on image: CGImage, _ make: () -> Request)
        -> (request: Request, handler: VNImageRequestHandler)? {
        for attempt in attempts {
            guard !isStalled else { return nil }
            if attempt.pause > 0 { Thread.sleep(forTimeInterval: attempt.pause) }
            let request = make()
            let handler = VNImageRequestHandler(cgImage: image)
            if perform(request, on: handler, onCPU: attempt.onCPU) { return (request, handler) }
        }
        return nil
    }

    /// Every stage of `request` set to its CPU device, where it has one.
    public static func runOnCPU(_ request: VNRequest) {
        guard let stages = try? request.supportedComputeStageDevices else { return }
        for (stage, devices) in stages {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
    }
}
