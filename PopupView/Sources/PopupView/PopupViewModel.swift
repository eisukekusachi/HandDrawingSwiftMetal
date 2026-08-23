//
//  PopupView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import Combine
import SwiftUI

@MainActor
public final class PopupViewModel: ObservableObject {
    /// Portrait width of iPhone SE, in points.
    public static let iPhoneSEWidth = 320

    @Published public private(set) var isHidden: Bool

    @Published public private(set) var isUserInteractionEnabled: Bool = true

    /// Bounds of the anchor target in container coordinates.
    @Published public private(set) var targetFrame: CGRect = .zero

    @Published public private(set) var stackingOrder: Int = 0

    /// Measured popup height used for positioning.
    @Published public private(set) var height: CGFloat = 0

    /// `true` when the popup should not be visible. Stays `true` while hidden, and during the short delay after `show()`. Not tied to actual layout completion.
    @Published public private(set) var isConcealed: Bool = true

    /// Configured popup width in points.
    public let width: Int

    /// Vertical gap between `targetFrame` and the popup edge
    public let targetSpacing: CGFloat

    /// Horizontal gap between the container edges and the popup.
    public let horizontalPadding: CGFloat

    /// Short delay before revealing, giving layout a moment to finish. Not synced to layout.
    public let revealDelayNanoseconds: UInt64

    private var revealTask: Task<Void, Never>?

    public init(
        width: Int = iPhoneSEWidth,
        targetSpacing: CGFloat = 8,
        horizontalPadding: CGFloat = 16,
        isHidden: Bool = true,
        revealDelayNanoseconds: UInt64 = 10_000_000
    ) {
        self.width = width
        self.targetSpacing = targetSpacing
        self.horizontalPadding = horizontalPadding
        self.isHidden = isHidden
        self.revealDelayNanoseconds = revealDelayNanoseconds
    }
}

public extension PopupViewModel {

    func popupRect(
        containerWidth: CGFloat,
        containerHeight: CGFloat? = nil,
        placement: PopupPlacement
    ) -> CGRect {
        var rect = alignPopupRectHorizontally(containerWidth: containerWidth)

        switch placement {
        case .belowAnchor:
            rect.origin.y = targetFrame.maxY + targetSpacing

        case .aboveAnchor:
            rect.origin.y = targetFrame.minY - targetSpacing - rect.height
        }

        guard let containerHeight else { return rect }
        rect.origin.y = max(rect.origin.y, 0)
        rect.origin.y = min(rect.origin.y, max(0, containerHeight - rect.height))
        return rect
    }

    func show(immediately: Bool = false) {
        revealTask?.cancel()
        isHidden = false

        guard !immediately, revealDelayNanoseconds > 0 else {
            isConcealed = false
            return
        }

        isConcealed = true
        revealTask = Task { [weak self, delay = revealDelayNanoseconds] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            guard let `self` else { return }
            self.isConcealed = false
        }
    }

    func hide() {
        revealTask?.cancel()
        revealTask = nil
        isConcealed = true
        isHidden = true
    }

    func enableComponentInteraction(_ isEnabled: Bool) {
        isUserInteractionEnabled = isEnabled
    }

    /// Sets the anchor bounds used to position this popup.
    /// Placement fails while `targetFrame` remains `.zero`.
    func setTargetFrame(_ frame: CGRect) {
        guard targetFrame != frame else { return }
        targetFrame = frame
    }

    func bringToFront() {
        Self.nextStackingOrder += 1
        stackingOrder = Self.nextStackingOrder
    }

    func updateMeasuredHeight(_ height: CGFloat) {
        guard self.height != height else { return }
        self.height = height
    }
}

private extension PopupViewModel {
    static var nextStackingOrder = 0

    /// Adjusts the popup's horizontal origin so it stays on screen.
    func alignPopupRectHorizontally(containerWidth: CGFloat) -> CGRect {
        let popupWidth = CGFloat(width)
        let halfWidth = popupWidth / 2

        let centeredCenterX = targetFrame.midX
        let minCenterX = halfWidth + horizontalPadding
        let maxCenterX = containerWidth - (halfWidth + horizontalPadding)
        let centerX: CGFloat
        if minCenterX <= maxCenterX {
            centerX = min(max(centeredCenterX, minCenterX), maxCenterX)
        } else {
            centerX = containerWidth / 2
        }

        let idealX = centerX - halfWidth
        let clampedX = min(max(idealX, 0), max(containerWidth - popupWidth, 0))

        return CGRect(
            x: clampedX,
            y: 0,
            width: popupWidth,
            height: height
        )
    }
}
