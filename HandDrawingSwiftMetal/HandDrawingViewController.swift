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

    private var configuration: ProjectConfiguration?

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private var textureLayerViewPresenter: TextureLayerViewPresenter?

    private var cancellables = Set<AnyCancellable>()

    private let paletteHeight: CGFloat = 44

    private let canvasView = HandDrawingCanvasView()

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
            image: canvasView.canvasTexture?.uiImage?.resizeWithAspectRatio(
                height: HandDrawingCanvasView.thumbnailLength,
                scale: 1.0
            ),
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
        setup()
    }

    private func setup() {
        showActivityIndicator(true)
        showContentView(false)
        Task { [weak self] in
            guard let `self` else { return }

            defer {
                self.showActivityIndicator(false)
                self.showContentView(true)
            }
            do {
                let configuration: ProjectConfiguration = self.configuration ?? .init(
                    canvasConfiguration: .init()
                )

                self.drawingRenderers.forEach {
                    $0.value.setup(
                        renderer: self.canvasView.renderer
                    )
                }
                try await self.canvasView.setup(
                    drawingRenderers: self.drawingRenderers.map { $0.value },
                    configuration: configuration.canvasConfiguration
                )
                try self.viewModel.setup(configuration: configuration)

                // Set the undo limit
                self.canvasView.undoManager?.levelsOfUndo = configuration.undoCount

                self.updateComponents()

            } catch {
                fatalError("Failed to initialize the canvas")
            }
        }
    }

    private func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let `self` else { return }

            Task {
                defer { self.showActivityIndicator(false) }
                self.showActivityIndicator(true)

                do {
                    try await self.canvasView.newCanvas()

                    self.viewModel.resetCoreData()

                    self.updateComponents()

                } catch {
                    self.showAlert(error)
                }
            }
        }
    }

    private func setupTextureLayerViewPresenter() {
        textureLayerViewPresenter?.setup(
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

        canvasView.canvasEvents
            .compactMap { event -> CGSize? in
                guard case let .canvasCreated(size) = event else { return nil }
                return size
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] textureSize in
                guard
                    let `self`,
                    let textureLayers = self.canvasView.textureLayers
                else { return }

                // Initialize the textures in DrawingRenderer
                for renderer in drawingRenderers.values {
                    renderer.initializeTextures(textureSize)
                }

                self.textureLayerViewPresenter?.update(
                    textureLayers: textureLayers
                )
                self.contentView.initialize()

                // Update the thumbnails
                Task {
                    for layer in textureLayers.layers {
                        try await textureLayers.updateThumbnail(layer.id)
                    }
                }
            }
            .store(in: &cancellables)

        canvasView.strokeEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let `self` else { return }
                switch event {
                case .fingerStrokeBegan:
                    self.enableComponentsInteraction(false)
                    /*
                    Task {
                        await self.canvasView.undoTextureLayers?.setUndoDrawing(
                            texture: self.canvasView.currentTexture
                        )
                    }
                    */
                case .pencilStrokeBegan:
                    self.enableComponentsInteraction(false)
                    /*
                    Task {
                        await self.canvasView.undoTextureLayers?.setUndoDrawing(
                            texture: self.canvasView.currentTexture
                        )
                    }
                    */
                case .strokeCompleted:
                    /*
                    Task {
                        try await self.canvasView.undoTextureLayers?.pushUndoDrawingObjectToUndoStack(
                            texture: self.canvasView.currentTexture
                        )
                    }

                    // Update the project's updatedAt value to the current time
                    self.viewModel.project.update(
                        updatedAt: Date()
                    )
                    */
                    self.enableComponentsInteraction(true)

                case .strokeCancelled:
                    self.enableComponentsInteraction(true)
                }
            }
            .store(in: &cancellables)

        /*
        canvasView.undoTextureLayers?.didEmitUndoObjectPair
            .sink { [weak self] undoObjectPair in
                self?.canvasView.registerUndoObjectPair(undoObjectPair)
            }
            .store(in: &cancellables)

        canvasView.didUndo
            .sink { [weak self] state in
                self?.contentView.setUndoRedoButtonState(state)
            }
            .store(in: &cancellables)
        */

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
        contentView.tapResetTransforming = { [weak self] in
            self?.canvasView.resetTransforming()
        }
        contentView.tapLayerButton = { [weak self] in
            self?.textureLayerViewPresenter?.toggleView()
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
            self.canvasView.setDrawingRenderer(renderer)
        }
        contentView.tapUndoButton = { [weak self] in
            self?.canvasView.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.canvasView.redo()
        }

        contentView.dragBrushSlider = { [weak self] value in
            self?.viewModel.drawingTool.brushDiameter = BrushDrawingRenderer.diameterIntValue(value)
        }
        contentView.dragEraserSlider = { [weak self] value in
            self?.viewModel.drawingTool.eraserDiameter = EraserDrawingRenderer.diameterIntValue(value)
        }
    }

    private func layoutViews() {

        textureLayerViewPresenter = TextureLayerViewPresenter(device: canvasView.sharedDevice)

        if let baseView = contentView.baseView {
            baseView.addSubview(canvasView)
            canvasView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                canvasView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
                canvasView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
                canvasView.topAnchor.constraint(equalTo: baseView.topAnchor),
                canvasView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor)
            ])
        }

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
        canvasView.setDrawingRenderer(renderer)

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
                self.textureLayerViewPresenter?.hide()
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
        textureLayerViewPresenter?.enableComponentInteraction(isUserInteractionEnabled)
    }
}

extension HandDrawingViewController {

    private func loadProject(zipFileURL: URL) {
        self.viewModel.loadFile(
            zipFileURL: zipFileURL,
            action: { [weak self] workingDirectoryURL in
                try await self?.canvasView.loadFiles(
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

                try await self?.canvasView.saveFiles(
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
        if let image = canvasView.canvasTexture?.uiImage {
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
        configuration: ProjectConfiguration
    ) -> Self {
        let viewController = Self()
        viewController.configuration = configuration
        return viewController
    }
}
