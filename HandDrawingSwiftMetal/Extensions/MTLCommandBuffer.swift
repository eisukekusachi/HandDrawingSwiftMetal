//
//  Created by Eisuke Kusachi
//

@preconcurrency import MetalKit

@MainActor
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
