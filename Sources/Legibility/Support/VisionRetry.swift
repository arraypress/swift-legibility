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

import CoreGraphics
import CoreML
import Foundation
import Vision

public enum VisionRetry {

    /// The attempts, in order: a pause before each, and whether it runs on
    /// the CPU only.
    public static let attempts: [(pause: Double, onCPU: Bool)] = [(0, false), (0.3, false), (0, true), (0.5, true)]

    /// `request` performed once on `handler`; `false` when Vision refused.
    /// `onCPU` keeps every stage off the Neural Engine and the GPU.
    public static func perform(_ request: VNRequest, on handler: VNImageRequestHandler, onCPU: Bool) -> Bool {
        if onCPU { runOnCPU(request) }
        do { try handler.perform([request]) } catch { return false }
        return true
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
