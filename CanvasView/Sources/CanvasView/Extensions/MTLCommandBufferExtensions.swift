//
//  MTLCommandBufferExtensions.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/10/10.
//

@preconcurrency import MetalKit

extension MTLCommandBuffer {
    func commitAndWaitAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.addCompletedHandler { @Sendable result in
                if let error = result.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
            self.commit()
        }
    }
}
