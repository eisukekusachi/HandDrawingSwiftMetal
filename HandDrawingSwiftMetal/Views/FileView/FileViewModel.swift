//
//  FileViewModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/24.
//

import Combine
import Foundation

@MainActor
final class FileViewModel: ObservableObject {

    let fileCoordinator: FileCoordinator

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

    var renameDisabled: Bool {
        guard
            renameAction != nil,
            let index = selectedIndex,
            let _ = fileCoordinator.item(index)
        else { return true }

        return false
    }

    var deleteDisabled: Bool {
        guard
            deleteAction != nil,
            let index = selectedIndex,
            let item = fileCoordinator.item(index),
            item.fileURL != currentOpenFileURL
        else { return true }

        return false
    }

    init(fileCoordinator: FileCoordinator) {
        self.fileCoordinator = fileCoordinator
        self.selectedIndex = nil
    }

    func configure(
        currentOpenFileURL: URL? = nil,
        selectedFileURL: URL? = nil,
        renameAction: ((URL, String) async throws -> URL)? = nil,
        deleteAction: ((URL) async throws -> Void)? = nil,
        createAction: ((String) async throws -> Void)? = nil,
        selectAction: ((URL) -> Void)? = nil
    ) {
        self.selectAction = selectAction
        self.renameAction = renameAction
        self.deleteAction = deleteAction
        self.createAction = createAction
        self.currentOpenFileURL = currentOpenFileURL
        self.selectedIndex = selectedFileURL.flatMap { url in
            fileCoordinator.index(url: url)
        }
    }
}

extension FileViewModel {
    func onTapItem(at index: Int) {
        guard
            let item = fileCoordinator.item(index)
        else { return }

        if selectedIndex == index {
            selectAction?(item.fileURL)
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
            let index = selectedIndex,
            let item = fileCoordinator.item(index)
        else { return }

        draftName = item.title
        isShowingRenameDialog = true
    }
}

extension FileViewModel {
    func applyNewFile() async throws {
        try await createAction?(newFileName)
    }

    func applyRename() async throws {
        let newName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let renameAction,
            let index = selectedIndex,
            let item = fileCoordinator.item(index)
        else { return }

        let oldURL = item.fileURL
        let newURL = try await renameAction(oldURL, newName)

        selectedIndex = fileCoordinator.index(url: newURL)
    }

    func applyDelete() async throws {
        guard
            let deleteAction,
            let index = selectedIndex,
            let item = fileCoordinator.item(index)
        else { return }

        try await deleteAction(item.fileURL)

        selectedIndex = nil
    }
}
