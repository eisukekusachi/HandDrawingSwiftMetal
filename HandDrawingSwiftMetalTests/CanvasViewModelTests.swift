//
//  CanvasViewModelTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class CanvasViewModelTests: XCTestCase {

    var mockRootTexture: MTLTexture!

    let textureSize = CGSize(width: 100, height: 100)
    let brushDiameter: Int = 5
    let eraserDiameter: Int = 10

    let tmpFolderURL = URL.tmpFolderURL
    let zipFilePath = "zipFilePath.zip"

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    lazy var layers = [
        LayerModel(texture: MTKTextureUtils.makeTexture(device, textureSize), title: "Test0"),
        LayerModel(texture: MTKTextureUtils.makeTexture(device, textureSize), title: "Test1")
    ]
    lazy var codableLayers = [
        LayerModelCodable(textureName: UUID().uuidString, title: "Test0", isVisible: true, alpha: 255),
        LayerModelCodable(textureName: UUID().uuidString, title: "Test1", isVisible: true, alpha: 255)
    ]
    lazy var canvasModelV2 = CanvasModelV2(textureSize: mockRootTexture.size,
                                           layerIndex: 0,
                                           layers: codableLayers,
                                           thumbnailName: URL.thumbnailPath,
                                           drawingTool: DrawingToolType.brush.rawValue,
                                           brushDiameter: brushDiameter,
                                           eraserDiameter: eraserDiameter)

    override func setUp() {
        super.setUp()
        mockRootTexture = MTKTextureUtils.makeTexture(device, textureSize)!
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSaveLoadCanvas() throws {
        // Arrange
        let mockFileIO = MockFileIO()
        let canvasViewModel = CanvasViewModel(fileIO: mockFileIO)
        let layerIndex: Int = 0

        var resultModel: CanvasModelV2?

        // Act
        XCTAssertNoThrow(try canvasViewModel.saveCanvasAsZipFile(rootTexture: mockRootTexture,
                                                                 layerIndex: layerIndex,
                                                                 codableLayers: codableLayers,
                                                                 tmpFolderURL: tmpFolderURL,
                                                                 with: zipFilePath))

        do {
            resultModel = try canvasViewModel.loadCanvasDataV2(from: zipFilePath,
                                                               into: tmpFolderURL)
        } catch {
            XCTFail("Failed to load data")
            return
        }
        guard let resultModel else {
            XCTFail("Failed to unwrap")
            return
        }

        // Assert
        XCTAssertEqual(resultModel.textureSize, mockRootTexture.size)
        XCTAssertEqual(resultModel.layerIndex, layerIndex)
        XCTAssertEqual(resultModel.layers, codableLayers)
    }

    func testApplyData() throws {
        // Arrange
        let mockFileIO = MockFileIO()
        let canvasViewModel = CanvasViewModel(fileIO: mockFileIO)

        // Act
        XCTAssertNoThrow(try canvasViewModel.applyCanvasDataToCanvasV2(canvasModelV2,
                                                                       layers: layers,
                                                                       folderURL: tmpFolderURL,
                                                                       zipFilePath: zipFilePath))

        // Assert
        let index = canvasModelV2.layerIndex
        let selectedLayerAlpha = layers[index].alpha
        XCTAssertEqual(canvasViewModel.layerManager.layers, layers)
        XCTAssertEqual(canvasViewModel.layerManager.index, index)
        XCTAssertEqual(canvasViewModel.layerManager.selectedLayerAlpha, selectedLayerAlpha)
        XCTAssertEqual((canvasViewModel.drawingBrush.tool as? DrawingToolBrush)?.diameter, brushDiameter)
        XCTAssertEqual((canvasViewModel.drawingEraser.tool as? DrawingToolEraser)?.diameter, eraserDiameter)
        XCTAssertEqual(canvasViewModel.drawingTool.rawValue, DrawingToolType.brush.rawValue)
        XCTAssertEqual(canvasViewModel.projectName, zipFilePath.fileName)
    }
}

class MockFileIO: FileIO {
    typealias T = CanvasModelV2

    var resultData: CanvasModelV2?

    func saveJson<T: Codable>(_ data: T, to jsonUrl: URL) throws {
        self.resultData = data as? CanvasModelV2
    }
    func loadJson<T: Codable>(_ url: URL) throws -> T? {
        return resultData as? T
    }

    func saveImage(bytes: [UInt8], to url: URL) throws {}
    func saveImage(image: UIImage?, to url: URL) throws {}
    func zip(_ srcFolderURL: URL, to zipFileURL: URL) throws {}
    func unzip(_ srcZipURL: URL, to destinationURL: URL) throws {}
}
