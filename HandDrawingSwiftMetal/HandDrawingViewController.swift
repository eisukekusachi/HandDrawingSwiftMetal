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

    private var configuration = ProjectConfiguration()

    private let dialogPresenter = DialogPresenter()
    private let newCanvasDialogPresenter = NewCanvasDialogPresenter()

    private let textureLayerViewPresenter = TextureLayerViewPresenter()

    private var cancellables = Set<AnyCancellable>()

    private let paletteHeight: CGFloat = 44

    override func viewDidLoad() {
        super.viewDidLoad()

        addEvents()
        bindData()

        contentView.canvasView.initialize(
            drawingToolRenderers: [
                contentView.brushDrawingToolRenderer,
                contentView.eraserDrawingToolRenderer
            ],
            canvasConfiguration: .init(
                projectConfiguration: ProjectConfiguration(),
                environmentConfiguration: EnvironmentConfiguration()
            )
        )

        setupNewCanvasDialogPresenter()
        setupLayerView()
    }
}

extension HandDrawingViewController {

    private func bindData() {

        contentView.canvasView.canvasViewSetupCompleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.contentView.setup()
            }
            .store(in: &cancellables)

        contentView.canvasView.activityIndicator
            .map { !$0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isHidden, on: activityIndicatorView)
            .store(in: &cancellables)

        contentView.canvasView.alert
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showAlert(error)
            }
            .store(in: &cancellables)

        contentView.canvasView.toast
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.showToast(model)
            }
            .store(in: &cancellables)

        /*
        contentView.canvasView.didUndo
            .sink { [weak self] state in
                self?.contentView.setUndoRedoButtonState(state)
            }
            .store(in: &cancellables)
        */
    }

    private func addEvents() {
        contentView.tapLayerButton = { [weak self] in
            self?.textureLayerViewPresenter.toggleView()
        }
        contentView.tapSaveButton = { [weak self] in
            guard let `self` else { return }
            self.contentView.canvasView.saveFile(
                additionalItems: [
                    DrawingToolModel.anyNamedItem(from: contentView.viewModel.drawingTool),
                    BrushPaletteModel.anyNamedItem(from: contentView.viewModel.brushPaletteStorage.palette),
                    EraserPaletteModel.anyNamedItem(from: contentView.viewModel.eraserPaletteStorage.palette)
                ]
            )
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
    }
}

extension HandDrawingViewController {

    private func setupNewCanvasDialogPresenter() {
        newCanvasDialogPresenter.onTapButton = { [weak self] in
            guard let `self` else { return }

            self.contentView.viewModel.drawingTool.reset()
            self.contentView.viewModel.brushPaletteStorage.reset()
            self.contentView.viewModel.eraserPaletteStorage.reset()

            let scale = UIScreen.main.scale
            let size = UIScreen.main.bounds.size
            self.contentView.canvasView.newCanvas(
                configuration: ProjectConfiguration(
                    textureSize: .init(width: size.width * scale, height: size.height * scale)
                )
            )
        }
    }

    private func setupLayerView() {
        textureLayerViewPresenter.initialize(
            textureLayerConfiguration: contentView.canvasView.textureLayerConfiguration,
            popupConfiguration: .init(
                anchorButton: contentView.layerButton,
                destinationView: contentView,
                size: .init(
                    width: 300,
                    height: 300
                )
            )
        )

        addBrushPalette()
        addEraserPalette()
    }

    private func addBrushPalette() {
        let targetView: UIView = contentView.brushPaletteView

        let brushPaletteHostingView = UIHostingController(
            rootView: BrushPaletteView(
                palette: contentView.viewModel.brushPaletteStorage.palette,
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
                palette: contentView.viewModel.eraserPaletteStorage.palette,
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

    private func showFileView() {
        let fileView = FileView(
            targetURL: URL.documents,
            suffix: CanvasViewModel.fileSuffix,
            onTapItem: { [weak self] url in
                guard let `self` else { return }

                self.presentedViewController?.dismiss(animated: true)
                self.contentView.canvasView.loadFile(
                    zipFileURL: url,
                    optionalEntities: [
                        self.contentView.drawingToolLoader,
                        self.contentView.brushPaletteLoader,
                        self.contentView.eraserPaletteLoader
                    ]
                )
            }
        )
        present(
            UIHostingController(rootView: fileView),
            animated: true
        )
    }

    private func showAlert(_ error: ErrorModel) {
        dialogPresenter.configuration = .init(
            title: error.title,
            message: error.message
        )
        dialogPresenter.presentAlert(on: self)
    }

    private func showToast(_ model: ToastModel) {
        let toast = Toast()
        toast.setupView(model)
        view.addSubview(toast)
    }
}

extension HandDrawingViewController {

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
        configuration: ProjectConfiguration
    ) -> Self {
        let viewController = Self()
        viewController.configuration = configuration
        return viewController
    }
}
