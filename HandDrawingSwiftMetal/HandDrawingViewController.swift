//
//  HandDrawingViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import CanvasView
import Combine
import SwiftUI
import TextureLayerCanvasView
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

class HandDrawingViewController: UIViewController {

    var zipFileURL: URL {
        FileManager.documentsFileURL(
            projectName: viewModel.project.projectName,
            suffix: viewModel.fileSuffix
        )
    }

    @IBOutlet private weak var contentView: HandDrawingContentView!

    @IBOutlet private weak var activityIndicatorView: UIView!

    private var configuration: ProjectConfiguration = .init(canvasConfiguration: .init())

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private var textureLayerPopup: UIHostingController<AnyView>?
    private var textureLayerPresenter = PopupViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    private let paletteHeight: CGFloat = 44

    /// The `MTLDevice` used throughout the app
    private lazy var sharedDevice: MTLDevice = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        return device
    }()

    private lazy var undoCoordinator: UndoCoordinator = {
        .init(
            canvasView: canvasView,
            textureLayersState: viewModel.textureLayersState
        )
    }()

    private lazy var canvasView: TextureLayerCanvasView = {
        TextureLayerCanvasView(
            textureLayersState: viewModel.textureLayersState,
            device: sharedDevice,
            configuration: configuration.canvasConfiguration
        )
    }()

    private lazy var textureLayerView: TextureLayerView = {
        TextureLayerView(
            viewModel: UndoTextureLayerViewModel(
                textureLayers: viewModel.textureLayersState,
                device: canvasView.sharedDevice,
                commandQueue: canvasView.sharedCommandQueue,
                onLayersChanged: onTextureLayersChanged,
                onRegisterUndo: { [weak self] undoObjectPair in
                    self?.undoCoordinator.registerUndo(undoObjectPair)
                }
            )
        )
    }()

    private let drawingRenderers: [DrawingToolType: any DrawingRenderer] = [
        .brush: BrushDrawingRenderer(),
        .eraser: EraserDrawingRenderer()
    ]

    private let viewModel = HandDrawingViewModel()

    override func viewDidLoad() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device.")
        }
        super.viewDidLoad()
        view.backgroundColor = .white

        sharedDevice = defaultDevice
        addEvents()
        bindData()
        layoutViews()
        setupNewCanvasDialogPresenter()

        drawingRenderers.forEach {
            $0.value.setup(
                renderer: canvasView.renderer
            )
        }

        viewModel.loadLocalDrawingComponentsData(
            configuration: configuration
        )
        updateDrawingComponents()

        showActivityIndicator(true)
        showContentView(false)

        Task {
            do {
                let textureSize = await viewModel.restoreOrInitializeTextureLayers(
                    device: sharedDevice,
                    fallbackTextureSize: configuration.canvasConfiguration.textureSize,
                    commandQueue: canvasView.sharedCommandQueue
                )

                try await initializeCanvas(textureSize)

                textureLayerView.update(
                    viewModel.textureLayersState
                )

                // Initialize the textures in DrawingRenderer
                for renderer in drawingRenderers.values {
                    renderer.initializeTextures(textureSize)
                }

                showActivityIndicator(false)
                showContentView(true)

                contentView.showCanvasAfterCompletion()

            } catch {
                showActivityIndicator(false)
                showAlert(error)
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Set the undo limit
        canvasView.undoManager?.levelsOfUndo = configuration.undoCount

        undoCoordinator.setUndoManager(canvasView.undoManager)
    }

    func newCanvas() async throws {
        try await viewModel.onNewCanvas(
            device: sharedDevice,
            commandQueue: canvasView.sharedCommandQueue
        )
        try await initializeCanvas(viewModel.textureSize)
        canvasView.resetTransforming()
    }

    func saveFiles(to workingDirectoryURL: URL) async throws {
        try await viewModel.onSaveFiles(
            thumbnail: canvasView.thumbnail,
            to: workingDirectoryURL
        )
    }

    func loadFiles(in workingDirectoryURL: URL) async throws {
        try await viewModel.onLoadFiles(
            device: canvasView.sharedDevice,
            from: workingDirectoryURL
        )
        try await initializeCanvas(viewModel.textureSize)
    }
}

