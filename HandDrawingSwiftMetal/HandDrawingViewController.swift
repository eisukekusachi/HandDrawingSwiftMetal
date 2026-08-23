//
//  HandDrawingViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import CanvasView
import Combine
import PaletteEditView
import PaletteView
import PopupView
import SwiftUI
import TextureLayerCanvasView
import TextureLayerView
import UIKit

@preconcurrency import MetalKit

class HandDrawingViewController: UIViewController {

    @IBOutlet private weak var contentView: HandDrawingContentView!

    @IBOutlet private weak var activityIndicatorView: UIView!

    private var configuration: ProjectConfiguration = .init(canvasConfiguration: .init())

    private let dialogPresenter = DialogPresenter()

    private var textureLayerViewModel = PopupViewModel()
    private var colorPaletteEditPopupViewModel = PopupViewModel()
    private var alphaPaletteEditPopupViewModel = PopupViewModel()

    private weak var popupPassthroughView: PassthroughHostingView?

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
            ),
            onClose: { [weak self] in
                self?.textureLayerViewModel.hide()
            }
        )
    }()

    private let drawingRenderers: [DrawingToolType: any HighPrecisionDrawingRenderer] = [
        .brush: BrushDrawingRenderer(),
        .eraser: EraserDrawingRenderer()
    ]

    private lazy var colorPaletteEditViewModel = ColorPaletteEditViewModel(
        colorSource: viewModel.brushPalette,
        onChanged: { [weak self] color in
            guard let `self` else { return }
            self.viewModel.brushPalette.update(
                color: color,
                at: self.viewModel.brushPalette.selectedIndex
            )
            (self.drawingRenderers[.brush] as? BrushDrawingRenderer)?.setColor(color)
        }
    )

    private lazy var alphaPaletteEditViewModel = AlphaPaletteEditViewModel(
        alphaSource: viewModel.eraserPalette,
        onChanged: { [weak self] alpha in
            guard let `self` else { return }
            self.viewModel.eraserPalette.update(
                alpha: alpha,
                at: self.viewModel.eraserPalette.selectedIndex
            )
            (self.drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setAlpha(alpha)
        }
    )

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        popupPassthroughView?.syncPopupLayout()
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

    func bindData() {
        Publishers.CombineLatest(
            canvasView.strokeLifecyclePhase.map(\.isActive),
            canvasView.transformLifecyclePhase.map(\.isActive)
        )
        .map { isStrokeActive, isTransformActive in
            isStrokeActive || isTransformActive
        }
        .removeDuplicates()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] shouldLockUI in
            self?.enableComponentsInteraction(!shouldLockUI)
        }
        .store(in: &cancellables)

        canvasView.strokeLifecyclePhase
            .scan((StrokeLifecycle.idle, StrokeLifecycle.idle)) { previous, current in
                (previous.1, current)
            }
            .sink { [weak self] previous, current in
                if previous == .idle, current == .drawing {
                    Task {
                        await self?.undoCoordinator.setUndoDrawingBeforeStroke()
                    }
                }
            }
            .store(in: &cancellables)

        canvasView.strokeSessionDidCommit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                Task {
                    do {
                        try await self?.undoCoordinator.registerDrawingUndoAfterCommit()
                    } catch {
                        Logger.error(error)
                    }
                }
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

        viewModel.brushPalette.$selectedIndex
            .sink { [weak self] index in
                guard let `self`, let newColor = viewModel.brushPalette.color(at: index) else { return }
                (self.drawingRenderers[.brush] as? BrushDrawingRenderer)?.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPalette.$selectedIndex
            .sink { [weak self] index in
                guard let `self`, let newAlpha = viewModel.eraserPalette.alpha(at: index) else { return }
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
            if self.textureLayerViewModel.isHidden {
                self.colorPaletteEditPopupViewModel.hide()
                self.alphaPaletteEditPopupViewModel.hide()
                self.textureLayerViewModel.show()
            } else {
                self.textureLayerViewModel.hide()
            }
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
        contentView.tapDrawingToolButton = { [weak self] in
            guard let `self` else { return }
            let wasPaletteEditPopupVisible =
                !self.colorPaletteEditPopupViewModel.isHidden ||
                !self.alphaPaletteEditPopupViewModel.isHidden

            self.viewModel.toggleDrawingTool()
            self.contentView.updateDrawingComponents(self.viewModel.drawingTool.type)

            guard let renderer = self.drawingRenderers[self.viewModel.drawingTool.type] else { return }
            self.canvasView.setDrawingRenderer(renderer)
            self.updatePalettePopupOnToolSwitch(wasVisible: wasPaletteEditPopupVisible)
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
        guard let baseView = contentView.baseView else { return }

        baseView.addSubview(canvasView)
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor),
            canvasView.topAnchor.constraint(equalTo: baseView.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor)
        ])

        addBrushPalette()
        addEraserPalette()
        addOverlayHostingView()

        contentView.layoutIfNeeded()
    }

    func addBrushPalette() {
        let hostingController = UIHostingController(
            rootView: ColorPaletteView(
                palette: viewModel.brushPalette,
                paletteHeight: paletteHeight
            ) { [weak self] index, didReselect in
                guard let `self`, didReselect else { return }
                if self.colorPaletteEditPopupViewModel.isHidden {
                    self.showColorPalettePopup(selectedIndex: index)
                } else {
                    self.colorPaletteEditPopupViewModel.hide()
                }
            }
        )
        embedHostingController(hostingController, in: contentView.brushPaletteView)
    }

    func addEraserPalette() {
        let hostingController = UIHostingController(
            rootView: AlphaPaletteView(
                palette: viewModel.eraserPalette,
                paletteHeight: paletteHeight
            ) { [weak self] index, didReselect in
                guard let `self`, didReselect else { return }
                if self.alphaPaletteEditPopupViewModel.isHidden {
                    self.showAlphaPalettePopup(selectedIndex: index)
                } else {
                    self.alphaPaletteEditPopupViewModel.hide()
                }
            }
        )
        embedHostingController(hostingController, in: contentView.eraserPaletteView)
    }

    func addOverlayHostingView() {
        let targetView: HandDrawingContentView = contentView

        let bindings: [PopupAnchorBinding] = [
            .init(
                target: targetView.layerButton,
                viewModel: textureLayerViewModel,
                placement: .belowAnchor,
                content: {
                    textureLayerView
                        .frame(height: 300)
                }
            ),
            .init(
                target: targetView.brushPaletteView,
                viewModel: colorPaletteEditPopupViewModel,
                placement: .aboveAnchor,
                onClose: { [weak self] in
                    self?.colorPaletteEditPopupViewModel.hide()
                },
                content: {
                    ColorPaletteEditView(
                        viewModel: colorPaletteEditViewModel,
                        onRemove: { [weak self] in
                            guard let `self` else { return }
                            self.viewModel.brushPalette.removeSelected()
                            if let color = self.viewModel.brushPalette.color {
                                (self.drawingRenderers[.brush] as? BrushDrawingRenderer)?.setColor(color)
                            }
                        },
                        onDuplicate: { [weak self] in
                            self?.viewModel.brushPalette.duplicateSelected()
                        }
                    )
                }
            ),
            .init(
                target: targetView.eraserPaletteView,
                viewModel: alphaPaletteEditPopupViewModel,
                placement: .aboveAnchor,
                onClose: { [weak self] in
                    self?.alphaPaletteEditPopupViewModel.hide()
                },
                content: {
                    AlphaPaletteEditView(
                        viewModel: alphaPaletteEditViewModel,
                        onRemove: { [weak self] in
                            guard let `self` else { return }
                            self.viewModel.eraserPalette.removeSelected()
                            if let alpha = self.viewModel.eraserPalette.alpha {
                                (self.drawingRenderers[.eraser] as? EraserDrawingRenderer)?.setAlpha(alpha)
                            }
                        },
                        onDuplicate: { [weak self] in
                            self?.viewModel.eraserPalette.duplicateSelected()
                        }
                    )
                }
            )
        ]

        let passthroughHostingView = PassthroughHostingView()
        passthroughHostingView.translatesAutoresizingMaskIntoConstraints = false
        targetView.addSubview(passthroughHostingView)
        targetView.bringSubviewToFront(passthroughHostingView)

        // HandDrawingContentView.xib lays out popup anchors (layer button, palettes, etc.)
        // against the safe area, so the overlay must use the same guide for correct popup placement.
        let safeAreaTargetView = targetView.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            passthroughHostingView.leadingAnchor.constraint(equalTo: safeAreaTargetView.leadingAnchor),
            passthroughHostingView.trailingAnchor.constraint(equalTo: safeAreaTargetView.trailingAnchor),
            passthroughHostingView.topAnchor.constraint(equalTo: safeAreaTargetView.topAnchor),
            passthroughHostingView.bottomAnchor.constraint(equalTo: safeAreaTargetView.bottomAnchor)
        ])

        let hostingController = UIHostingController(
            rootView: HandDrawingPopupOverlayContentView(bindings: bindings)
        )
        hostingController.view.isOpaque = false
        embedHostingController(hostingController, in: passthroughHostingView)

        passthroughHostingView.hostingView = hostingController.view
        passthroughHostingView.anchorBindings = bindings
        popupPassthroughView = passthroughHostingView
    }

    func updatePalettePopupOnToolSwitch(wasVisible: Bool) {
        guard wasVisible else { return }
        switch viewModel.drawingTool.type {
        case .brush:
            showColorPalettePopup(
                selectedIndex: viewModel.brushPalette.selectedIndex,
                immediately: true
            )
        case .eraser:
            showAlphaPalettePopup(
                selectedIndex: viewModel.eraserPalette.selectedIndex,
                immediately: true
            )
        }
    }

    func showColorPalettePopup(selectedIndex: Int, immediately: Bool = false) {
        alphaPaletteEditPopupViewModel.hide()
        textureLayerViewModel.hide()
        viewModel.brushPalette.select(selectedIndex)
        colorPaletteEditPopupViewModel.bringToFront()
        colorPaletteEditPopupViewModel.show(immediately: immediately)
    }

    func showAlphaPalettePopup(selectedIndex: Int, immediately: Bool = false) {
        colorPaletteEditPopupViewModel.hide()
        textureLayerViewModel.hide()
        viewModel.eraserPalette.select(selectedIndex)
        alphaPaletteEditPopupViewModel.bringToFront()
        alphaPaletteEditPopupViewModel.show(immediately: immediately)
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

    func embedHostingController<Content: View>(
        _ hostingController: UIHostingController<Content>,
        in containerView: UIView
    ) {
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    func showFileView() {
        let fileView = FileView(
            fileCoordinator: viewModel.fileCoordinator,
            currentOpenFileURL: viewModel.zipFileURL,
            selectedFileURL: viewModel.zipFileURL,
            createAction: { [weak self] name in
                guard let `self` else { return }
                let zipFileURL = try await self.viewModel.createNewCanvas(
                    fileName: name,
                    device: self.sharedDevice,
                    commandQueue: self.canvasView.sharedCommandQueue
                )
                self.loadCanvas(zipFileURL: zipFileURL)
                self.presentedViewController?.dismiss(animated: true)
            },
            renameAction: { [weak self] index, newName in
                guard let `self` else {
                    throw NSError(
                        title: String(localized: "Error"),
                        message: String(localized: "Invalid Value")
                    )
                }
                return try self.viewModel.renameCanvas(
                    index: index,
                    newName: newName,
                    currentOpenFileURL: self.viewModel.zipFileURL
                )
            },
            deleteAction: { [weak self] index in
                guard let `self` else { return }
                try self.viewModel.deleteCanvas(
                    index: index,
                    currentOpenFileURL: self.viewModel.zipFileURL
                )
            },
            selectAction: { [weak self] zipFileURL in
                guard let `self` else { return }
                self.loadCanvas(zipFileURL: zipFileURL)
                self.presentedViewController?.dismiss(animated: true)
            }
        )

        let vc = UIHostingController(rootView: fileView)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

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
        popupPassthroughView?.enablePopupInteraction(isUserInteractionEnabled)
    }
}

private extension HandDrawingViewController {

    func loadCanvas(zipFileURL: URL) {
        self.viewModel.loadCanvas(
            device: sharedDevice,
            zipFileURL: zipFileURL,
            completion: { [weak self] in
                guard let `self` else { return }
                Task {
                    do {
                        try await self.initializeCanvas(self.viewModel.textureSize)
                        self.updateDrawingComponents()
                    } catch {
                        self.showAlert(error)
                    }
                }
            }
        )
    }

    func saveCanvas() {
        viewModel.saveCanvas(
            thumbnail: canvasView.thumbnail,
            completion: { [weak self] in
                guard
                    let `self`,
                    let thumbnail = self.canvasView.thumbnail
                else { return }

                self.viewModel.upsertFileList(
                    self.viewModel.currentFileItem(
                        thumbnail: thumbnail
                    )
                )
                self.viewModel.sortFileList()
            },
            zipFileURL: viewModel.zipFileURL
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
