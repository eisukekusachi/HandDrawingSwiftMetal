//
//  PopupViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import Combine
import SwiftUI

enum PopupPlacement {
    /// Popup opens downward
    case top
    /// Popup opens upward
    case bottom
}

@MainActor
final class PopupViewModel: ObservableObject {

    @Published var isHidden: Bool

    @Published var isUserInteractionEnabled: Bool = true

    /// Bounds of the anchor target
    @Published var targetFrame: CGRect = .zero

    /// Vertical gap between `targetFrame` and the popup edge
    private let targetSpacing: CGFloat

    private let horizontalPadding: CGFloat

    private let placement: PopupPlacement

    private let popupSize: CGSize

    init(
        size: CGSize,
        targetSpacing: CGFloat = 8,
        horizontalPadding: CGFloat = 16,
        placement: PopupPlacement,
        isHidden: Bool = true
    ) {
        self.popupSize = size
        self.targetSpacing = targetSpacing
        self.horizontalPadding = horizontalPadding
        self.placement = placement
        self.isHidden = isHidden
    }

    func toggleView() {
        isHidden.toggle()
    }

    func hide() {
        isHidden = true
    }

    func enableComponentInteraction(_ isEnabled: Bool) {
        isUserInteractionEnabled = isEnabled
    }

    func popupRect(
        containerWidth: CGFloat
    ) -> CGRect {
        var rect = alignPopupRectHorizontally(containerWidth: containerWidth)
        switch placement {
        case .top:
            rect.origin.y = targetFrame.maxY + targetSpacing
        case .bottom:
            rect.origin.y = targetFrame.minY - rect.height - targetSpacing
        }
        return rect
    }
}

private extension PopupViewModel {
    /// Horizontally aligns the popup with `targetFrame`, clamped to container margins
    private func alignPopupRectHorizontally(
        containerWidth: CGFloat
    ) -> CGRect {
        let halfPopupSize = popupSize.width / 2

        let centeredCenterX = targetFrame.midX
        let minCenterX = halfPopupSize + horizontalPadding
        let maxCenterX = containerWidth - (halfPopupSize + horizontalPadding)
        let centerX: CGFloat
        if minCenterX <= maxCenterX {
            centerX = min(max(centeredCenterX, minCenterX), maxCenterX)
        } else {
            // Container too narrow to satisfy horizontal padding on both sides.
            // Keep the popup inside the container by centering, then clamping x.
            centerX = containerWidth / 2
        }

        let idealX = centerX - halfPopupSize
        let clampedX = min(max(idealX, 0), max(containerWidth - popupSize.width, 0))

        return CGRect(
            x: clampedX,
            y: 0,
            width: popupSize.width,
            height: popupSize.height
        )
    }
}