private extension HandDrawingViewController {
    /// Handler that responds to texture layer events and updates the canvas view accordingly.
    var onTextureLayersChanged: (TextureLayerEvent) -> Void {
        { [weak self] event in
            switch event {
            case .addLayer, .removeLayer, .selectLayer, .changeVisibility, .moveLayer:
                Task { [weak self] in
                    try? await self?.canvasView.updateFullCanvasTexture()
                }
                // Update the alpha UI to match the currently selected layer.
                // changeLayerAlpha is excluded because the slider already reflects that change.
                if let alpha = self?.viewModel.textureLayersState.selectedLayer?.alpha {
                    self?.textureLayerView.updateAlpha(alpha)
                }
            case .changeLayerAlpha:
                Task { [weak self] in
                    self?.canvasView.updateCanvasTextureUsingCurrentTexture()
                }
            }
        }
    }

    func initializeCanvas(_ textureSize: CGSize) async throws {

        try await canvasView.initializeCanvas(textureSize)

        // Initialize the textures used for Undo
        await undoCoordinator.initializeDrawingUndoTextures(
            textureSize
        )
    }

    func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = {
            Task { [weak self] in
                guard let `self` else { return }

                defer { self.showActivityIndicator(false) }
                self.showActivityIndicator(true)

                do {
                    try await self.newCanvas()

                    self.viewModel.resetCoreData()

                    self.updateDrawingComponents()

                } catch {
                    self.showAlert(error)
                }
            }
        }
    }

    func bindData() {
        canvasView.strokeEvents
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .fingerStrokeBegan, .pencilStrokeBegan:
                    self?.enableComponentsInteraction(false)
                case .strokeCompleted, .strokeCancelled:
                    self?.enableComponentsInteraction(true)
                }

                self?.undoCoordinator.registerDrawingUndoAfterCompletion(event)
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

        undoCoordinator.didChangeUndoState
            .sink { [weak self] in
                guard
                    let undoManager = self?.undoCoordinator.undoManager
                else { return }
                self?.contentView.setUndoRedoButtonState(
                    .init(undoManager)
                )
                if let alpha = self?.viewModel.textureLayersState.selectedLayer?.alpha {
                    self?.textureLayerView.updateAlpha(alpha)
                }
            }
            .store(in: &cancellables)
    }

    func addEvents() {
        contentView.tapResetTransforming = { [weak self] in
            self?.canvasView.resetTransforming()
        }
        contentView.tapLayerButton = { [weak self] in
            guard let `self` else { return }
            self.textureLayerPresenter.toggleView()
            self.textureLayerPopup?.view.isHidden = self.textureLayerPresenter.isHidden
        }
        contentView.tapSaveButton = { [weak self] in
            self?.saveCanvas()
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
            guard let `self` else { return }
            self.viewModel.toggleDrawingTool()

            self.contentView.updateDrawingComponents(viewModel.drawingTool.type)

            guard let renderer = self.drawingRenderers[self.viewModel.drawingTool.type] else { return }
            self.canvasView.setDrawingRenderer(renderer)
        }
        contentView.tapUndoButton = { [weak self] in
            self?.undoCoordinator.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.undoCoordinator.redo()
        }

        contentView.dragBrushSlider = { [weak self] value in
            self?.viewModel.drawingTool.brushDiameter = BrushDrawingRenderer.diameterIntValue(value)
        }
        contentView.dragEraserSlider = { [weak self] value in
            self?.viewModel.drawingTool.eraserDiameter = EraserDrawingRenderer.diameterIntValue(value)
        }
    }

    func layoutViews() {
        if let baseView = contentView.baseView {
            baseView.addSubview(canvasView)
            canvasView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                canvasView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
                canvasView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
                canvasView.topAnchor.constraint(equalTo: baseView.topAnchor),
                canvasView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor)
            ])

            let popupView = PopupPresenterView(presenter: textureLayerPresenter) { [weak self] in
                if let view = self?.textureLayerView {
                    AnyView(view)
                } else {
                    AnyView(EmptyView())
                }
            }
            popupView.presenter.arrowX(
                contentView.layerButton,
                to: contentView,
                dialogWidth: 300
            )

            textureLayerPopup = UIHostingController(rootView: AnyView(popupView))
            textureLayerPopup?.view.backgroundColor = .white

            if let popup = textureLayerPopup {
                baseView.addSubview(popup.view)
  
                popup.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    popup.view.topAnchor.constraint(equalTo: contentView.layerButton.bottomAnchor),
                    popup.view.centerXAnchor.constraint(equalTo: contentView.layerButton.centerXAnchor),
                    popup.view.widthAnchor.constraint(equalToConstant: 300),
                    popup.view.heightAnchor.constraint(equalToConstant: 300)
                ])
            }
            textureLayerPopup?.view.isHidden = textureLayerPresenter.isHidden
        }

        addBrushPalette()
        addEraserPalette()
    }

    func addBrushPalette() {
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

    func addEraserPalette() {
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

    func updateDrawingComponents() {
        (drawingRenderers[.brush] as? BrushDrawingRenderer)?.setDiameter(viewModel.drawingTool.brushDiameter)
        (drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setDiameter(viewModel.drawingTool.eraserDiameter)

        contentView.setBrushDiameterSlider(viewModel.drawingTool.brushDiameter)
        contentView.setEraserDiameterSlider(viewModel.drawingTool.eraserDiameter)

        contentView.updateDrawingComponents(viewModel.drawingTool.type)

        if let renderer = drawingRenderers[viewModel.drawingTool.type] {
            canvasView.setDrawingRenderer(renderer)
        }
    }
}

private extension HandDrawingViewController {
    func showFileView() {
        let fileView = FileView(
            list: viewModel.fileList,
            onTapItem: { [weak self] zipFileURL in
                self?.presentedViewController?.dismiss(animated: true)
                self?.loadCanvas(zipFileURL: zipFileURL)
            }
        )

        let vc = UIHostingController(rootView: fileView)

        present(vc, animated: true)
    }

    func showAlert(_ error: CanvasError) {
        dialogPresenter.configuration = .init(
            title: error.title,
            message: error.message
        )
        dialogPresenter.presentAlert(on: self)
    }

    func showAlert(_ error: Error) {
        dialogPresenter.configuration = .init(
            title: "Error",
            message: error.localizedDescription
        )
        dialogPresenter.presentAlert(on: self)
    }

    func showToast(_ model: ToastMessage) {
        let toast = Toast()
        toast.showMessage(model)
        view.addSubview(toast)
    }

    func showActivityIndicator(_ isShown: Bool) {
        activityIndicatorView.isHidden = !isShown
    }

    func showContentView(_ isShown: Bool) {
        contentView.isHidden = !isShown
    }

    func enableComponentsInteraction(_ isUserInteractionEnabled: Bool) {
        contentView.enableComponentsInteraction(isUserInteractionEnabled)
        textureLayerPresenter.enableComponentInteraction(isUserInteractionEnabled)
    }
}

private extension HandDrawingViewController {

    func loadCanvas(zipFileURL: URL) {
        self.viewModel.onLoadCanvas(
            zipFileURL: zipFileURL,
            action: { [weak self] workingDirectoryURL in
                try await self?.loadFiles(
                    in: workingDirectoryURL
                )
            },
            completion: { [weak self] in
                self?.updateDrawingComponents()
            }
        )
    }
    func saveCanvas() {
        viewModel.onSaveCanvas(
            saveCanvasAction: { [weak self] tmpWorkingDirectoryURL in
                try await self?.saveFiles(
                    to: tmpWorkingDirectoryURL
                )
            },
            completion: { [weak self] in
                guard
                    let `self`,
                    let thumbnail = self.canvasView.thumbnail
                else { return }
                self.viewModel.upsertFileList(
                    self.viewModel.currentFile(thumbnail: thumbnail)
                )
            },
            zipFileURL: zipFileURL
        )
    }

    func saveImage() {
        if let image = canvasView.canvasTexture?.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        }
    }
    @objc func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
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
