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
            let i = selectedIndex,
            i >= 0 && i < fileCoordinator.fileList.count
        else { return true }

        return false
    }

    var deleteDisabled: Bool {
        guard
            deleteAction != nil,
            let i = selectedIndex,
            i >= 0 && i < fileCoordinator.fileList.count,
            fileCoordinator.fileList[i].fileURL != currentOpenFileURL
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
        guard index < fileCoordinator.fileList.count else { return }

        if selectedIndex == index {
            selectAction?(fileCoordinator.fileList[index].fileURL)
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
            selectedIndex < fileCoordinator.fileList.count
        else { return }

        draftName = fileCoordinator.fileList[selectedIndex].title
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
            !newName.isEmpty,
            let index = selectedIndex,
            index < fileCoordinator.fileList.count
        else { return }

        let oldURL = fileCoordinator.fileList[index].fileURL
        let newURL = try await renameAction(oldURL, newName)

        selectedIndex = fileCoordinator.index(url: newURL)
    }

    func applyDelete() async throws {
        guard
            let deleteAction,
            let index = selectedIndex,
            index < fileCoordinator.fileList.count
        else { return }

        let fileURL = fileCoordinator.fileList[index].fileURL

        try await deleteAction(fileURL)

        selectedIndex = nil
    }
}
