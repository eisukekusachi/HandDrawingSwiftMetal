//
//  CoreDataStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import CoreData
import UIKit

public protocol CoreDataStorage {

    var context: NSManagedObjectContext { get }

    func saveContext() throws
}
