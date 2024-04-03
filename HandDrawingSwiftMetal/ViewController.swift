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

    let canvasViewModel = CanvasViewModel()

    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let layerViewPresenter = LayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupContentView()
        setupNewCanvasDialogPresenter()
        setupLayerViewPresenter()

        bindViewModel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size

        canvasViewModel.initTextureSizeIfSizeIsZero(
            frameSize: view.frame.size,
            drawableSize: contentView.canvasView.drawableSize
        )
    }
    
}

extension ViewController {

    private func setupContentView() {
        contentView.canvasView.setViewModel(canvasViewModel)
        contentView.applyDrawingParameters(canvasViewModel.drawingTool)
        subscribeEvents()

        contentView.tapResetTransformButton = { [weak self] in
            self?.canvasViewModel.didTapResetTransformButton()
        }

        contentView.tapSaveButton = { [weak self] in
            guard let `self` else { return }
            saveCanvas(into: URL.tmpFolderURL,
                       with: canvasViewModel.zipFileNameName)
        }
        contentView.tapLayerButton = { [weak self] in
            self?.layerViewPresenter.toggleVisible()
        }
        contentView.tapLoadButton = { [weak self] in
            guard let `self` else { return }
            let zipFileList = URL.documents.allFileURLs(suffix: URL.zipSuffix).map {
                $0.lastPathComponent
            }
            let fileView = FileView(zipFileList: zipFileList,
                                    didTapItem: { [weak self] zipFilePath in

                self?.loadCanvas(from: zipFilePath,
                                 into: URL.tmpFolderURL)
                self?.presentedViewController?.dismiss(animated: true)
            })
            let vc = UIHostingController(rootView: fileView)
            present(vc, animated: true)
        }
        contentView.tapExportImageButton = { [weak self] in
            guard let `self` else { return }
            contentView.exportImageButton.debounce()

            if let image = contentView.canvasView.rootTexture?.uiImage {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
            }
        }
        contentView.tapNewButton = { [weak self] in
            guard let `self` else { return }
            newCanvasDialogPresenter.presentAlert(on: self)
        }

        contentView.tapUndoButton = { [weak self] in
            self?.contentView.canvasView.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.contentView.canvasView.redo()
        }
    }

    private func bindViewModel() {

        canvasViewModel.pauseDisplayLinkPublisher
            .sink { [weak self] pause in
                self?.contentView.pauseDisplayLinkLoop(pause)
            }
            .store(in: &cancellables)

        canvasViewModel.clearUndoPublisher
            .sink { [weak self] in
                self?.contentView.canvasView.clearUndo()
            }
            .store(in: &cancellables)

        canvasViewModel.addUndoObjectToUndoStackPublisher
            .sink { [weak self] in
                self?.contentView.canvasView.registerDrawingUndoAction()
            }
            .store(in: &cancellables)
    }

    private func subscribeEvents() {
        let fingerInputGestureRecognizer = FingerInputGestureRecognizer()
        let pencilInputGestureRecognizer = PencilInputGestureRecognizer()

        view.addGestureRecognizer(fingerInputGestureRecognizer)
        view.addGestureRecognizer(pencilInputGestureRecognizer)

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
            layerManager: canvasViewModel.drawingTool.layerManager,
            targetView: contentView.layerButton,
            on: self)
    }

}

extension ViewController {

    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            view.addSubview(Toast(text: "Failed"))
        } else {
            view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))
        }
    }

}

extension ViewController {

    func saveCanvas(into tmpFolderURL: URL, with zipFileName: String) {
        createTemporaryFolderWithErrorHandling(tmpFolderURL: tmpFolderURL) { [weak self] tmpFolderURL in
            guard   let self,
                    let currentTexture = contentView.canvasView.rootTexture else { return }

            let layerIndex = canvasViewModel.drawingTool.layerManager.index
            let codableLayers = try await canvasViewModel.drawingTool.layerManager.layers.convertToLayerModelCodable(imageFolderURL: tmpFolderURL)
            try canvasViewModel.saveCanvasAsZipFile(rootTexture: currentTexture,
                                                    layerIndex: layerIndex,
                                                    codableLayers: codableLayers,
                                                    tmpFolderURL: tmpFolderURL,
                                                    with: zipFileName)
        }
    }

    func loadCanvas(from zipFilePath: String, into tmpFolderURL: URL) {
        createTemporaryFolderWithErrorHandling(tmpFolderURL: tmpFolderURL) { [weak self] folderURL in
            guard let self else { return }

            if let data = try canvasViewModel.loadCanvasDataV2(from: zipFilePath, into: folderURL) {
                guard let textureSize = data.textureSize,
                      let layers = try data.layers?.compactMap({ $0 }).convertToLayerModel(device: canvasViewModel.device,
                                                                                           textureSize: textureSize,
                                                                                           folderURL: folderURL) else { return }
                try canvasViewModel.applyCanvasDataToCanvasV2(data,
                                                              layers: layers,
                                                              folderURL: folderURL,
                                                              zipFilePath: zipFilePath)

            } else if let data = try canvasViewModel.loadCanvasData(from: zipFilePath,
                                                                    into: folderURL) {
                try canvasViewModel.applyCanvasDataToCanvas(data,
                                                            folderURL: folderURL,
                                                            zipFilePath: zipFilePath)
            }

            contentView.initUndoComponents()

            canvasViewModel.drawingTool.layerManager.addCommandToMergeUnselectedLayers(
                to: contentView.canvasView.commandBuffer
            )

            canvasViewModel.drawingTool.addCommandToMergeAllLayers(
                backgroundColor: contentView.canvasView.backgroundColor ?? .white,
                onto: contentView.canvasView.rootTexture,
                to: contentView.canvasView.commandBuffer
            )

            contentView.canvasView.setNeedsDisplay()
        }
    }

    private func createTemporaryFolderWithErrorHandling(tmpFolderURL: URL,
                                                        _ tasks: @escaping (URL) async throws -> Void) {
        Task {
            let activityIndicatorView = ActivityIndicatorView(frame: view.frame)
            defer {
                try? FileManager.default.removeItem(atPath: tmpFolderURL.path)
                activityIndicatorView.removeFromSuperview()
            }
            view.addSubview(activityIndicatorView)

            do {
                // Clean up the temporary folder when done
                try FileManager.createNewDirectory(url: tmpFolderURL)

                try await tasks(tmpFolderURL)

                try await Task.sleep(nanoseconds: UInt64(1_000_000_000))

                view.addSubview(Toast(text: "Success", systemName: "hand.thumbsup.fill"))

            } catch {
                view.addSubview(Toast(text: error.localizedDescription))
            }
        }
    }

}

extension ViewController: FingerInputGestureSender {

    func sendFingerTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.handleFingerInputGesture(touches, with: event, on: view)
    }

}

extension ViewController: PencilInputGestureSender {

    func sendPencilTouches(_ touches: Set<UITouch>, with event: UIEvent?, on view: UIView) {
        canvasViewModel.handlePencilInputGesture(touches, with: event, on: view)
    }

}
