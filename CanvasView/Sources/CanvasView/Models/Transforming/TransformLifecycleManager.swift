//
//  TransformLifecycleManager.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/07.
//

import Combine

/// Owns transform lifecycle transitions and publishes phase changes.
@MainActor
final class TransformLifecycleManager {

    var phase: TransformLifecycle { phaseSubject.value }
    var isActive: Bool { phase.isActive }

    var phasePublisher: AnyPublisher<TransformLifecycle, Never> {
        phaseSubject.eraseToAnyPublisher()
    }

    private let phaseSubject = CurrentValueSubject<TransformLifecycle, Never>(.idle)

    func beginIfIdle() {
        guard case .idle = phase else { return }

        phaseSubject.send(.transforming)
    }

    func finalizeIfTransforming() {
        guard case .transforming = phase else { return }

        phaseSubject.send(.finalizing)
    }

    func complete() {
        guard case .finalizing = phase else { return }

        phaseSubject.send(.idle)
    }

    func reset() {
        phaseSubject.send(.idle)
    }
}
