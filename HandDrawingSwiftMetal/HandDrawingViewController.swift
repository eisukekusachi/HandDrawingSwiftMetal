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

    private let viewModel = HandDrawingContentViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        addEvents()
        bindData()

        addBrushPalette()
        addEraserPalette()

        brushDrawingRenderer.setDiameter(viewModel.drawingToolStorage.brushDiameter)
        eraserDrawingRenderer.setDiameter(viewModel.drawingToolStorage.eraserDiameter)

        initializeNewCanvasDialogPresenter()

        view.backgroundColor = .white
        showActivityIndicator(true)
        showContentView(false)

        Task {
            do {
                try await contentView.canvasView.setup(
                    drawingRenderers: [
                        brushDrawingRenderer,
                        eraserDrawingRenderer
                    ],
                    configuration: canvasConfiguration ?? .init()
                )

                updateComponents()

                showActivityIndicator(false)
                showContentView(true)

            } catch {
                fatalError("Failed to initialize the canvas")
            }
        }
    }
}

extension HandDrawingViewController {

    private func bindData() {

        contentView.canvasView.didInitializeCanvasView
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.contentView.initialize()
            }
            .store(in: &cancellables)

        contentView.canvasView.didInitializeTextures
            .receive(on: DispatchQueue.main)
            .sink { [weak self] textureLayers in
                self?.initializeLayerView(textureLayers)
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

        viewModel.drawingToolStorage.drawingTool.$brushDiameter
            .sink { [weak self] diameter in
                self?.brushDrawingRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)

        viewModel.drawingToolStorage.drawingTool.$eraserDiameter
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
            contentView.updateDrawingComponents(viewModel.drawingToolStorage.type)
        }
        contentView.tapUndoButton = { [weak self] in
            self?.contentView.undo()
        }
        contentView.tapRedoButton = { [weak self] in
            self?.contentView.redo()
        }

        contentView.dragBrushSlider = { [weak self] value in
            self?.viewModel.drawingToolStorage.setBrushDiameter(
                BrushDrawingRenderer.diameterIntValue(value)
            )
        }
        contentView.dragEraserSlider = { [weak self] value in
            self?.viewModel.drawingToolStorage.setEraserDiameter(
                EraserDrawingRenderer.diameterIntValue(value)
            )
        }
    }
}

extension HandDrawingViewController {

    private func initializeNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let `self` else { return }

            Task {
                defer { self.viewModel.showActivityIndicator(false) }
                self.viewModel.showActivityIndicator(true)

                self.viewModel.drawingToolStorage.update(
                    type: .brush,
                    brushDiameter: 8,
                    eraserDiameter: 8
                )
                self.viewModel.brushPaletteStorage.update(
                    colors: self.viewModel.initializeColors,
                    index: 0
                )
                self.viewModel.eraserPaletteStorage.update(
                    alphas: self.viewModel.initializeAlphas,
                    index: 0
                )

                let scale = UIScreen.main.scale
                let size = UIScreen.main.bounds.size
                try await self.contentView.canvasView.newCanvas(
                    configuration: TextureLayerArrayConfiguration(
                        textureSize: .init(width: size.width * scale, height: size.height * scale)
                    )
                )

                self.updateComponents()
            }
        }
    }

    private func initializeLayerView(_ textureLayers: any TextureLayersProtocol) {
        textureLayerViewPresenter.initialize(
            textureLayers: textureLayers,
            popupConfiguration: .init(
                anchorButton: contentView.layerButton,
                destinationView: contentView,
                size: .init(
                    width: 300,
                    height: 300
                )
            )
        )
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
        contentView.updateDrawingComponents(viewModel.drawingToolStorage.drawingTool.type)
        contentView.setBrushDiameterSlider(viewModel.drawingToolStorage.brushDiameter)
        contentView.setEraserDiameterSlider(viewModel.drawingToolStorage.eraserDiameter)
    }

    private func showFileView() {
        let fileView = FileView(
            targetURL: URL.documents,
            suffix: ProjectMetaData.fileSuffix,
            onTapItem: { [weak self] zipFileURL in
                guard let `self` else { return }
                self.presentedViewController?.dismiss(animated: true)
                self.textureLayerViewPresenter.hide()

                self.loadProject(zipFileURL: zipFileURL)
            }
        )
        present(
            UIHostingController(rootView: fileView),
            animated: true
        )
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
            zipFileURL: self.contentView.canvasView.zipFileURL
        )
    }

    private func saveImage() {
        if let image = contentView.canvasView.displayTexture?.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        }
    }
    @objc private func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            showToast(
                .init(
                    title: "Failed",
                    icon: UIImage(systemName: "exclamationmark.circle")
                )
            )
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
        canvasConfiguration: CanvasConfiguration? = nil
    ) -> Self {
        let viewController = Self()
        viewController.canvasConfiguration = canvasConfiguration
        return viewController
    }
}
