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

    private var selectAction: ((URL) -> Void)?

    private var currentOpenFileURL: URL?

    private var canRename = false
    private var canDelete = false

    var renameDisabled: Bool {
        guard
            canRename,
            let index = selectedIndex,
            fileCoordinator.item(index) != nil
        else { return true }
        return false
    }

    var deleteDisabled: Bool {
        guard
            canDelete,
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
        canRename: Bool = false,
        canDelete: Bool = false,
        selectAction: ((URL) -> Void)? = nil
    ) {
        self.selectAction = selectAction
        self.canRename = canRename
        self.canDelete = canDelete
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
