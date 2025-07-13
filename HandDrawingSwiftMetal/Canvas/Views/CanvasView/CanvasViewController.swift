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

    private let canvasViewModel = CanvasViewModel(
        textureLayerRepository: TextureLayerDocumentsDirectorySingletonRepository.shared,
        undoTextureRepository: TextureUndoDocumentsDirectorySingletonRepository.shared
    )

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        addEvents()
        bindData()

        setupNewCanvasDialogPresenter()

        canvasViewModel.onViewDidLoad(
            canvasView: contentView.canvasView
        )

        contentView.alpha = 0.0
        view.backgroundColor = UIColor(rgb: Constants.blankAreaBackgroundColor)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        canvasViewModel.onViewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvasViewModel.onViewDidAppear(
            configuration: configuration,
            drawableTextureSize: contentView.canvasView.drawableSize
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size
    }

}

extension CanvasViewController {

    private func bindData() {
        canvasViewModel.viewConfigureRequestPublisher
            .sink { [weak self] configuration in
                self?.setupLayerView(
                    canvasState: configuration.canvasState,
                    textureLayerRepository: configuration.textureLayerRepository,
                    undoStack: configuration.undoStack
                )
                self?.contentView.setup()
            }
            .store(in: &cancellables)

        canvasViewModel.canvasViewSetupCompleted
            .sink { [weak self] configuration in
                UIView.animate(withDuration: 0.05) { [weak self] in
                    self?.contentView.alpha = 1.0
                }
            }
            .store(in: &cancellables)

        canvasViewModel.activityIndicator
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        canvasViewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(
                    title: "Alert",
                    message: error.localizedDescription
                )
            }
            .store(in: &cancellables)

        canvasViewModel.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        canvasViewModel.needsUndoButtonStateUpdatePublisher
            .assign(to: \.isEnabled, on: contentView.undoButton)
            .store(in: &cancellables)

        canvasViewModel.needsRedoButtonStateUpdatePublisher
            .assign(to: \.isEnabled, on: contentView.redoButton)
            .store(in: &cancellables)

        canvasViewModel.canvasViewControllerUndoButtonsDisplayPublisher
            .sink { [weak self] shown in
                self?.contentView.undoButton.isHidden = !shown
                self?.contentView.redoButton.isHidden = !shown
            }
            .store(in: &cancellables)

        contentView.canvasView.needsTextureRefreshPublisher
            .sink { [weak self] in
                self?.canvasViewModel.updateCanvasView()
            }
            .store(in: &cancellables)
    }

    private func addEvents() {
        contentView.tapResetTransformButton = { [weak self] in
            self?.canvasViewModel.resetTransforming()
        }

        contentView.tapBlackButton = { [weak self] in
            self?.canvasViewModel.setDrawingTool(.brush)
            self?.canvasViewModel.setBrushColor(UIColor.black.withAlphaComponent(0.75))
        }
        contentView.tapRedButton = { [weak self] in
            self?.canvasViewModel.setDrawingTool(.brush)
            self?.canvasViewModel.setBrushColor(UIColor.red.withAlphaComponent(0.75))
        }
        contentView.tapEraserButton = { [weak self] in
            self?.canvasViewModel.setDrawingTool(.eraser)
        }
        contentView.changeBrushDiameter = { [weak self] value in
            self?.canvasViewModel.setBrushDiameter(value)
        }
        contentView.changeEraserDiameter = { [weak self] value in
            self?.canvasViewModel.setEraserDiameter(value)
        }

        contentView.tapLayerButton = { [weak self] in
            self?.textureLayerViewPresenter.toggleView()
        }
        contentView.tapSaveButton = { [weak self] in
            self?.canvasViewModel.saveFile()
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

        contentView.tapUndoButton = { [weak self] in
            self?.canvasViewModel.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.canvasViewModel.redo()
        }

        contentView.canvasView.addGestureRecognizer(
            FingerInputGestureRecognizer(delegate: self)
        )
        contentView.canvasView.addGestureRecognizer(
            PencilInputGestureRecognizer(delegate: self)
        )
    }
}

extension CanvasViewController {

    private func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            self?.canvasViewModel.newCanvas()
        }
    }

    private func setupLayerView(
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository,
        undoStack: UndoStack?
    ) {
        textureLayerViewPresenter.setupLayerViewPresenter(
            canvasState: canvasState,
            textureLayerRepository: textureLayerRepository,
            undoStack: undoStack,
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
                self?.canvasViewModel.loadFile(zipFileURL: url)
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
        if let image = contentView.canvasView.renderTexture?.uiImage {
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
        configuration: CanvasConfiguration = .init()
    ) -> Self {
        let viewController = Self()
        viewController.configuration = configuration
        return viewController
    }

}
