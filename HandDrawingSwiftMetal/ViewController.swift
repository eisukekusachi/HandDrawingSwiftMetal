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

    lazy var layerViewController = UIHostingController<LayerView>(rootView: LayerView(layerManager: canvasViewModel.parameters.layerManager))

    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupContentView()
        setupNewCanvasDialogPresenter()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasViewModel.frameSize = view.frame.size

        if canvasViewModel.parameters.textureSizeSubject.value == .zero {
            canvasViewModel.parameters.textureSizeSubject.send(contentView.canvasView.drawableSize)
            canvasViewModel.initTexture(canvasRootTexture: contentView.canvasView.rootTexture)
        }
    }
    
    func initAllComponents() {

        contentView.canvasView.clearUndo()
        refreshUndoRedoButtons()
    }
    func refreshUndoRedoButtons() {
        contentView.undoButton.isEnabled = contentView.canvasView.canUndo
        contentView.redoButton.isEnabled = contentView.canvasView.canRedo
    }

}

extension ViewController {

    private func setupContentView() {
        contentView.canvasView.setViewModel(canvasViewModel)
        contentView.applyDrawingParameters(canvasViewModel.parameters)

        contentView.tapResetTransformButton = { [weak self] in
            self?.canvasViewModel.didTapResetTransformButton()
        }

        contentView.tapSaveButton = { [weak self] in
            guard let `self` else { return }
            saveCanvas(into: URL.tmpFolderURL,
                       with: canvasViewModel.zipFileNameName)
        }
        contentView.tapLayerButton = { [weak self] in
            self?.toggleLayerVisibility()
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

        contentView.canvasView.$undoCount
            .sink { [weak self] _ in
                self?.refreshUndoRedoButtons()
            }
            .store(in: &cancellables)
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

    func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let rootTexture = self?.contentView.canvasView.rootTexture else { return }
            self?.canvasViewModel.newCanvas(rootTexture: rootTexture)
        }
    }

}

extension ViewController {

    func saveCanvas(into tmpFolderURL: URL, with zipFileName: String) {
        createTemporaryFolderWithErrorHandling(tmpFolderURL: tmpFolderURL) { [weak self] tmpFolderURL in
            guard   let self,
                    let currentTexture = contentView.canvasView.rootTexture else { return }

            let layerIndex = canvasViewModel.parameters.layerManager.index
            let codableLayers = try await canvasViewModel.parameters.layerManager.layers.convertToLayerModelCodable(imageFolderURL: tmpFolderURL)
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

            initAllComponents()
            canvasViewModel.parameters.layerManager.updateNonSelectedTextures(commandBuffer: contentView.canvasView.commandBuffer)

            canvasViewModel.parameters.mergeAllLayers(to: contentView.canvasView.rootTexture,
                                                      contentView.canvasView.commandBuffer)
            
            canvasViewModel.parameters.setNeedsDisplaySubject.send()
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

extension ViewController {

    func toggleLayerVisibility() {
        if !existHostingController() {
            let marginRight: CGFloat = 8
            let viewWidth: CGFloat = 300.0
            let viewHeight: CGFloat = 300.0
            let viewX: CGFloat = view.frame.width - (viewWidth + marginRight)

            canvasViewModel.parameters.layerManager.arrowPointX = contentView.layerButton.convert(contentView.layerButton.bounds, to: view).midX - viewX

            view.addSubview(layerViewController.view)

            layerViewController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                layerViewController.view.topAnchor.constraint(equalTo: contentView.topStackView.bottomAnchor),
                layerViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -marginRight),

                layerViewController.view.widthAnchor.constraint(equalToConstant: viewWidth),
                layerViewController.view.heightAnchor.constraint(equalToConstant: viewHeight)
            ])

            layerViewController.view.backgroundColor = .clear

        } else {
            layerViewController.view.removeFromSuperview()
        }
    }

    func existHostingController() -> Bool {
        return view.subviews.contains { subview in
            return subview == layerViewController.view
        }
    }

}
