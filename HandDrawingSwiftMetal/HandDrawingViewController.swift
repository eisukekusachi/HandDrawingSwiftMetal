//
//  HandDrawingViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import CanvasView
import UIKit
import SwiftUI
import Combine

class HandDrawingViewController: UIViewController {

    @IBOutlet private weak var contentView: HandDrawingContentView!

    @IBOutlet private weak var activityIndicatorView: UIView!

    private var canvasConfiguration: CanvasConfiguration?

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    private let paletteHeight: CGFloat = 44

    private let drawingRenderers: [DrawingToolType: any DrawingRenderer] = [
        .brush: BrushDrawingRenderer(),
        .eraser: EraserDrawingRenderer()
    ]

    private let viewModel = HandDrawingViewModel()

    public var zipFileURL: URL {
        FileManager.documentsFileURL(
            projectName: viewModel.project.projectName,
            suffix: viewModel.fileSuffix
        )
    }

    var currentLocalFileItem: LocalFileItem {
        .init(
            title: viewModel.project.projectName,
            createdAt: viewModel.project.createdAt,
            updatedAt: viewModel.project.updatedAt,
            image: contentView.canvasView.thumbnail(),
            fileURL: URL.documents.appendingPathComponent(
                viewModel.projectFileName()
            )
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        addEvents()
        bindData()
        layoutViews()

        setupTextureLayerViewPresenter()
        setupNewCanvasDialogPresenter()
        setupCanvasView()
    }

    private func setupCanvasView() {
        showActivityIndicator(true)
        showContentView(false)
        Task { [weak self] in
            guard
                let `self`
            else { return }

            defer {
                self.showActivityIndicator(false)
                self.showContentView(true)
            }
            do {
                let configuration: CanvasConfiguration = self.canvasConfiguration ?? .init()

                self.drawingRenderers.forEach {
                    $0.value.setup(
                        renderer: self.contentView.canvasView.renderer
                    )
                }
                try await contentView.canvasView.setup(
                    drawingRenderers: self.drawingRenderers.map { $0.value },
                    configuration: configuration
                )
                try self.viewModel.setup(configuration: configuration)

                // Set the undo limit
                self.contentView.canvasView.undoManager?.levelsOfUndo = configuration.undoCount

                self.updateComponents()

            } catch {
                fatalError("Failed to initialize the canvas")
            }
        }
    }

    private func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard
                let `self`,
                let canvasView = self.contentView.canvasView
            else { return }

            Task {
                defer { self.showActivityIndicator(false) }
                self.showActivityIndicator(true)

                do {
                    try await canvasView.newCanvas()

                    self.viewModel.resetCoreData()

                    self.updateComponents()

                } catch {
                    self.showAlert(error)
                }
            }
        }
    }

    private func setupTextureLayerViewPresenter() {
        textureLayerViewPresenter.setup(
            configuration: .init(
                anchorButton: contentView.layerButton,
                destinationView: contentView,
                size: .init(
                    width: 300,
                    height: 300
                )
            )
        )
    }
}

extension HandDrawingViewController {
    private func bindData() {

        contentView.canvasView.setupCompletion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard
                    let `self`,
                    let textureLayers = self.contentView.canvasView.undoTextureLayers
                else { return }

                self.contentView.canvasView.setupCompletion(textureSize: result.textureSize)
                self.contentView.canvasView.resetUndo()

                // Update the thumbnails
                Task {
                    for layer in textureLayers.textureLayers.layers {
                        try await textureLayers.updateThumbnail(layer.id)
                    }
                }

                // Initialize the textures in DrawingRenderer
                for renderer in drawingRenderers.values {
                    renderer.setupTextures(textureSize: result.textureSize)
                }

                self.textureLayerViewPresenter.update(
                    textureLayers: textureLayers
                )
                self.contentView.initialize()
            }
            .store(in: &cancellables)

