//
//  FileView.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import CanvasView
import SwiftUI

struct FileView: View {

    private let onTapItem: ((URL) -> Void)
    private let onRenameSelected: ((URL, String) async throws -> URL)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var list: [LocalFileItem]
    @State private var selectedIndex: Int?
    @State private var isShowingRenameAlert: Bool = false
    @State private var renameDraft: String = ""

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
        onRenameSelected: ((URL, String) async throws -> URL)? = nil,
        onTapItem: @escaping ((URL) -> Void)
    ) {
        self.onTapItem = onTapItem
        self.onRenameSelected = onRenameSelected
        self._list = State(initialValue: list)
        self._selectedIndex = State(
            initialValue: selectedFileURL.flatMap { url in
                list.firstIndex(where: { $0.fileURL == url })
            }
        )
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0 ..< list.count, id: \.self) { index in
                        itemView(item: list[index], isSelected: selectedIndex == index)
                            .onTapGesture {
                                if selectedIndex == index {
                                    onTapItem(list[index].fileURL)
                                } else {
                                    selectedIndex = index
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        guard let selectedIndex else { return }
                        renameDraft = list[selectedIndex].title
                        isShowingRenameAlert = true
                    }) {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Rename")
                    .disabled(onRenameSelected == nil || selectedIndex == nil)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(Color.white)

                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .semibold))
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                        .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .alert("Rename", isPresented: $isShowingRenameAlert) {
                TextField("Name", text: $renameDraft)
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    let newName = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !newName.isEmpty else { return }
                    guard
                        let selectedIndex,
                        let onRenameSelected
                    else { return }

                    let oldURL = list[selectedIndex].fileURL
                    let oldTitle = list[selectedIndex].title

                    // Immediate UI update
                    list[selectedIndex].update(title: newName, updatedAt: Date())

                    Task { @MainActor in
                        do {
                            let newURL = try await onRenameSelected(oldURL, newName)
                            list[selectedIndex].update(
                                title: newURL.deletingPathExtension().lastPathComponent,
                                fileURL: newURL,
                                updatedAt: Date()
                            )
                        } catch {
                            // Revert if rename failed
                            list[selectedIndex].update(title: oldTitle, fileURL: oldURL, updatedAt: Date())
                        }
                    }
                }
            } message: {
                Text("Enter a new name.")
            }
        }
        .navigationViewStyle(.stack)
    }

    private func itemView(item: LocalFileItem, isSelected: Bool) -> some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(Color(red: 0.92, green: 0.92, blue: 0.92))

            if let image = item.thumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "questionmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .opacity(0.5)
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
        onRenameSelected: { url, _ in url },
        onTapItem: { _ in }
    )
}
