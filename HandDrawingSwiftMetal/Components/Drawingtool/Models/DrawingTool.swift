//
//  DrawingTool.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/24.
//

import CanvasView
import CoreData
import UIKit

public protocol DrawingToolStorageProtocol {
    func load() async throws -> (type: Int, brushDiameter: Int, eraserDiameter: Int)?
    func save(type: Int, brushDiameter: Int, eraserDiameter: Int) async throws
}

@MainActor
public final class DrawingTool: ObservableObject {

    @Published private(set) var type: DrawingToolType = .brush
    @Published private(set) var brushDiameter: Int = 8
    @Published private(set) var eraserDiameter: Int = 8

    private let storage: DrawingToolStorageProtocol

    public init(
        initialType: DrawingToolType = .brush,
        initialBrushDiameter: Int = 8,
        initialEraserDiameter: Int = 8,
        storage: DrawingToolStorageProtocol
    ) {
        self.storage = storage

        Task {
            if let entity = try await storage.load() {
                self.type = .init(rawValue: entity.type)
                self.brushDiameter = entity.brushDiameter
                self.eraserDiameter = entity.eraserDiameter
            } else {
                self.type = initialType
                self.brushDiameter = initialBrushDiameter
                self.eraserDiameter = initialEraserDiameter

                saveData()
            }
        }
    }

    public final class CoreDataStorage: DrawingToolStorageProtocol {

        private let uniqueName: String
        private let entityName: String = "DrawingToolEntity"
        private let context: NSManagedObjectContext

        public init(
            uniqueName: String = "default",
            context: NSManagedObjectContext
        ) {
            self.uniqueName = uniqueName
            self.context = context
        }

        public func load() async throws -> (type: Int, brushDiameter: Int, eraserDiameter: Int)? {
            try await context.perform {
                guard let drawingTool = try self.fetch() else { return nil }
                return (
                    type: Int(drawingTool.type),
                    brushDiameter: Int(drawingTool.brushDiameter),
                    eraserDiameter: Int(drawingTool.eraserDiameter)
                )
            }
        }

        public func save(type: Int, brushDiameter: Int, eraserDiameter: Int) async throws {
            try await context.perform {
                let drawingTool = try self.fetch() ?? DrawingToolEntity(context: self.context)
                drawingTool.type = Int16(type)
                drawingTool.name = self.uniqueName
                drawingTool.brushDiameter = Int16(brushDiameter)
                drawingTool.eraserDiameter = Int16(eraserDiameter)

                if self.context.hasChanges {
                    try self.context.save()
                }
            }
        }

        private func fetch() throws -> DrawingToolEntity? {
            let request: NSFetchRequest<DrawingToolEntity> = DrawingToolEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", uniqueName)
            request.fetchLimit = 1
            request.returnsObjectsAsFaults = false
            return try context.fetch(request).first
        }
    }

    func setDrawingTool(_ type: DrawingToolType) {
        self.type = type
        saveData()
    }

    func setBrushDiameter(_ diameter: Int) {
        self.brushDiameter = diameter
        saveData()
    }

    func setEraserDiameter(_ diameter: Int) {
        self.eraserDiameter = diameter
        saveData()
    }

    func setBrushDiameter(_ diameter: Float) {
        self.brushDiameter = BrushDrawingRenderer.diameterIntValue(diameter)
        saveData()
    }

    func setEraserDiameter(_ diameter: Float) {
        self.eraserDiameter = EraserDrawingRenderer.diameterIntValue(diameter)
        saveData()
    }
}

extension DrawingTool {
    private func saveData() {
        Task {
            try? await storage.save(
                type: type.rawValue,
                brushDiameter: brushDiameter,
                eraserDiameter: eraserDiameter
            )
        }
    }
}
