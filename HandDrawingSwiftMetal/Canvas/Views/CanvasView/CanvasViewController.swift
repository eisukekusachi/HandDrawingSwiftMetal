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
        textureRepository: DocumentsFolderTextureSingletonRepository.shared
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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvasViewModel.onViewDidAppear(
            configuration: configuration,
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

    private func bindData() {

        canvasViewModel.needsShowingActivityIndicatorPublisher
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        canvasViewModel.needsShowingAlertPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.showAlert(
                    title: "Alert",
                    message: message
                )
            }
            .store(in: &cancellables)

        canvasViewModel.needsShowingToastPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        canvasViewModel.needsShowingLayerViewPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isShown in
                self?.textureLayerViewPresenter.showView(isShown)
            }
            .store(in: &cancellables)

        canvasViewModel.canvasViewControllerSetupPublisher
            .sink { [weak self] configuration in
                self?.setupLayerView(
                    canvasState: configuration.canvasState,
                    textureRepository: configuration.textureRepository
                )
                self?.contentView.setup(
                    configuration.canvasState
                )
            }
            .store(in: &cancellables)

        canvasViewModel.canvasInitializationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] configuration in
                self?.canvasViewModel.initializeCanvas(using: configuration)
            }
            .store(in: &cancellables)

        canvasViewModel.needsUndoButtonStateUpdatePublisher
            .assign(to: \.isEnabled, on: contentView.undoButton)
            .store(in: &cancellables)

        canvasViewModel.needsRedoButtonStateUpdatePublisher
            .assign(to: \.isEnabled, on: contentView.redoButton)
            .store(in: &cancellables)

        contentView.canvasView.needsTextureRefreshPublisher
            .sink { [weak self] in
                self?.canvasViewModel.updateCanvas()
            }
            .store(in: &cancellables)
    }

    private func addEvents() {
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
            self?.setupFileView()
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
            self?.canvasViewModel.didTapUndoButton()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.canvasViewModel.didTapRedoButton()
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
            self?.canvasViewModel.didTapNewCanvasButton()
        }
    }

    private func setupLayerView(canvasState: CanvasState, textureRepository: TextureRepository) {
        textureLayerViewPresenter.setupLayerViewPresenter(
            canvasState: canvasState,
            textureRepository: textureRepository,
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

    private func setupFileView() {
        let zipFilePashArray: [String] = URL.documents.allFileURLs(suffix: URL.zipSuffix).map {
            $0.lastPathComponent
        }

        let fileView = FileView(
            zipFileList: zipFilePashArray,
            didTapItem: { [weak self] selectedZipFilePath in
                self?.canvasViewModel.didTapLoadButton(filePath: selectedZipFilePath)
                self?.presentedViewController?.dismiss(animated: true)
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
