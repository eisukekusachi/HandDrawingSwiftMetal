//
//  CoreDataRepositoryProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import CoreData
import UIKit

protocol CoreDataRepository {

    var context: NSManagedObjectContext { get }

    func fetchEntity() throws -> NSManagedObject?
    func saveContext() throws
}
