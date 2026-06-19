//
//  StrokeLifecycleManager.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/06/15.
//

import Combine

/// Owns stroke lifecycle transitions and publishes phase changes.
@MainActor
final class StrokeLifecycleManager {

    var phase: StrokeLifecycle { phaseSubject.value }

    var isActive: Bool { phase.isActive }

    var displayLinkShouldRunPublisher: AnyPublisher<Bool, Never> {
        phasePublisher
            .map(\.isDrawing)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var phasePublisher: AnyPublisher<StrokeLifecycle, Never> {
        phaseSubject.eraseToAnyPublisher()
    }
    private let phaseSubject = CurrentValueSubject<StrokeLifecycle, Never>(.idle)

    func beginIfIdle() {
        guard case .idle = phase else { return }

        phaseSubject.send(.drawing)
    }

    func finalizeIfDrawing(cancelled: Bool = false) {
        guard case .drawing = phase else { return }

        phaseSubject.send(.finalizing(cancelled: cancelled))
    }

    func complete() {
        guard case .finalizing = phase else { return }

        phaseSubject.send(.idle)
    }

    func reset() {
        phaseSubject.send(.idle)
    }
}
