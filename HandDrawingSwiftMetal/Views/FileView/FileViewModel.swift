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

    @Published var isShowingRenameAlert = false
    @Published var isShowingDeleteConfirm = false
    @Published var isShowingNewFileAlert = false
    @Published var isShowingErrorAlert = false
    @Published var errorAlertMessage = ""
    @Published var renameDraft = ""
    @Published var newFileNameDraft = "Untitled"

    private var onTapItem: ((URL) -> Void)?
    private var onRenameSelected: ((URL, String) async throws -> URL)?
    private var onDeleteSelected: ((URL) async throws -> Void)?
    private var onCreateNew: ((String) async throws -> Void)?
    private var currentOpenFileURL: URL?
    private var didConfigure = false

    var canCreateNew: Bool { onCreateNew != nil }

    var renameDisabled: Bool {
        onRenameSelected == nil || selectedIndex == nil
    }

    var deleteDisabled: Bool {
        guard
            onDeleteSelected != nil,
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
        selectedFileURL: URL? = nil,
        currentOpenFileURL: URL? = nil,
        onRenameSelected: ((URL, String) async throws -> URL)? = nil,
        onDeleteSelected: ((URL) async throws -> Void)? = nil,
        onCreateNew: ((String) async throws -> Void)? = nil,
        onTapItem: @escaping (URL) -> Void
    ) {
        self.list = list
        self.onTapItem = onTapItem
        self.onRenameSelected = onRenameSelected
        self.onDeleteSelected = onDeleteSelected
        self.onCreateNew = onCreateNew
        self.currentOpenFileURL = currentOpenFileURL
        self.selectedIndex = selectedFileURL.flatMap { url in
            list.firstIndex(where: { $0.fileURL == url })
        }
    }

    func tapGridItem(at index: Int) {
        guard index < list.count else { return }
        if selectedIndex == index {
            onTapItem?(list[index].fileURL)
        } else {
            selectedIndex = index
        }
    }

    func beginRename() {
        guard let selectedIndex, selectedIndex < list.count else { return }
        renameDraft = list[selectedIndex].title
        isShowingRenameAlert = true
    }

    func applyRename() {
        let newName = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else { return }
        guard
            let index = selectedIndex,
            index < list.count,
            let onRenameSelected
        else { return }

        let oldURL = list[index].fileURL
        let oldTitle = list[index].title

        var next = list
        next[index].update(title: newName, updatedAt: Date())
        list = next

        Task { @MainActor in
            do {
                let newURL = try await onRenameSelected(oldURL, newName)
                var updated = self.list
                updated[index].update(
                    title: newURL.deletingPathExtension().lastPathComponent,
                    fileURL: newURL,
                    updatedAt: Date()
                )
                self.list = updated
            } catch {
                var reverted = self.list
                reverted[index].update(title: oldTitle, fileURL: oldURL, updatedAt: Date())
                self.list = reverted
            }
        }
    }

    func beginNewFile() {
        newFileNameDraft = "Untitled"
        isShowingNewFileAlert = true
    }

    func applyNewFile() {
        let name = newFileNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let onCreateNew else { return }
        Task { @MainActor in
            do {
                try await onCreateNew(name)
            } catch {
                self.errorAlertMessage = error.localizedDescription
                self.isShowingErrorAlert = true
            }
        }
    }

    func applyDelete() {
        guard
            let onDeleteSelected,
            let index = selectedIndex,
            index < list.count
        else { return }

        let fileURL = list[index].fileURL
        Task { @MainActor in
            do {
                try await onDeleteSelected(fileURL)
                var next = self.list
                next.remove(at: index)
                self.list = next
                self.selectedIndex = nil
            } catch {
                self.errorAlertMessage = error.localizedDescription
                self.isShowingErrorAlert = true
            }
        }
    }
}
