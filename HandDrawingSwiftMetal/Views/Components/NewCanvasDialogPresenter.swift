//
//  NewCanvasDialogPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/18.
//

import Foundation

final class NewCanvasDialogPresenter: DialogPresenter {

    var onTapButton: (() -> Void)?

    override init() {
        super.init()

        configuration = Configuration(
            title: "New Canvas",
            message: "Do you want to create a new canvas?",
            buttonTitles: ["Cancel", "OK"],
            buttonActions: [1: { [weak self] in self?.onTapButton?() }]
        )
    }

}
