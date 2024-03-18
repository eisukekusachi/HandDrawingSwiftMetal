//
//  DialogPresenter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/18.
//

import UIKit

class DialogPresenter {

    struct Configuration {
        var title: String
        var message: String
        var buttonTitles: [String]
        var buttonActions: [Int: (() -> Void)]
    }

    var configuration: Configuration?

    func presentAlert(on viewController: UIViewController) {
        guard let configuration else { return }

        let alert = UIAlertController(
            title: configuration.title,
            message: configuration.message,
            preferredStyle: .alert)

        var allButtons: [String] = configuration.buttonTitles

        if allButtons.count == 0 {
            allButtons.append("OK")
        }

        for index in 0 ..< allButtons.count {
            let action = UIAlertAction(
                title: allButtons[index],
                style: .default,
                handler: { _ in
                    configuration.buttonActions[index]?()
                }
            )
            alert.addAction(action)
        }

        viewController.present(alert, animated: true)
    }

}
