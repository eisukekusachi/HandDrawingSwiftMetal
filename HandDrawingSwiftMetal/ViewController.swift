//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
import SwiftUI
import Combine

class ViewController: UIViewController {

    @IBOutlet private weak var contentView: ContentView!

    private let canvasViewModel = CanvasViewModel()

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let layerViewPresenter = LayerViewPresenter()

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
            renderTarget: contentView.canvasView
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size
    }

}

extension ViewController {
    private func setupCanvasViewModel() {
        canvasViewModel.renderTarget = contentView.canvasView

        // Initialize the canvas with `CGSize`,
        // if not initialized here, it will be initialized with the screen size
        // when `func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)` is called.
        /*
        canvasViewModel.initCanvas(
            textureSize: .init(width: 768, height: 1024),
            renderTarget: contentView.canvasView
        )
        */
    }

    private func setupContentView() {
        contentView.bindTransforming(canvasViewModel.canvasTransformer)
        contentView.applyDrawingParameters(canvasViewModel.drawingTool)
        contentView.bindUndoModels(canvasViewModel.layerUndoManager)

        subscribeEvents()

        contentView.tapResetTransformButton = { [weak self] in
            self?.canvasViewModel.didTapResetTransformButton()
        }

        contentView.tapLayerButton = { [weak self] in
            self?.canvasViewModel.didTapLayerButton()
        }
        contentView.tapSaveButton = { [weak self] in
            guard let `self` else { return }
            self.canvasViewModel.didTapSaveButton(
                renderTarget: self.contentView.canvasView
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
            .sink { [weak self] in
                self?.layerViewPresenter.toggleVisible()
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
    }

    private func subscribeEvents() {
        let fingerInputGestureRecognizer = FingerInputGestureRecognizer()
        let pencilInputGestureRecognizer = PencilInputGestureRecognizer()

        contentView.canvasView.addGestureRecognizer(fingerInputGestureRecognizer)
        contentView.canvasView.addGestureRecognizer(pencilInputGestureRecognizer)

        fingerInputGestureRecognizer.gestureDelegate = self
        pencilInputGestureRecognizer.gestureDelegate = self
    }

}

extension ViewController {

    func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            self?.canvasViewModel.didTapNewCanvasButton()
        }
    }

    func setupLayerViewPresenter() {
        layerViewPresenter.setupLayerViewPresenter(
            layerManager: canvasViewModel.layerManager,
            targetView: contentView.layerButton,
            didTapLayer: { [weak self] layer in
                self?.canvasViewModel.didTapLayer(layer: layer)
            },
            didTapAddButton: { [weak self] in
                self?.canvasViewModel.didTapAddLayerButton()
            },
            didTapRemoveButton: { [weak self] in
                self?.canvasViewModel.didTapRemoveLayerButton()
            },
            didTapVisibility: { [weak self] layer, value in
                self?.canvasViewModel.didTapLayerVisibility(layer: layer, isVisible: value)
            },
            didChangeAlpha: { [weak self] layer, value in
                self?.canvasViewModel.didChangeLayerAlpha(layer: layer, value: value)
            },
            didEditTitle: { [weak self] layer, value in
                self?.canvasViewModel.didEditLayerTitle(layer: layer, title: value)
            },
            didMove: { [weak self] layer, source, destination in
                self?.canvasViewModel.didMoveLayers(layer: layer, source: source, destination: destination)
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

extension ViewController {

    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            showToast(.init(title: "Failed", systemName: "exclamationmark.circle"))
        } else {
            showToast(.init(title: "Success", systemName: "hand.thumbsup.fill"))
        }
    }

}

extension ViewController: FingerInputGestureSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onFingerGestureDetected(
            touches: touches,
            with: event,
            view: view,
            renderTarget: contentView.canvasView
        )
    }

}

extension ViewController: PencilInputGestureSender {

    func sendPencilTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.onPencilGestureDetected(
            touches: touches,
            with: event,
            view: view,
            renderTarget: contentView.canvasView
        )
    }

}
