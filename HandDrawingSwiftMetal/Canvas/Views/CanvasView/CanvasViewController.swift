//
//  CanvasViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import SwiftUI
import Combine

class CanvasViewController: UIViewController {

    @IBOutlet private weak var contentView: CanvasContentView!

    @IBOutlet private weak var activityIndicatorView: UIView!

    private var configuration = CanvasConfiguration()

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        addEvents()
        bindData()

        contentView.canvasView.initialize(
            configuration: configuration
        )

        setupNewCanvasDialogPresenter()
        setupLayerView()

        view.backgroundColor = UIColor(rgb: Constants.blankAreaBackgroundColor)
    }
}

extension CanvasViewController {

    private func bindData() {

        contentView.canvasView.activityIndicator
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        contentView.canvasView.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(
                    title: "Alert",
                    message: error.localizedDescription
                )
            }
            .store(in: &cancellables)

        contentView.canvasView.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        contentView.canvasView.undoRedoButtonState
            .sink { [weak self] state in
                self?.contentView.setUndoRedoButtonState(state)
            }
            .store(in: &cancellables)
    }

    private func addEvents() {
        contentView.tapLayerButton = { [weak self] in
            self?.textureLayerViewPresenter.toggleView()
        }
        contentView.tapSaveButton = { [weak self] in
            self?.contentView.canvasView.saveFile()
        }
        contentView.tapLoadButton = { [weak self] in
            self?.showFileView()
        }

        contentView.tapExportImageButton = { [weak self] in
            self?.contentView.exportImageButton.debounce()
            self?.saveImage()
        }
        contentView.tapNewButton = { [weak self] in
            guard let `self` else { return }
            self.newCanvasDialogPresenter.presentAlert(on: self)
        }
    }
}

extension CanvasViewController {

    private func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let `self` else { return }
            self.contentView.canvasView.newCanvas(
                configuration: CanvasConfiguration(
                    textureSize: self.contentView.canvasView.currentTextureSize
                )
            )
        }
    }

    private func setupLayerView() {
        textureLayerViewPresenter.setupLayerViewPresenter(
            configuration: contentView.canvasView.textureLayerConfiguration,
            using: .init(
                anchorButton: contentView.layerButton,
                destinationView: contentView,
                size: .init(
                    width: 300,
                    height: 300
                )
            )
        )
    }

    private func showFileView() {
        let fileView = FileView(
            targetURL: URL.documents,
            suffix: CanvasViewModel.fileSuffix,
            onTapItem: { [weak self] url in
                self?.presentedViewController?.dismiss(animated: true)
                self?.contentView.canvasView.loadFile(zipFileURL: url)
            }
        )
        present(
            UIHostingController(rootView: fileView),
            animated: true
        )
    }

    private func showAlert(title: String, message: String) {
        dialogPresenter.configuration = .init(
            title: title,
            message: message
        )
        dialogPresenter.presentAlert(on: self)
    }

    private func showToast(_ model: ToastModel) {
        let toast = Toast()
        toast.setupView(model)
        view.addSubview(toast)
    }

}

extension CanvasViewController {

    private func saveImage() {
        if let image = contentView.canvasView.renderView.renderTexture?.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        }
    }
    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            showToast(.init(title: "Failed", systemName: "exclamationmark.circle"))
        } else {
            showToast(.init(title: "Success", systemName: "hand.thumbsup.fill"))
        }
    }

}

extension CanvasViewController {

    static func create(
        configuration: CanvasConfiguration = .init()
    ) -> Self {
        let viewController = Self()
        viewController.configuration = configuration
        return viewController
    }

}
