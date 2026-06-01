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
    let target: UIView
    let content: AnyView

    init<Content: View>(
        target: UIView,
        viewModel: PopupViewModel,
        @ViewBuilder content: () -> Content
    ) {
        self.target = target
        self.viewModel = viewModel
        self.content = AnyView(content())
    }
}

/// Hosts SwiftUI popups and limits UIKit hit testing to their visible rectangles.
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
        popupHitTestRects.contains { $0.contains(point) }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard popupHitTestRects.contains(where: { $0.contains(point) }) else {
            return nil
        }
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    private func observeViewModels() {
        cancellables.removeAll()
        for viewModel in popupViewModels {
            viewModel.$isHidden
                .sink { [weak self] _ in
                    self?.setNeedsLayout()
                }
                .store(in: &cancellables)
        }
    }

    private func syncTargetFrames() {
        for binding in anchorBindings {
            let newFrame = binding.target.convert(binding.target.bounds, to: self)
            binding.viewModel.targetFrame = newFrame
        }
    }

    /// Recomputes anchor frames and popup geometry. Call after rotation when anchor views have finished layout.
    func syncPopupLayout() {
        syncTargetFrames()
        syncHitTestRect()
        syncHostingVisibility()
        hostingView?.setNeedsLayout()
    }

    private func syncHitTestRect() {
        popupHitTestRects = popupViewModels
            .filter { !$0.isHidden }
            .map { viewModel in
                viewModel.popupRect(
                    containerWidth: bounds.width
                )
            }
    }

    private func syncHostingVisibility() {
        let hasVisiblePopup = popupViewModels.contains { !$0.isHidden }
        hostingView?.isHidden = !hasVisiblePopup
        hostingView?.isUserInteractionEnabled = hasVisiblePopup
    }
}
