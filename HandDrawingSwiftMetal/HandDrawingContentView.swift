//
//  HandDrawingContentView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/03/09.
//

import CanvasView
import UIKit
import Combine

final class HandDrawingContentView: UIView {

    @IBOutlet private(set) weak var canvasView: CanvasView!

    @IBOutlet private weak var resetTransformButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    @IBOutlet private weak var loadButton: UIButton!
    @IBOutlet private weak var newButton: UIButton!

    @IBOutlet private weak var brushDiameterSlider: UISlider!
    @IBOutlet private weak var eraserDiameterSlider: UISlider!

    @IBOutlet private(set) weak var exportImageButton: UIButton!
    @IBOutlet private(set) weak var layerButton: UIButton!

    @IBOutlet weak var drawingToolButton: UIButton!

    @IBOutlet weak var brushPaletteView: UIView!
    @IBOutlet weak var eraserPaletteView: UIView!
    
    @IBOutlet weak var undoButton: UIButton!
    @IBOutlet weak var redoButton: UIButton!

    var tapSaveButton: (() -> Void)?
    var tapLayerButton: (() -> Void)?
    var tapLoadButton: (() -> Void)?
    var tapExportImageButton: (() -> Void)?
    var tapNewButton: (() -> Void)?

    let brushDrawingToolRenderer = BrushDrawingToolRenderer()
    let eraserDrawingToolRenderer = EraserDrawingToolRenderer()

    let viewModel = HandDrawingContentViewModel()

    lazy var drawingToolLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<DrawingToolArchiveModel>(
                fileName: DrawingToolArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.drawingToolStorage.setDrawingTool(.init(rawValue: file.type))
                    self?.viewModel.drawingToolStorage.setBrushDiameter(file.brushDiameter)
                    self?.viewModel.drawingToolStorage.setEraserDiameter(file.eraserDiameter)
                }
            }
         )
    }()

    lazy var brushPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<BrushPaletteArchiveModel>(
                fileName: BrushPaletteArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.brushPaletteStorage.update(
                        colors: file.hexColors.compactMap { UIColor(hex: $0) },
                        index: file.index
                    )
                }
            }
         )
    }()

    lazy var eraserPaletteLoader: AnyLocalFileLoader = {
         AnyLocalFileLoader(
            LocalFileNamedLoader<EraserPaletteArchiveModel>(
                fileName: EraserPaletteArchiveModel.jsonFileName
            ) { [weak self] file in
                Task { @MainActor [weak self] in
                    self?.viewModel.eraserPaletteStorage.update(
                        alphas: file.alphas,
                        index: file.index
                    )
                }
            }
         )
    }()

    private var cancellables = Set<AnyCancellable>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        instantiateNib()
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        instantiateNib()
        commonInit()
    }

    private func commonInit() {
        canvasView.alpha = 0.0

        subscribe()
        addEvents()

        brushDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))
        eraserDiameterSlider.transform = CGAffineTransform(rotationAngle: CGFloat(-Double.pi / 2.0))

        updateDrawingComponents(
            viewModel.drawingToolStorage.type
        )
    }

    func initialize() {
        brushDrawingToolRenderer.setDiameter(viewModel.drawingToolStorage.brushDiameter)
        brushDiameterSlider.setValue(
            BrushDrawingToolRenderer.diameterFloatValue(viewModel.drawingToolStorage.brushDiameter),
            animated: false
        )

        eraserDrawingToolRenderer.setDiameter(viewModel.drawingToolStorage.eraserDiameter)
        eraserDiameterSlider.setValue(
            EraserDrawingToolRenderer.diameterFloatValue(viewModel.drawingToolStorage.eraserDiameter),
            animated: false
        )

        updateDrawingComponents(viewModel.drawingToolStorage.type)

        UIView.animate(withDuration: 0.1) { [weak self] in
            self?.canvasView.alpha = 1.0
        }

        backgroundColor = .white
    }

    func setUndoRedoButtonState(_ state: UndoRedoButtonState) {
        undoButton.isEnabled = state.isUndoEnabled
        redoButton.isEnabled = state.isRedoEnabled
    }
}

