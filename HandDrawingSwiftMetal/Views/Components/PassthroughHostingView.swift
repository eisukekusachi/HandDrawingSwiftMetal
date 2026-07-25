//
//  PassthroughHostingView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/31.
//

import Combine
import SwiftUI
import UIKit

struct PopupAnchorBinding: Identifiable {
    /// Identity for the intended one ViewModel–one popup pairing
    var id: ObjectIdentifier {
        ObjectIdentifier(viewModel)
    }

    let viewModel: PopupViewModel
    let placement: PopupPlacement
    let target: UIView
    let targetFrameAdjustment: UIEdgeInsets
    let content: AnyView
    let onClose: (() -> Void)?

    init<Content: View>(
        target: UIView,
        viewModel: PopupViewModel,
        placement: PopupPlacement,
        targetFrameAdjustment: UIEdgeInsets = .zero,
        @ViewBuilder content: () -> Content,
        onClose: (() -> Void)? = nil
    ) {
        self.target = target
        self.viewModel = viewModel
        self.placement = placement
        self.targetFrameAdjustment = targetFrameAdjustment
        self.content = AnyView(content())
        self.onClose = onClose
    }
}

/// Hosts SwiftUI popups and limits UIKit hit testing to their visible rectangles
final class PassthroughHostingView: UIView {

    var anchorBindings: [PopupAnchorBinding] = [] {
        didSet {
            observeViewModels()
            setNeedsLayout()
        }
    }

    weak var hostingView: UIView?

    private var popupHitTestRects: [CGRect] = []
    private var cancellables = Set<AnyCancellable>()

    private var popupViewModels: [PopupViewModel] {
        anchorBindings.map(\.viewModel)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncPopupLayout()
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard popupViewModels.allSatisfy({ $0.isHidden || $0.isUserInteractionEnabled }) else {
            return false
        }
        if shouldPassThroughToAnchor(at: point) {
            return false
        }
        return popupHitTestRects.contains { $0.contains(point) }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard popupViewModels.allSatisfy({ $0.isHidden || $0.isUserInteractionEnabled }) else {
            return nil
        }
        if shouldPassThroughToAnchor(at: point) {
            return nil
        }
        guard topmostVisiblePopup(at: point) != nil else {
            return nil
        }
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    private func observeViewModels() {
        cancellables.removeAll()
        for viewModel in popupViewModels {
            viewModel.$isHidden
                .removeDuplicates()
                .sink { [weak self] isHidden in
                    if !isHidden {
                        viewModel.bringToFront()
                    }
                    self?.setNeedsLayout()
                }
                .store(in: &cancellables)
        }
    }

    private func syncTargetFrames() {
        for binding in anchorBindings {
            binding.viewModel.targetFrame = anchorFrame(for: binding)
        }
    }

    private func anchorFrame(for binding: PopupAnchorBinding) -> CGRect {
        let frame = binding.target.convert(binding.target.bounds, to: self)
        return frame.inset(by: binding.targetFrameAdjustment)
    }

    private func shouldPassThroughToAnchor(at point: CGPoint) -> Bool {
        anchorBindings.contains { binding in
            !binding.viewModel.isHidden && anchorFrame(for: binding).contains(point)
        }
    }

    /// Recomputes anchor frames and popup geometry. Call after rotation when anchor views have finished layout
    func syncPopupLayout() {
        syncTargetFrames()
        syncHitTestRect()
        syncHostingVisibility()
        hostingView?.setNeedsLayout()
    }

    private func syncHitTestRect() {
        popupHitTestRects = anchorBindings
            .filter { !$0.viewModel.isHidden }
            .sorted { $0.viewModel.stackingOrder < $1.viewModel.stackingOrder }
            .map { binding in
                binding.viewModel.popupRect(
                    containerWidth: bounds.width,
                    containerHeight: bounds.height,
                    placement: binding.placement
                )
            }
    }

    private func topmostVisiblePopup(at point: CGPoint) -> PopupAnchorBinding? {
        anchorBindings
            .filter { !$0.viewModel.isHidden }
            .sorted { $0.viewModel.stackingOrder > $1.viewModel.stackingOrder }
            .first { binding in
                binding.viewModel.popupRect(
                    containerWidth: bounds.width,
                    containerHeight: bounds.height,
                    placement: binding.placement
                ).contains(point)
            }
    }

    private func syncHostingVisibility() {
        let hasVisiblePopup = popupViewModels.contains { !$0.isHidden }
        hostingView?.isHidden = !hasVisiblePopup
        hostingView?.isUserInteractionEnabled = hasVisiblePopup
    }
}
