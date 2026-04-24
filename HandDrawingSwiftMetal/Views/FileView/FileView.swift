//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import SwiftUI

struct FileView: View {

    @StateObject private var viewModel = FileViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let initialList: [LocalFileItem]
    private let selectedFileURL: URL?
    private let currentOpenFileURL: URL?
    private let onRenameSelected: ((URL, String) async throws -> URL)?
    private let onDeleteSelected: ((URL) async throws -> Void)?
    private let onCreateNew: ((String) async throws -> Void)?
    private let onTapItem: (URL) -> Void

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
        list: [LocalFileItem],
        selectedFileURL: URL? = nil,
        currentOpenFileURL: URL? = nil,
        onRenameSelected: ((URL, String) async throws -> URL)? = nil,
        onDeleteSelected: ((URL) async throws -> Void)? = nil,
        onCreateNew: ((String) async throws -> Void)? = nil,
        onTapItem: @escaping (URL) -> Void
    ) {
        self.initialList = list
        self.selectedFileURL = selectedFileURL
        self.currentOpenFileURL = currentOpenFileURL
        self.onRenameSelected = onRenameSelected
        self.onDeleteSelected = onDeleteSelected
        self.onCreateNew = onCreateNew
        self.onTapItem = onTapItem
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0 ..< viewModel.list.count, id: \.self) { index in
                        itemView(
                            item: viewModel.list[index],
                            isSelected: viewModel.selectedIndex == index
                        )
                        .onTapGesture {
                            viewModel.tapGridItem(at: index)
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
                title: "Rename",
                textFieldPrompt: "Name",
                message: "Enter a new name",
                confirmButtonTitle: "OK",
                text: $viewModel.renameDraft,
                isPresented: $viewModel.isShowingRenameAlert,
                onConfirm: { viewModel.applyRename() }
            )
            .alertWithTextField(
                title: "New file",
                textFieldPrompt: "File name",
                message: "Enter a name for the new file",
                confirmButtonTitle: "Create",
                text: $viewModel.newFileNameDraft,
                isPresented: $viewModel.isShowingNewFileAlert,
                onConfirm: { viewModel.applyNewFile() }
            )
            .alertDestructiveConfirmation(
                title: "Delete this file?",
                message: "This file will be removed from the device",
                destructiveButtonTitle: "Delete",
                isPresented: $viewModel.isShowingDeleteConfirm,
                onDestructive: { viewModel.applyDelete() }
            )
            .alert(
                title: "Error",
                message: $viewModel.errorAlertMessage,
                isPresented: $viewModel.isShowingErrorAlert
            )
        }
        .navigationViewStyle(.stack)
        .onFirstAppear {
            viewModel.configure(
                list: initialList,
                selectedFileURL: selectedFileURL,
                currentOpenFileURL: currentOpenFileURL,
                onRenameSelected: onRenameSelected,
                onDeleteSelected: onDeleteSelected,
                onCreateNew: onCreateNew,
                onTapItem: onTapItem
            )
        }
    }
}

private extension FileView {
    @ViewBuilder
    func leadingToolbarContent() -> some View {
        HStack(spacing: 20) {
            if viewModel.canCreateNew {
                Button(
                    action: { viewModel.beginNewFile() },
                    label: { Image(systemName: "plus.circle") }
                )
            }

            Button(
                action: { viewModel.beginRename() },
                label: { Image(systemName: "pencil") }
            )
            .disabled(viewModel.renameDisabled)

            Button(
                action: { viewModel.isShowingDeleteConfirm = true },
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

                    Text("Not saved yet")
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
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
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
                .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
        )
    }
}

#Preview {
    FileView(
        list: [
            .init(
                title: "Test",
                createdAt: Date(),
                updatedAt: Date(),
                thumbnail: nil,
                fileURL: URL(fileURLWithPath: "")
            ),
            .init(
                title: "Test Test Test Test Test Test Test Test Test Test Test Test",
                createdAt: Date(),
                updatedAt: Date(),
                thumbnail: nil,
                fileURL: URL(fileURLWithPath: "")
            )
        ],
        selectedFileURL: nil,
        currentOpenFileURL: nil,
        onRenameSelected: { url, _ in url },
        onDeleteSelected: { _ in },
        onCreateNew: { _ in },
        onTapItem: { _ in }
    )
}
