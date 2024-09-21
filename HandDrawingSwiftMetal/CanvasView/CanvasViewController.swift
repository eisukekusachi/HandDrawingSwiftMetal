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

    private let canvasViewModel = CanvasViewModel()

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupContentView()
        setupCanvasViewModel()

        setupNewCanvasDialogPresenter()
        setupLayerViewPresenter()

        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        canvasViewModel.onViewDidAppear(
            contentView.canvasView.drawableSize,
            canvasView: contentView.canvasView
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size
    }

}

extension CanvasViewController {
    private func setupCanvasViewModel() {
        // Initialize the canvas with `CGSize`,
        // if not initialized here, it will be initialized with the screen size
        // when `func viewDidAppear` is called.
        /*
        canvasViewModel.initCanvas(
            textureSize: .init(width: 768, height: 1024)
        )
        */
    }

    private func setupContentView() {
        contentView.applyDrawingParameters(canvasViewModel.drawingTool)

        subscribeEvents()

        contentView.tapResetTransformButton = { [weak self] in
            guard let `self` else { return }
            self.canvasViewModel.didTapResetTransformButton(
                canvasView: self.contentView.canvasView
            )
        }

        contentView.tapLayerButton = { [weak self] in
            self?.canvasViewModel.didTapLayerButton()
        }
        contentView.tapSaveButton = { [weak self] in
            guard let `self` else { return }
            self.canvasViewModel.didTapSaveButton(
                canvasView: self.contentView.canvasView
            )
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

    private func bindViewModel() {
        canvasViewModel.pauseDisplayLinkPublisher
            .assign(to: \.isDisplayLinkPaused, on: contentView)
            .store(in: &cancellables)

        canvasViewModel.requestShowingActivityIndicatorPublisher
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHiddenActivityIndicator, on: contentView)
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
                guard let `self` else { return }
                self.canvasViewModel.apply(
                    model: model,
                    to: self.contentView.canvasView
                )
            }
            .store(in: &cancellables)

        canvasViewModel.refreshCanvasWithUndoObjectPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] undoObject in
                guard let `self` else { return }
                self.canvasViewModel.apply(
                    undoObject: undoObject,
                    to: self.contentView.canvasView
                )
            }
            .store(in: &cancellables)

        canvasViewModel.refreshCanUndoPublisher
            .assign(to: \.isEnabled, on: contentView.undoButton)
            .store(in: &cancellables)

        canvasViewModel.refreshCanRedoPublisher
            .assign(to: \.isEnabled, on: contentView.redoButton)
            .store(in: &cancellables)
    }

    private func subscribeEvents() {
        contentView.canvasView.addGestureRecognizer(
            CanvasFingerInputGestureRecognizer(delegate: self)
        )
        contentView.canvasView.addGestureRecognizer(
            CanvasPencilInputGestureRecognizer(delegate: self)
        )

        contentView.canvasView.updateTexturePublisher
            .sink { [weak self] in
                guard let `self` else { return }
                self.canvasViewModel.onUpdateRenderTexture(
                    canvasView: self.contentView.canvasView
                )
            }
            .store(in: &cancellables)

    }

}

extension CanvasViewController {

    func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let `self` else { return }
            self.canvasViewModel.didTapNewCanvasButton(
                canvasView: self.contentView.canvasView
            )
        }
    }

    func setupLayerViewPresenter() {
        textureLayerViewPresenter.setupLayerViewPresenter(
            textureLayers: canvasViewModel.textureLayers,
            targetView: contentView.layerButton,
            didTapLayer: { [weak self] layer in
                guard let `self` else { return }
                self.canvasViewModel.didTapLayer(
                    layer: layer,
                    canvasView: self.contentView.canvasView
                )
            },
            didTapAddButton: { [weak self] in
                guard let `self` else { return }
                self.canvasViewModel.didTapAddLayerButton(
                    canvasView: self.contentView.canvasView
                )
            },
            didTapRemoveButton: { [weak self] in
                guard let `self` else { return }
                self.canvasViewModel.didTapRemoveLayerButton(
                    canvasView: self.contentView.canvasView
                )
            },
            didTapVisibility: { [weak self] layer, value in
                guard let `self` else { return }
                self.canvasViewModel.didTapLayerVisibility(
                    layer: layer,
                    isVisible: value,
                    canvasView: self.contentView.canvasView
                )
            },
            didChangeAlpha: { [weak self] layer, value in
                guard let `self` else { return }
                self.canvasViewModel.didChangeLayerAlpha(
                    layer: layer,
                    value: value,
                    canvasView: self.contentView.canvasView
                )
            },
            didEditTitle: { [weak self] layer, value in
                self?.canvasViewModel.didEditLayerTitle(
                    layer: layer,
                    title: value
                )
            },
            didMove: { [weak self] layer, source, destination in
                guard let `self` else { return }
                self.canvasViewModel.didMoveLayers(
                    layer: layer, 
                    source: source,
                    destination: destination,
                    canvasView: self.contentView.canvasView)
            },
            on: self
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

extension CanvasViewController: CanvasFingerInputGestureRecognizerSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view,
            canvasView: contentView.canvasView
        )
    }

}

extension CanvasViewController: CanvasPencilInputGestureRecognizerSender {

    func sendPencilEstimatedTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            estimatedTouches: touches,
            with: event,
            view: view,
            canvasView: contentView.canvasView
        )
    }

    func sendPencilActualTouches(_ touches: Set<UITouch>, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            actualTouches: touches,
            view: view,
            canvasView: contentView.canvasView
        )
    }

}
