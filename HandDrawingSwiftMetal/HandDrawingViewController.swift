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

    private let brushDrawingRenderer = BrushDrawingRenderer()
    private let eraserDrawingRenderer = EraserDrawingRenderer()

    private let viewModel = HandDrawingViewModel()

    public var zipFileURL: URL {
        FileManager.documentsFileURL(
            projectName: viewModel.projectStorage.projectName,
            suffix: viewModel.fileSuffix
        )
    }

    var currentLocalFileItem: LocalFileItem {
        .init(
            title: viewModel.projectStorage.projectName,
            createdAt: viewModel.projectStorage.createdAt,
            updatedAt: viewModel.projectStorage.updatedAt,
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
            guard let `self` else { return }

            defer {
                self.showActivityIndicator(false)
                self.showContentView(true)
            }
            do {
                let configuration: CanvasConfiguration = self.canvasConfiguration ?? .init()

                try await contentView.canvasView.setup(
                    drawingRenderers: [
                        self.brushDrawingRenderer,
                        self.eraserDrawingRenderer
                    ],
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
                    let textureSize = canvasView.currentTextureSize

                    try await canvasView.newCanvas(
                        textureSize: textureSize
                    )
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
        contentView.canvasView.isDrawing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isDrawing in
                // Disable the components during the drawing
                self?.enableComponentsInteraction(!isDrawing)
            }
            .store(in: &cancellables)

        contentView.canvasView.setupCompletion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.textureLayerViewPresenter.update(
                    textureLayers: result.textureLayers
                )
                self?.contentView.initialize()
            }
            .store(in: &cancellables)

        contentView.canvasView.drawingCompletion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                // Update the project's updatedAt value to the current time
                self?.viewModel.projectStorage.update(
                    updatedAt: Date()
                )
            }
            .store(in: &cancellables)

        contentView.canvasView.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(error)
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

        viewModel.brushPaletteStorage.palette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.brushPaletteStorage.palette.colors.count else { return }
                let newColor = viewModel.brushPaletteStorage.palette.colors[index]
                self.brushDrawingRenderer.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPaletteStorage.palette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.eraserPaletteStorage.palette.alphas.count else { return }
                let newAlpha = viewModel.eraserPaletteStorage.palette.alphas[index]
                self.eraserDrawingRenderer.setAlpha(newAlpha)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$brushDiameter
            .sink { [weak self] diameter in
                self?.brushDrawingRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)

        viewModel.drawingTool.$eraserDiameter
            .sink { [weak self] diameter in
                self?.eraserDrawingRenderer.setDiameter(diameter)
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
            guard let `self` else { return }
            viewModel.toggleDrawingTool()
            contentView.updateDrawingComponents(viewModel.drawingTool.type)
        }
        contentView.tapUndoButton = { [weak self] in
            self?.contentView.canvasView.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.contentView.canvasView.redo()
        }

        contentView.dragBrushSlider = { [weak self] value in
            self?.viewModel.drawingTool.setBrushDiameter(
                BrushDrawingRenderer.diameterIntValue(value)
            )
        }
        contentView.dragEraserSlider = { [weak self] value in
            self?.viewModel.drawingTool.setEraserDiameter(
                EraserDrawingRenderer.diameterIntValue(value)
            )
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
                palette: viewModel.brushPaletteStorage.palette,
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
                palette: viewModel.eraserPaletteStorage.palette,
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
        brushDrawingRenderer.setDiameter(viewModel.drawingTool.brushDiameter)
        eraserDrawingRenderer.setDiameter(viewModel.drawingTool.eraserDiameter)
        contentView.updateDrawingComponents(viewModel.drawingTool.type)
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
                try await self?.contentView.canvasView.exportFiles(
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
