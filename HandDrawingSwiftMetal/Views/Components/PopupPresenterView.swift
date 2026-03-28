//
//  PopupPresenterView.swift
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

    func arrowX(_ target: UIView, to destination: UIView, dialogWidth: CGFloat) {
        let targetViewCenterX = target.convert(
            target.bounds, to: destination
        ).midX
        let layerViewX = targetViewCenterX - dialogWidth * 0.5
        let centerX = targetViewCenterX - layerViewX + target.bounds.width * 0.5

        self.arrowX = centerX
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
