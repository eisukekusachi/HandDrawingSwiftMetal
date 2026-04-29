//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import SwiftUI

struct FileView: View {

    @ObservedObject private var fileCoordinator: FileCoordinator
    @StateObject private var viewModel: FileViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Active file URL
    private let currentOpenFileURL: URL?

    /// Highlighted file URL
    private let selectedFileURL: URL?

    private let createAction: ((String) async throws -> Void)?
    private let renameAction: ((Int, String) async throws -> URL)?
    private let deleteAction: ((Int) async throws -> Void)?
    private let selectAction: (URL) -> Void

    private var columns: [GridItem] {
        let spacing: CGFloat = 12
        if horizontalSizeClass == .compact {
            return [.init(.flexible(), spacing: spacing)]
        } else {
            return [
                .init(.flexible(), spacing: spacing),
                .init(.flexible(), spacing: spacing)
            ]
        }
    }

    init(
        fileCoordinator: FileCoordinator,
        currentOpenFileURL: URL? = nil,
        selectedFileURL: URL? = nil,
        createAction: ((String) async throws -> Void)? = nil,
        renameAction: ((Int, String) async throws -> URL)? = nil,
        deleteAction: ((Int) async throws -> Void)? = nil,
        selectAction: @escaping (URL) -> Void
    ) {
        self._fileCoordinator = ObservedObject(wrappedValue: fileCoordinator)
        self._viewModel = StateObject(wrappedValue: FileViewModel(fileCoordinator: fileCoordinator))
        self.selectedFileURL = selectedFileURL
        self.currentOpenFileURL = currentOpenFileURL
        self.createAction = createAction
        self.renameAction = renameAction
        self.deleteAction = deleteAction
        self.selectAction = selectAction
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(fileCoordinator.fileList.enumerated()), id: \.element.id) { index, item in
                        itemView(
                            item: item,
                            isSelected: viewModel.selectedIndex == index
                        )
                        .onTapGesture {
                            viewModel.onTapItem(at: index)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    leadingToolbarContent()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    trailingToolbarContent()
                }
            }
            .alertWithTextField(
                title: String(localized: "Rename"),
                textFieldPrompt: String(localized: "Name"),
                message: String(localized: "Enter a new name"),
                confirmButtonTitle: String(localized: "OK"),
                text: $viewModel.draftName,
                isPresented: $viewModel.isShowingRenameDialog,
                onConfirm: { renameItem() }
            )
            .alertWithTextField(
                title: String(localized: "New file"),
                textFieldPrompt: String(localized: "File name"),
                message: String(localized: "Enter a name for the new file"),
                confirmButtonTitle: String(localized: "Create"),
                text: $viewModel.newFileName,
                isPresented: $viewModel.isShowingNewFileDialog,
                onConfirm: { newItem() }
            )
            .alertDestructiveConfirmation(
                title: String(localized: "Delete this file?"),
                message: String(localized: "This file will be removed from the device"),
                destructiveButtonTitle: String(localized: "Delete"),
                isPresented: $viewModel.isShowingDeleteConfirmDialog,
                onDestructive: { deleteItem() }
            )
            .alert(
                title: String(localized: "Error"),
                message: $viewModel.errorAlertMessage,
                isPresented: $viewModel.isShowingErrorAlert
            )
        }
        .navigationViewStyle(.stack)
        .onFirstAppear {
            viewModel.configure(
                currentOpenFileURL: currentOpenFileURL,
                selectedFileURL: selectedFileURL,
                canCreate: createAction != nil,
                canRename: renameAction != nil,
                canDelete: deleteAction != nil,
                selectAction: selectAction
            )
        }
    }
}

private extension FileView {
    @ViewBuilder
    func leadingToolbarContent() -> some View {
        HStack(spacing: 20) {
            Button(
                action: { viewModel.onTapNewButton() },
                label: { Image(systemName: "plus.circle") }
            )
            .disabled(viewModel.createDisabled)

            Button(
                action: { viewModel.onTapRenameButton() },
                label: { Image(systemName: "pencil") }
            )
            .disabled(viewModel.renameDisabled)

            Button(
                action: { viewModel.isShowingDeleteConfirmDialog = true },
                label: { Image(systemName: "trash") }
            )
            .tint(.red)
            .disabled(viewModel.deleteDisabled)
        }
    }

    func trailingToolbarContent() -> some View {
        Button(
            action: { dismiss() },
            label: { Image(systemName: "xmark.circle.fill") }
        )
    }

    func itemView(item: LocalFileItem, isSelected: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.92, green: 0.92, blue: 0.92))

            if let image = item.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                let placeholderTint = Color(red: 0.22, green: 0.24, blue: 0.28)

                VStack(spacing: 10) {
                    Spacer()

                    Image(systemName: "questionmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(placeholderTint.opacity(0.85))

                    Text(
                        String(localized: "Not saved yet")
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(placeholderTint)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)

                    Spacer()
                }
            }

            Text(item.title)
                .bold()
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 3
                )
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .padding(10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    isSelected ? Color.accentColor.opacity(0.10) : Color.clear
                )
        )
    }
}

private extension FileView {

    func newItem() {
        Task {
            do {
                guard let createAction else { return }
                try await createAction(viewModel.newFileName)
            } catch {
                viewModel.errorAlertMessage = error.nsErrorDescription
                viewModel.isShowingErrorAlert = true
            }
        }
    }

    func renameItem() {
        Task {
            do {
                guard
                    let renameAction,
                    let index = viewModel.selectedIndex
                else { return }
                let newURL = try await renameAction(index, viewModel.draftName)
                viewModel.selectedIndex = fileCoordinator.index(url: newURL)
            } catch {
                viewModel.errorAlertMessage = error.nsErrorDescription
                viewModel.isShowingErrorAlert = true
            }
        }
    }

    func deleteItem() {
        Task {
            do {
                guard
                    let deleteAction,
                    let index = viewModel.selectedIndex
                else { return }
                try await deleteAction(index)
                viewModel.selectedIndex = nil
            } catch {
                viewModel.errorAlertMessage = error.nsErrorDescription
                viewModel.isShowingErrorAlert = true
            }
        }
    }
}

#Preview {
    let dependencies = HandDrawingViewDependencies(
        localFileRepository: MockLocalFileRepository()
    )
    let fileCoordinator = FileCoordinator(
        fileList: [
            .init(
                title: "Test",
                createdAt: Date(),
                updatedAt: Date(),
                thumbnail: nil,
                suffix: "zip"
            ),
            .init(
                title: "Test Test Test Test Test Test Test Test Test Test Test Test",
                createdAt: Date(),
                updatedAt: Date(),
                thumbnail: nil,
                suffix: "zip"
            )
        ],
        dependencies: dependencies,
        fileSuffix: "zip"
    )
    return FileView(
        fileCoordinator: fileCoordinator,
        currentOpenFileURL: nil,
        selectedFileURL: nil,
        createAction: { _ in },
        renameAction: { _, _ in URL(fileURLWithPath: "/tmp/example.zip") },
        deleteAction: { _ in },
        selectAction: { _ in }
    )
}
