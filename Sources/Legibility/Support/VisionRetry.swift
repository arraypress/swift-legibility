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
//  0.3.2: a request can also never come back. With the Neural Engine's
//  compiler service wedged, every text-recognition request blocked inside
//  `performRequests` at 0 % CPU and a test run hung for 2 h 25 min. So a
//  request that may use the Neural Engine runs on its own thread under a
//  wall-clock limit (``neuralEngineTimeout``); past it the attempt counts as
//  failed, and every later request in the process goes to the CPU (the
//  stuck thread cannot be stopped, only abandoned). `LEGIBILITY_VISION_CPU=1`
//  sends every request to the CPU from the start.
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

    /// How long a request that may use the Neural Engine is waited for
    /// before it is abandoned and the CPU used instead, seconds.
    public static let neuralEngineTimeout = 20.0

    /// Whether every request goes to the CPU: `LEGIBILITY_VISION_CPU=1`, or a
    /// request in this process timed out on the Neural Engine.
    public static var cpuOnly: Bool {
        stalled.withLock { $0 } || ProcessInfo.processInfo.environment["LEGIBILITY_VISION_CPU"] == "1"
    }

    private static let stalled = OSAllocatedUnfairLock(initialState: false)

    /// `request` performed once on `handler`; `false` when Vision refused or
    /// the Neural Engine did not answer within ``neuralEngineTimeout``.
    /// `onCPU` keeps every stage off the Neural Engine and the GPU.
    public static func perform(_ request: VNRequest, on handler: VNImageRequestHandler, onCPU: Bool) -> Bool {
        if onCPU || cpuOnly {
            runOnCPU(request)
            do { try handler.perform([request]) } catch { return false }
            return true
        }
        return perform(request, on: handler, within: neuralEngineTimeout)
    }

    /// `request` on `handler` on a thread of its own, waited for at most
    /// `seconds`; past that it is cancelled, abandoned, and the process
    /// turns to the CPU.
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
            done.signal()
        }
        guard done.wait(timeout: .now() + seconds) == .success else {
            stalled.withLock { $0 = true }
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
