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

    /// `true` while the realtime stroke display link should run.
    var shouldRunDisplayLink: Bool {
        phase == .drawing
    }

    var displayLinkShouldRunPublisher: AnyPublisher<Bool, Never> {
        phasePublisher
            .map { [weak self] _ in
                self?.shouldRunDisplayLink ?? false
            }
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