        contentView.canvasView.fingerDrawingDidBegin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let `self` else { return }
                self.enableComponentsInteraction(false)
                Task {
                    await self.contentView.canvasView.undoTextureLayers?.setUndoDrawing(
                        texture: self.contentView.canvasView.currentTexture
                    )
                }
            }
            .store(in: &cancellables)

        contentView.canvasView.pencilDrawingDidBegin
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let `self` else { return }
                self.enableComponentsInteraction(false)
                Task {
                    await self.contentView.canvasView.undoTextureLayers?.setUndoDrawing(
                        texture: self.contentView.canvasView.currentTexture
                    )
                }
            }
            .store(in: &cancellables)

        contentView.canvasView.drawingCompletion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                guard let `self` else { return }
                Task {
                    try await self.contentView.canvasView.undoTextureLayers?.pushUndoDrawingObjectToUndoStack(
                        texture: self.contentView.canvasView.currentTexture
                    )
                }

                self.enableComponentsInteraction(true)

                // Update the project's updatedAt value to the current time
                self.viewModel.project.update(
                    updatedAt: Date()
                )
            }
            .store(in: &cancellables)

        contentView.canvasView.undoTextureLayers?.didEmitUndoObjectPair
            .sink { [weak self] undoObjectPair in
                self?.contentView.canvasView.registerUndoObjectPair(undoObjectPair)
            }
            .store(in: &cancellables)

        contentView.canvasView.didUndo
            .sink { [weak self] state in
                self?.contentView.setUndoRedoButtonState(state)
            }
            .store(in: &cancellables)

        viewModel.activityIndicator
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        viewModel.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(error)
            }
            .store(in: &cancellables)

        viewModel.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        viewModel.brushPalette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.brushPalette.colors.count else { return }
                let newColor = viewModel.brushPalette.colors[index]
                (self.drawingRenderers[.brush] as? BrushDrawingRenderer)?.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPalette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.eraserPalette.alphas.count else { return }
                let newAlpha = viewModel.eraserPalette.alphas[index]
                (self.drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setAlpha(newAlpha)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$brushDiameter
            .sink { [weak self] diameter in
                (self?.drawingRenderers[.brush] as? BrushDrawingRenderer)?.setDiameter(diameter)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$eraserDiameter
            .sink { [weak self] diameter in
                (self?.drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setDiameter(diameter)
            }
            .store(in: &cancellables)
    }

    private func addEvents() {
        contentView.tapLayerButton = { [weak self] in
            self?.textureLayerViewPresenter.toggleView()
        }
        contentView.tapSaveButton = { [weak self] in
            self?.saveProject()
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
        contentView.tapDrawingToolButton = { [weak self] in
            guard
                let `self`
            else { return }
            self.viewModel.toggleDrawingTool()

            self.contentView.updateDrawingComponents(viewModel.drawingTool.type)

            guard let renderer = self.drawingRenderers[self.viewModel.drawingTool.type] else { return }
            self.contentView.canvasView.setDrawingTool(renderer)
        }
        contentView.tapUndoButton = { [weak self] in
            self?.contentView.canvasView.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.contentView.canvasView.redo()
        }

        contentView.dragBrushSlider = { [weak self] value in
            self?.viewModel.drawingTool.brushDiameter = BrushDrawingRenderer.diameterIntValue(value)
        }
        contentView.dragEraserSlider = { [weak self] value in
            self?.viewModel.drawingTool.eraserDiameter = EraserDrawingRenderer.diameterIntValue(value)
        }
    }

    private func layoutViews() {
        addBrushPalette()
        addEraserPalette()
    }

    private func addBrushPalette() {
        let targetView: UIView = contentView.brushPaletteView

        let brushPaletteHostingView = UIHostingController(
            rootView: BrushPaletteView(
                palette: viewModel.brushPalette,
                paletteHeight: paletteHeight
            )
        )
        brushPaletteHostingView.view.backgroundColor = .clear
        targetView.addSubview(brushPaletteHostingView.view)

        brushPaletteHostingView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brushPaletteHostingView.view.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            brushPaletteHostingView.view.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
            brushPaletteHostingView.view.topAnchor.constraint(equalTo: targetView.topAnchor),
            brushPaletteHostingView.view.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
        ])
    }

    private func addEraserPalette() {
        let targetView: UIView = contentView.eraserPaletteView

        let eraserPaletteHostingView = UIHostingController(
            rootView: EraserPaletteView(
                palette: viewModel.eraserPalette,
                paletteHeight: paletteHeight
            )
        )
        eraserPaletteHostingView.view.backgroundColor = .clear
        targetView.addSubview(eraserPaletteHostingView.view)

        eraserPaletteHostingView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eraserPaletteHostingView.view.leadingAnchor.constraint(equalTo: targetView.leadingAnchor),
            eraserPaletteHostingView.view.trailingAnchor.constraint(equalTo: targetView.trailingAnchor),
            eraserPaletteHostingView.view.topAnchor.constraint(equalTo: targetView.topAnchor),
            eraserPaletteHostingView.view.bottomAnchor.constraint(equalTo: targetView.bottomAnchor)
        ])
    }

    private func updateComponents() {
        (drawingRenderers[.brush] as? BrushDrawingRenderer)?.setDiameter(viewModel.drawingTool.brushDiameter)
        (drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setDiameter(viewModel.drawingTool.eraserDiameter)

        contentView.updateDrawingComponents(viewModel.drawingTool.type)

        guard let renderer = drawingRenderers[viewModel.drawingTool.type] else { return }
        contentView.canvasView.setDrawingTool(renderer)

        contentView.setBrushDiameterSlider(viewModel.drawingTool.brushDiameter)
        contentView.setEraserDiameterSlider(viewModel.drawingTool.eraserDiameter)
    }
}

