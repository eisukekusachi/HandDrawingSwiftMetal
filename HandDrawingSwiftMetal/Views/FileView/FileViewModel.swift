//
//  FileViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/24.
//

import Combine
import Foundation
import UIKit

@MainActor
final class FileViewModel: ObservableObject {

    @Published var list: [LocalFileItem]
    @Published var selectedIndex: Int?

    @Published var isShowingRenameDialog = false
    @Published var isShowingDeleteConfirmDialog = false
    @Published var isShowingNewFileDialog = false
    @Published var isShowingErrorAlert = false
    @Published var errorAlertMessage = ""
    @Published var draftName = ""
    @Published var newFileName = "Untitled"

    private var renameAction: ((URL, String) async throws -> URL)?
    private var deleteAction: ((URL) async throws -> Void)?
    private var createAction: ((String) async throws -> Void)?
    private var selectAction: ((URL) -> Void)?

    private var currentOpenFileURL: URL?
    private var didConfigure = false

    var canCreateNew: Bool { createAction != nil }

    var renameDisabled: Bool {
        renameAction == nil || selectedIndex == nil
    }

    var deleteDisabled: Bool {
        guard
            deleteAction != nil,
            let i = selectedIndex,
            i < list.count
        else { return true }

        if let currentOpenFileURL, list[i].fileURL == currentOpenFileURL { return true }

        return false
    }

    init() {
        self.list = []
        self.selectedIndex = nil
    }

    func configure(
        list: [LocalFileItem],
        currentOpenFileURL: URL? = nil,
        selectedFileURL: URL? = nil,
        renameAction: ((URL, String) async throws -> URL)? = nil,
        deleteAction: ((URL) async throws -> Void)? = nil,
        createAction: ((String) async throws -> Void)? = nil,
        selectAction: @escaping (URL) -> Void
    ) {
        self.list = list
        self.selectAction = selectAction
        self.renameAction = renameAction
        self.deleteAction = deleteAction
        self.createAction = createAction
        self.currentOpenFileURL = currentOpenFileURL
        self.selectedIndex = selectedFileURL.flatMap { url in
            list.firstIndex(where: { $0.fileURL == url })
        }
    }
}

extension FileViewModel {
    func onTapItem(at index: Int) {
        guard index < list.count else { return }

        if selectedIndex == index {
            selectAction?(list[index].fileURL)
        } else {
            selectedIndex = index
        }
    }

    func onTapNewButton() {
        newFileName = Calendar.currentDate
        isShowingNewFileDialog = true
    }

    func onTapRenameButton() {
        guard
            let selectedIndex,
            selectedIndex < list.count
        else { return }

        draftName = list[selectedIndex].title
        isShowingRenameDialog = true
    }
}

extension FileViewModel {
    func applyNewFile() async throws {
        let newName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let createAction,
            !newName.isEmpty
        else { return }

        try await createAction(newName)
    }

    func applyRename() async throws {
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let renameAction,
            !newName.isEmpty,
            let index = selectedIndex,
            index < list.count
        else { return }

        let oldURL = list[index].fileURL

        let newURL = try await renameAction(oldURL, newName)

        let newList = self.list
        newList[index].update(
            title: newURL.baseName,
            fileURL: newURL,
            updatedAt: Date()
        )
        list = newList
    }

    func applyDelete() async throws {
        guard
            let deleteAction,
            let index = selectedIndex,
            index < list.count
        else { return }

        let fileURL = list[index].fileURL

        try await deleteAction(fileURL)

        var newList = list
        newList.remove(at: index)
        list = newList

        selectedIndex = nil
    }
}
