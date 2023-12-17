//
//  CanvasViewModelTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/12/17.
//

import XCTest
@testable import HandDrawingSwiftMetal

class CanvasViewModelTests: XCTestCase {

    var canvasViewModel: CanvasViewModel!
    var mockFileIO: MockFileIO!
    var mockLayerManager: LayerManager!

    let tmpFolderURL = CanvasViewModel.tmpFolderURL

    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    override func setUp() {
        super.setUp()

        mockFileIO = MockFileIO(textureName: "TextureName", thumbnailName: "ThumnnailName")
        mockLayerManager = MockLayerManager()
        canvasViewModel = CanvasViewModel(fileIO: mockFileIO,
                                          layerManager: mockLayerManager)
    }

    override func tearDown() {
        canvasViewModel = nil
        mockFileIO = nil
        mockLayerManager = nil
        super.tearDown()
    }

    func testSaveCanvas() throws {
        // Arrange
        let zipFilePath = "zipFilePath.zip"
        let mockTexture = LayerManagerImpl.makeTexture(device, CGSize(width: 100, height: 100))!
        let mockTextureFileName = UUID().uuidString

        // Act
        XCTAssertNoThrow(try canvasViewModel.saveCanvasAsZipFile(texture: mockTexture,
                                                                 textureName: mockTextureFileName,
                                                                 into: tmpFolderURL,
                                                                 with: zipFilePath))

        // Assert
        // The image is output as a canvas and its thumbnail, resulting in a total of 2 images being generated.
        XCTAssertEqual(mockFileIO.fileNames.count, 2)

        XCTAssertEqual(mockFileIO.fileNames[0], CanvasViewModel.thumbnailPath.fileName)
        XCTAssertEqual(mockFileIO.fileNames[1], mockTextureFileName)

        // Output the image and save its name in the Model.
        XCTAssertEqual((mockFileIO.data as? CanvasModel)?.textureName, mockTextureFileName)
    }

    func testLoadCanvas() throws {
        // Arrange
        let zipFilePath = "zipFilePath.zip"

        // Act
        var resultModel: CanvasModel?
        do {
            resultModel = try canvasViewModel.loadCanvasData(from: zipFilePath,
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
        XCTAssertEqual(resultModel.textureName, mockFileIO.textureName)
        XCTAssertEqual(resultModel.thumbnailName, mockFileIO.thumbnailName)
    }

    func testApplyData() throws {
        // Arrange
        let zipFilePath = "zipFilePath.zip"
        let brushDiameter: Int = 5
        let eraserDiameter: Int = 10
        let textureSize = CGSize(width: 100, height: 100)

        let model = CanvasModel(textureSize: textureSize,
                                textureName: "mockTexture",
                                thumbnailName: "thumbnail",
                                drawingTool: DrawingToolType.brush.rawValue,
                                brushDiameter: brushDiameter,
                                eraserDiameter: eraserDiameter)
        // Act
        XCTAssertNoThrow(try canvasViewModel.applyCanvasDataToCanvas(model,
                                                                     folderURL: tmpFolderURL,
                                                                     zipFilePath: zipFilePath))

        // Assert
        XCTAssertEqual((canvasViewModel.drawingBrush.tool as? DrawingToolBrush)?.diameter, brushDiameter)
        XCTAssertEqual((canvasViewModel.drawingEraser.tool as? DrawingToolEraser)?.diameter, eraserDiameter)
        XCTAssertEqual(canvasViewModel.drawingTool.rawValue, DrawingToolType.brush.rawValue)
        XCTAssertEqual(canvasViewModel.currentTexture.size, textureSize)
        XCTAssertEqual(canvasViewModel.projectName, zipFilePath.fileName)
    }
}

class MockLayerManager: LayerManager {
    let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    var currentTexture: MTLTexture!

    func setTexture(_ texture: MTLTexture) {
        currentTexture = texture
    }
    func makeTexture(fromDocumentsFolder url: URL, textureSize: CGSize) throws -> MTLTexture? {
        return LayerManagerImpl.makeTexture(device, textureSize)
    }

    func initTextures(_ textureSize: CGSize) {}
    func merge(textures: [MTLTexture?],
               backgroundColor: (Int, Int, Int),
               into dstTexture: MTLTexture,
               _ commandBuffer: MTLCommandBuffer) {}
    func clearTexture(_ commandBuffer: MTLCommandBuffer) {}
}
class MockFileIO: FileIO {
    typealias T = CanvasModel
    var data: Codable?
    var textureName: String
    var thumbnailName: String

    var fileNames: [String] = []

    init(textureName: String,
         thumbnailName: String) {
        self.textureName = textureName
        self.thumbnailName = thumbnailName
    }

    func saveImage(bytes: [UInt8], to url: URL) throws {
        let filePath: String = url.lastPathComponent
        fileNames.append(filePath.fileName)
    }
    func saveImage(image: UIImage?, to url: URL) throws {
        let filePath: String = url.lastPathComponent
        fileNames.append(filePath.fileName)
    }

    func loadJson<T: Codable>(_ url: URL) throws -> T? {
        return CanvasModel(textureSize: .init(width: 100, height: 100),
                           textureName: textureName,
                           thumbnailName: thumbnailName,
                           drawingTool: DrawingToolType.brush.rawValue,
                           brushDiameter: 10,
                           eraserDiameter: 20) as? T
    }
    func saveJson<T: Codable>(_ data: T, to jsonUrl: URL) throws {
        self.data = data
    }

    func zip(_ srcFolderURL: URL, to zipFileURL: URL) throws {}
    func unzip(_ srcZipURL: URL, to destinationURL: URL) throws {}
}
