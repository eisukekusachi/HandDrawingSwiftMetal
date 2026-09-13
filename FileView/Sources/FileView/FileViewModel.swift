//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Combine
import Foundation

@MainActor
final class FileViewModel: ObservableObject {

    /// Index of the currently highlighted item in the file list
    @Published var selectedIndex: Int? {
        didSet {
            selectedItem = selectedIndex.flatMap { fileList.item($0) }
        }
    }

    /// Files shown in the list
    private let fileList: FileList

    /// A publisher that emits a request to dismiss the file list
    let requestingDismiss: PassthroughSubject<Void, Never> = .init()

    /// Whether the rename button should be disabled
    var renameDisabled: Bool {
        guard
            !fileList.items.isEmpty,
            let index = selectedIndex,
            fileList.item(index) != nil
        else { return true }
        return false
    }

    /// Whether the delete button should be disabled
    var deleteDisabled: Bool {
        guard
            !fileList.items.isEmpty,
            let index = selectedIndex,
            fileList.item(index) != nil
        else { return true }
        return false
    }

    /// Whether the selected file is the canvas currently open outside this list
    var isSelectedFileOpen: Bool {
        guard
            let index = selectedIndex,
            let item = fileList.item(index)
        else { return false }
        return item.fileURL == currentOpenFileURL
    }

    /// Title for the delete confirmation dialog
    var deleteConfirmationTitle: String {
        isSelectedFileOpen
            ? strings.resetCanvasTitle
            : strings.deleteFileTitle
    }

    /// Message for the delete confirmation dialog
    var deleteConfirmationMessage: String {
        isSelectedFileOpen
            ? strings.resetCanvasMessage
            : strings.deleteFileMessage
    }

    /// Destructive button title for the delete confirmation dialog
    var deleteConfirmationButtonTitle: String {
        isSelectedFileOpen
            ? strings.reset
            : strings.delete
    }

    /// Whether the delete confirmation dialog is presented
    @Published var isShowingDeleteConfirmDialog = false

    /// Whether the rename dialog is presented
    @Published var isShowingRenameDialog = false

    /// Draft name shown in the rename dialog
    @Published var draftName = ""

    /// Stable reference to the selected item, used to keep selection after the list changes
    private weak var selectedItem: FileItem?
    /// File URL of the canvas that is currently open outside this list
    private var currentOpenFileURL: URL?

    /// User-facing copy
    private let strings: FileViewStrings

    /// Callbacks for create, rename, delete, and open actions
    private let eventHandler: FileViewEventHandler?

    private var cancellables = Set<AnyCancellable>()

    init(
        fileList: FileList,
        strings: FileViewStrings = .init(),
        currentOpenFileURL: URL? = nil,
        eventHandler: FileViewEventHandler? = nil
    ) {
        self.fileList = fileList
        self.strings = strings
        self.eventHandler = eventHandler
        self.currentOpenFileURL = currentOpenFileURL
        self.selectedIndex = fileList.index(fileURL: currentOpenFileURL)

        fileList.$items
            .sink { [weak self] items in
                guard let self else { return }
                let newIndex = selectedItem.flatMap { selected in
                    items.firstIndex { $0 === selected }
                }
                if selectedIndex != newIndex {
                    selectedIndex = newIndex
                }
            }
            .store(in: &cancellables)
    }

    func setup(
        selectedFileURL: URL? = nil
    ) {
        currentOpenFileURL = selectedFileURL
        selectedIndex = fileList.index(fileURL: selectedFileURL)
    }
}

extension FileViewModel {
    func onTapItem(at index: Int) {
        guard let item = fileList.item(index) else { return }

        if selectedIndex != index {
            selectedIndex = index
        } else if item.fileURL != currentOpenFileURL {
            eventHandler?.onSelectItem(item.fileURL)
        } else {
            requestingDismiss.send()
        }
    }

    func onTapClose() {
        requestingDismiss.send()
    }

    func onTapCreate() {
        eventHandler?.onTapCreate()
    }

    func onTapRename() {
        guard
            let index = selectedIndex,
            let item = fileList.item(index)
        else { return }

        draftName = item.title
        isShowingRenameDialog = true
    }

    func onTapDelete() {
        guard
            let index = selectedIndex,
            fileList.item(index) != nil
        else { return }

        isShowingDeleteConfirmDialog = true
    }
}

extension FileViewModel {
    func confirmRename() {
        guard
            let index = selectedIndex,
            let item = fileList.item(index)
        else { return }

        let isOpenFile = item.fileURL == currentOpenFileURL

        guard let newTitle = eventHandler?.onTapRename(index, draftName) else {
            return
        }

        selectedIndex = fileList.index(title: newTitle)

        if isOpenFile {
            currentOpenFileURL = item.fileURL
        }
    }

    func confirmDelete() {
        guard
            let index = selectedIndex,
            fileList.item(index) != nil
        else { return }

        eventHandler?.onTapDelete(index)
    }
}
