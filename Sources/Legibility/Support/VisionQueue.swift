//
//  VisionQueue.swift
//  Legibility
//
//  Created by David Sherlock on 2026.
//
//  Blocking work — Vision above all — run on a dispatch queue rather than a
//  Swift concurrency thread. Vision's requests wait synchronously on queues
//  of their own; several of them waiting at once on the cooperative pool
//  (one thread a core) was measured to deadlock every thread in it. Off the
//  pool, they only wait.
//

import Foundation

public enum VisionQueue {

    /// `work`'s result, computed on a global dispatch queue.
    public static func run<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { continuation.resume(returning: work()) }
        }
    }
}
