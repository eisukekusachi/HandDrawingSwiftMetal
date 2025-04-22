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

    private var canvasModel = CanvasModel()

    private let canvasViewModel = CanvasViewModel()

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupContentView()

        setupNewCanvasDialogPresenter()
        setupLayerViewPresenter()

        bindViewModel()

        canvasViewModel.onViewDidLoad(
            canvasView: contentView.canvasView
        )

        contentView.alpha = 0.0
        view.backgroundColor = UIColor(rgb: Constants.blankAreaBackgroundColor)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvasViewModel.onViewDidAppear(
            model: canvasModel,
            drawableTextureSize: contentView.canvasView.drawableSize
        )

        UIView.animate(withDuration: 0.05) { [weak self] in
            self?.contentView.alpha = 1.0
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size
    }

}

extension CanvasViewController {

    private func setupContentView() {
        addEvents()
        bindData()

        contentView.setup(
            canvasViewModel.canvasState
        )
    }

    private func bindData() {
        canvasViewModel.requestShowingActivityIndicatorPublisher
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        canvasViewModel.requestShowingAlertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(
                    title: "Alert",
                    message: message
                )
            }
            .store(in: &cancellables)

        canvasViewModel.requestShowingToastPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        canvasViewModel.requestShowingLayerViewPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShown in
                self?.textureLayerViewPresenter.showView(isShown)
            }
            .store(in: &cancellables)

        canvasViewModel.refreshCanvasPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.canvasViewModel.initCanvas(using: model)
            }
            .store(in: &cancellables)

        canvasViewModel.updateUndoButtonIsEnabledState
            .assign(to: \.isEnabled, on: contentView.undoButton)
            .store(in: &cancellables)

        canvasViewModel.updateRedoButtonIsEnabledState
            .assign(to: \.isEnabled, on: contentView.redoButton)
            .store(in: &cancellables)
    }
    private func bindViewModel() {
        contentView.tapResetTransformButton = { [weak self] in
            self?.canvasViewModel.didTapResetTransformButton()
        }

        contentView.tapLayerButton = { [weak self] in
            self?.canvasViewModel.didTapLayerButton()
        }
        contentView.tapSaveButton = { [weak self] in
            self?.canvasViewModel.didTapSaveButton()
        }
        contentView.tapLoadButton = { [weak self] in
            guard let `self` else { return }

            let zipFilePashArray: [String] = URL.documents.allFileURLs(suffix: URL.zipSuffix).map {
                $0.lastPathComponent
            }
            let fileView = FileView(
                zipFileList: zipFilePashArray,
                didTapItem: { selectedZipFilePath in
                    self.canvasViewModel.didTapLoadButton(filePath: selectedZipFilePath)
                    self.presentedViewController?.dismiss(animated: true)
            })
            let vc = UIHostingController(rootView: fileView)
            present(vc, animated: true)
        }
        contentView.tapExportImageButton = { [weak self] in
            guard let `self` else { return }
            contentView.exportImageButton.debounce()

            if let image = contentView.canvasView.renderTexture?.uiImage {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
            }
        }
        contentView.tapNewButton = { [weak self] in
            guard let `self` else { return }
            newCanvasDialogPresenter.presentAlert(on: self)
        }

        contentView.tapUndoButton = { [weak self] in
            self?.canvasViewModel.didTapUndoButton()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.canvasViewModel.didTapRedoButton()
        }
    }

    private func addEvents() {
        contentView.canvasView.addGestureRecognizer(
            FingerInputGestureRecognizer(delegate: self)
        )
        contentView.canvasView.addGestureRecognizer(
            PencilInputGestureRecognizer(delegate: self)
        )

        contentView.canvasView.updateTexturePublisher
            .sink { [weak self] in
                self?.canvasViewModel.onUpdateRenderTexture()
            }
            .store(in: &cancellables)
    }

}

extension CanvasViewController {

    func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            self?.canvasViewModel.didTapNewCanvasButton()
        }
    }

    func setupLayerViewPresenter() {
        textureLayerViewPresenter.setupLayerViewPresenter(
            canvasState: canvasViewModel.canvasState,
            textureLayers: canvasViewModel.textureLayers,
            targetView: contentView.layerButton,
            didStartChangingAlpha: { [weak self] layer in
                self?.canvasViewModel.didStartChangingLayerAlpha(layer: layer)
            },
            didChangeAlpha: { [weak self] layer, value in
                self?.canvasViewModel.didChangeLayerAlpha(
                    layer: layer,
                    value: value
                )
            },
            didFinishChangingAlpha: { [weak self] layer in
                self?.canvasViewModel.didFinishChangingLayerAlpha(layer: layer)
            },
            on: self.contentView
        )
    }

    func showAlert(title: String, message: String) {
        dialogPresenter.configuration = .init(
            title: title,
            message: message
        )
        dialogPresenter.presentAlert(on: self)
    }

    func showToast(_ model: ToastModel) {
        let toast = Toast()
        toast.setupView(model)
        view.addSubview(toast)
    }

}

extension CanvasViewController {

    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            showToast(.init(title: "Failed", systemName: "exclamationmark.circle"))
        } else {
            showToast(.init(title: "Success", systemName: "hand.thumbsup.fill"))
        }
    }

}

extension CanvasViewController: FingerInputGestureRecognizerSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view
        )
    }

}

extension CanvasViewController: PencilInputGestureRecognizerSender {

    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            estimatedTouches: touches,
            with: event,
            view: view
        )
    }

    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            actualTouches: touches,
            view: view
        )
    }

}

extension CanvasViewController {

    static func create(
        canvasModel: CanvasModel = .init()
    ) -> Self {
        let viewController = Self()
        viewController.canvasModel = canvasModel
        return viewController
    }

}