private extension HandDrawingContentView {

    func subscribe() {
        viewModel.brushPaletteStorage.palette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.brushPaletteStorage.palette.colors.count else { return }
                let newColor = viewModel.brushPaletteStorage.palette.colors[index]
                self.brushDrawingToolRenderer.setColor(newColor)
            }
            .store(in: &cancellables)

        viewModel.eraserPaletteStorage.palette.$index
            .sink { [weak self] index in
                guard let `self`, index < viewModel.eraserPaletteStorage.palette.alphas.count else { return }
                let newAlpha = viewModel.eraserPaletteStorage.palette.alphas[index]
                self.eraserDrawingToolRenderer.setAlpha(newAlpha)
            }
            .store(in: &cancellables)

        viewModel.drawingToolStorage.drawingTool.$brushDiameter
            .sink { [weak self] diameter in
                self?.brushDrawingToolRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)

        viewModel.drawingToolStorage.drawingTool.$eraserDiameter
            .sink { [weak self] diameter in
                self?.eraserDrawingToolRenderer.setDiameter(diameter)
            }
            .store(in: &cancellables)
    }

    func changeDrawingTool() {
        viewModel.changeDrawingTool()
        updateDrawingComponents(viewModel.drawingToolStorage.type)
    }

    func addEvents() {

        resetTransformButton.addAction(.init { [weak self] _ in
            self?.canvasView.resetTransforming()
        }, for: .touchUpInside)

        saveButton.addAction(.init { [weak self] _ in
            self?.tapSaveButton?()
        }, for: .touchUpInside)

        layerButton.addAction(.init { [weak self] _ in
            self?.tapLayerButton?()
        }, for: .touchUpInside)

        loadButton.addAction(.init { [weak self] _ in
            self?.tapLoadButton?()
        }, for: .touchUpInside)

        exportImageButton.addAction(.init { [weak self] _ in
            self?.tapExportImageButton?()
        }, for: .touchUpInside)

        newButton.addAction(.init { [weak self] _ in
            self?.tapNewButton?()
        }, for: .touchUpInside)

        drawingToolButton.addAction(.init { [weak self] _ in
            self?.changeDrawingTool()
        }, for: .touchUpInside)

        undoButton.addAction(.init { [weak self] _ in
            self?.canvasView.undo()
        }, for: .touchUpInside)

        redoButton.addAction(.init { [weak self] _ in
            self?.canvasView.redo()
        }, for: .touchUpInside)

        brushDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.viewModel.drawingToolStorage.setBrushDiameter(
                BrushDrawingToolRenderer.diameterIntValue(slider.value)
            )
        }, for: .valueChanged)

        eraserDiameterSlider.addAction(UIAction { [weak self] action in
            guard let slider = action.sender as? UISlider else { return }
            self?.viewModel.drawingToolStorage.setEraserDiameter(
                BrushDrawingToolRenderer.diameterIntValue(slider.value)
            )
        }, for: .valueChanged)
    }

    func updateDrawingComponents(_ tool: DrawingToolType) {
        if tool == .brush {
            drawingToolButton.setImage(.init(systemName: "pencil"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.brush.rawValue)

        } else {
            drawingToolButton.setImage(.init(systemName: "eraser"), for: .normal)
            canvasView.setDrawingTool(DrawingToolType.eraser.rawValue)
        }

        brushDiameterSlider.isHidden = tool != .brush
        brushPaletteView.isHidden = tool != .brush

        eraserDiameterSlider.isHidden = tool != .eraser
        eraserPaletteView.isHidden = tool != .eraser

        canvasView.setDrawingTool(tool.rawValue)
    }
}
