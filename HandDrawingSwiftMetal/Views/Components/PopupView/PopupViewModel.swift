//
//  PopupViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import Combine
import SwiftUI

enum PopupPlacement {
    /// Places the popup directly below the anchor.
    case top
    /// Places the popup directly above the anchor.
    case bottom
}

@MainActor
final class PopupViewModel: ObservableObject {

    @Published var isHidden: Bool

    @Published var isUserInteractionEnabled: Bool = true

    /// Bounds of the anchor target
    @Published var targetFrame: CGRect = .zero

    @Published private(set) var stackingOrder: Int = 0

    /// Configured popup width.
    let width: CGFloat

    /// Configured popup height.
    @Published var height: CGFloat

    /// Vertical gap between `targetFrame` and the popup edge
    let targetSpacing: CGFloat

    private let horizontalPadding: CGFloat

    init(
        width: CGFloat,
        height: CGFloat = 0,
        targetSpacing: CGFloat = 8,
        horizontalPadding: CGFloat = 16,
        isHidden: Bool = true
    ) {
        self.width = width
        self.height = height
        self.targetSpacing = targetSpacing
        self.horizontalPadding = horizontalPadding
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

    func bringToFront() {
        Self.nextStackingOrder += 1
        stackingOrder = Self.nextStackingOrder
    }

    func setHeight(_ height: CGFloat) {
        self.height = height
    }

    func popupRect(
        containerWidth: CGFloat,
        containerHeight: CGFloat? = nil,
        placement: PopupPlacement
    ) -> CGRect {
        var rect = alignPopupRectHorizontally(containerWidth: containerWidth)
        switch placement {
        case .top:
            rect.origin.y = targetFrame.maxY + targetSpacing
        case .bottom:
            rect.origin.y = targetFrame.minY - rect.height - targetSpacing
        }

        guard let containerHeight else { return rect }

        if placement == .bottom {
            let anchorClearanceY = targetFrame.minY - targetSpacing - rect.height
            rect.origin.y = min(rect.origin.y, anchorClearanceY)
        }

        rect.origin.y = max(rect.origin.y, 0)
        rect.origin.y = min(rect.origin.y, max(0, containerHeight - rect.height))
        return rect
    }
}

private extension PopupViewModel {
    static var nextStackingOrder = 0

    /// Horizontally aligns the popup with `targetFrame`, clamped to container margins
    func alignPopupRectHorizontally(
        containerWidth: CGFloat
    ) -> CGRect {
        let halfWidth = width / 2

        let centeredCenterX = targetFrame.midX
        let minCenterX = halfWidth + horizontalPadding
        let maxCenterX = containerWidth - (halfWidth + horizontalPadding)
        let centerX: CGFloat
        if minCenterX <= maxCenterX {
            centerX = min(max(centeredCenterX, minCenterX), maxCenterX)
        } else {
            // Container too narrow to satisfy horizontal padding on both sides.
            // Keep the popup inside the container by centering, then clamping x.
            centerX = containerWidth / 2
        }

        let idealX = centerX - halfWidth
        let clampedX = min(max(idealX, 0), max(containerWidth - width, 0))

        return CGRect(
            x: clampedX,
            y: 0,
            width: width,
            height: height
        )
    }
}
