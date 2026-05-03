//
//  PopupViewPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/03/14.
//

import SwiftUI

@MainActor final class PopupViewPresenter: ObservableObject {
    @Published var arrowX: CGFloat = 0
    @Published var isHidden: Bool = true
    @Published var isUserInteractionEnabled: Bool = true

    func toggleView() {
        isHidden.toggle()
    }

    func hide() {
        isHidden = true
    }

    func enableComponentInteraction(_ isEnabled: Bool) {
        isUserInteractionEnabled = isEnabled
    }

    /// Sets the arrow tip horizontal position in `popupRootView` coordinates so it stays under `target`
    func updateArrowTip(fromTarget target: UIView, popupRootView: UIView) {
        self.arrowX = target.convert(
            .init(
                x: target.bounds.midX,
                y: target.bounds.midY
            ),
            to: popupRootView
        ).x
    }
}

struct PopupPresenterView<Content: View>: View {
    @ObservedObject var presenter: PopupViewPresenter
    private let content: () -> Content

    init(
        presenter: PopupViewPresenter,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.presenter = presenter
        self.content = content
    }

    var body: some View {
        PopupWithArrowView(arrowPointX: $presenter.arrowX) {
            content()
        }
        .allowsHitTesting(presenter.isUserInteractionEnabled)
    }
}
