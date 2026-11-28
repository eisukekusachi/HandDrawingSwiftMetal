//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics
import Foundation
import Testing
import TextureLayerView
@testable import HandDrawingSwiftMetal

struct TextureLayersSnapshotTests {

    private typealias Subject = TextureLayersSnapshot

    private let textureSize: CGSize = .init(width: 123, height: 456)

    @Test
    func `Confirms the snapshot file name is texture_layers`() {
        #expect(Subject.fileName == "texture_layers")
    }

    @Test
    func `When layers is empty, the snapshot stays empty`() {
        let subject = Subject(
            layers: [],
            layerIndex: 0,
            textureSize: textureSize
        )

        #expect(subject.layers.isEmpty)
        #expect(subject.selectedLayerId == nil)
    }

    @Test
    func `When layerIndex is negative, it is clamped to 0`() {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = Subject(
            layers: layers,
            layerIndex: -3,
            textureSize: textureSize
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 0)
        #expect(subject.selectedLayerId == layers[0].id)
    }

    @Test
    func `When layerIndex exceeds the number of layers, it is clamped to the last layer`() {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = Subject(
            layers: layers,
            layerIndex: 5,
            textureSize: textureSize
        )

        #expect(subject.layers.count == 2)
        #expect(subject.layerIndex == 1)
        #expect(subject.selectedLayerId == layers[1].id)
    }

    @Test
    func `Confirms Codable round-trips layers, selection, and texture size`() throws {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0", alpha: 10, isVisible: true),
            .generate(title: "layer1", alpha: 20, isVisible: false)
        ]
        let subject = Subject(
            layers: layers,
            layerIndex: 1,
            textureSize: textureSize
        )

        let data = try JSONEncoder().encode(subject)
        let decoded = try JSONDecoder().decode(Subject.self, from: data)

        #expect(decoded == subject)
        #expect(decoded.selectedLayerId == layers[1].id)
    }

    @Test
    func `Confirms writing and reading a snapshot in a directory`() throws {
        let layers: [TextureLayerModel] = [
            .generate(title: "layer0"),
            .generate(title: "layer1")
        ]
        let subject = Subject(
            layers: layers,
            layerIndex: 1,
            textureSize: textureSize
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try subject.write(in: directory)
        let loaded = try Subject(in: directory)

        #expect(loaded == subject)
        #expect(
            FileManager.default.fileExists(
                atPath: directory.appendingPathComponent(Subject.fileName).path
            )
        )
    }
}