extension HandDrawingViewController {
    private func showFileView() {
        let fileView = FileView(
            list: viewModel.fileList,
            onTapItem: { [weak self] zipFileURL in
                guard let `self` else { return }
                self.presentedViewController?.dismiss(animated: true)
                self.textureLayerViewPresenter.hide()
                self.loadProject(zipFileURL: zipFileURL)
            }
        )

        let vc = UIHostingController(rootView: fileView)

        present(vc, animated: true)
    }

    private func showAlert(_ error: CanvasError) {
        dialogPresenter.configuration = .init(
            title: error.title,
            message: error.message
        )
        dialogPresenter.presentAlert(on: self)
    }

    private func showAlert(_ error: Error) {
        dialogPresenter.configuration = .init(
            title: "Error",
            message: error.localizedDescription
        )
        dialogPresenter.presentAlert(on: self)
    }

    private func showToast(_ model: ToastMessage) {
        let toast = Toast()
        toast.showMessage(model)
        view.addSubview(toast)
    }

    private func showActivityIndicator(_ isShown: Bool) {
        activityIndicatorView.isHidden = !isShown
    }

    private func showContentView(_ isShown: Bool) {
        contentView.isHidden = !isShown
    }

    private func enableComponentsInteraction(_ isUserInteractionEnabled: Bool) {
        contentView.enableComponentsInteraction(isUserInteractionEnabled)
        textureLayerViewPresenter.enableComponentInteraction(isUserInteractionEnabled)
    }
}

extension HandDrawingViewController {

    private func loadProject(zipFileURL: URL) {
        self.viewModel.loadFile(
            zipFileURL: zipFileURL,
            action: { [weak self] workingDirectoryURL in
                try await self?.contentView.canvasView.loadFiles(
                    in: workingDirectoryURL
                )
            },
            completion: { [weak self] in
                self?.updateComponents()
            }
        )
    }
    private func saveProject() {
        viewModel.saveProject(
            action: { [weak self] workingDirectoryURL in

                try await self?.contentView.canvasView.saveFiles(
                    to: workingDirectoryURL
                )
            },
            completion: { [weak self] in
                guard let `self` else { return }
                self.viewModel.upsertFileList(
                    fileItem: currentLocalFileItem
                )
            },
            zipFileURL: zipFileURL
        )
    }

    private func saveImage() {
        if let image = contentView.canvasView.displayTexture?.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        }
    }
    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error {
            Logger.error(error)
            showAlert(error)
        } else {
            showToast(
                .init(
                    title: "Success",
                    icon: UIImage(systemName: "hand.thumbsup.fill")
                )
            )
        }
    }
}

extension HandDrawingViewController {

    static func create(
        canvasConfiguration: CanvasConfiguration
    ) -> Self {
        let viewController = Self()
        viewController.canvasConfiguration = canvasConfiguration
        return viewController
    }
}
