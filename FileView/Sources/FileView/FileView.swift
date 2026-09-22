//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Combine
import SwiftUI
import UIKit

public struct FileView: View {

    @ObservedObject private var fileList: FileList
    @StateObject private var viewModel: FileViewModel

    @Environment(\.dismiss) private var dismiss

    private let configuration: FileViewConfiguration
    private let strings: FileViewStrings
    private let icons: FileViewIcons

    public init(
        fileList: FileList,
        configuration: FileViewConfiguration = .init(),
        strings: FileViewStrings = .init(),
        icons: FileViewIcons = .init(),
        eventHandler: FileViewEventHandler? = nil,
        currentOpenFileURL: URL? = nil
    ) {
        self._fileList = ObservedObject(wrappedValue: fileList)
        self._viewModel = StateObject(
            wrappedValue: FileViewModel(
                fileList: fileList,
                strings: strings,
                currentOpenFileURL: currentOpenFileURL,
                eventHandler: eventHandler
            )
        )
        self.configuration = configuration
        self.strings = strings
        self.icons = icons
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                toolbar
                    .padding(.top, geometry.safeAreaInsets.top)

                ScrollView {
                    LazyVGrid(
                        columns: columns(
                            for: geometry.size.width - configuration.horizontalPadding * 2
                        ),
                        spacing: configuration.columnSpacing
                    ) {
                        ForEach(
                            Array(fileList.items.enumerated()), id: \.element.id
                        ) { index, item in
                            itemView(
                                item: item,
                                isSelected: viewModel.selectedIndex == index
                            )
                            .transition(
                                .opacity.combined(
                                    with: .scale(scale: configuration.itemTransitionScale)
                                )
                            )
                            .onTapGesture {
                                viewModel.onTapItem(at: index)
                            }
                        }
                    }
                    .animation(
                        .easeInOut(duration: configuration.itemAnimationDuration),
                        value: fileList.items.map(\.id)
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, configuration.horizontalPadding)
                .padding(.vertical, configuration.verticalPadding)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .background(configuration.backgroundColor)
        }
        .onReceive(viewModel.requestingDismiss) { _ in
            dismiss()
        }
        .alertDestructiveConfirmation(
            title: viewModel.deleteConfirmationTitle,
            message: viewModel.deleteConfirmationMessage,
            destructiveButtonTitle: viewModel.deleteConfirmationButtonTitle,
            cancelButtonTitle: strings.cancel,
            isPresented: $viewModel.isShowingDeleteConfirmDialog,
            onDestructive: { viewModel.confirmDelete() }
        )
        .alertWithTextField(
            title: strings.renameTitle,
            textFieldPrompt: strings.renamePrompt,
            message: strings.renameMessage,
            confirmButtonTitle: strings.ok,
            cancelButtonTitle: strings.cancel,
            text: $viewModel.draftName,
            isPresented: $viewModel.isShowingRenameDialog,
            onConfirm: { viewModel.confirmRename() }
        )
    }
}

private extension FileView {
    var toolbar: some View {
        HStack {
            leadingToolbarContent()
            Spacer(minLength: 0)
            trailingToolbarContent()
        }
        .padding(.horizontal, configuration.horizontalPadding)
        .frame(height: configuration.navigationBarHeight)
        .frame(maxWidth: .infinity)
        .background(configuration.backgroundColor)
    }

    /// Builds grid columns from the available width, using `preferredThumbnailWidth` as a sizing hint.
    func columns(for availableWidth: CGFloat) -> [GridItem] {
        let spacing = configuration.columnSpacing
        let cellWidthHint = configuration.preferredThumbnailWidth + spacing
        let columnCount = max(1, Int((availableWidth + spacing) / cellWidthHint))

        return Array(
            repeating: GridItem(.flexible(), spacing: spacing),
            count: columnCount
        )
    }

    func itemView(
        item: FileItem,
        isSelected: Bool
    ) -> some View {
        VStack(alignment: .center, spacing: 0) {
            thumbnail(item: item, isSelected: isSelected)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)

            Text(item.title)
                .font(configuration.titleFont)
                .foregroundColor(configuration.titleColor)
                .frame(maxWidth: .infinity)
                .frame(height: configuration.titleBarHeight)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension FileView {
    @ViewBuilder
    func leadingToolbarContent() -> some View {
        HStack(spacing: configuration.toolbarButtonSpacing) {
            Button(
                action: { viewModel.onTapCreate() },
                label: { toolbarIcon(icons.create) }
            )

            Button(
                action: { viewModel.onTapRename() },
                label: { toolbarIcon(icons.rename) }
            )
            .grayedOutWhenDisabled(viewModel.renameDisabled)

            Button(
                action: { viewModel.onTapDelete() },
                label: { toolbarIcon(icons.delete) }
            )
            .grayedOutWhenDisabled(
                viewModel.deleteDisabled,
                enabledColor: configuration.deleteButtonEnabledColor
            )
        }
    }

    func toolbarIcon(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(
                width: configuration.toolbarButtonSize,
                height: configuration.toolbarButtonSize
            )
    }

    func trailingToolbarContent() -> some View {
        Button(
            action: { viewModel.onTapClose() },
            label: { icons.close }
        )
    }

    func thumbnail(item: FileItem, isSelected: Bool) -> some View {
        configuration.thumbnailBackgroundColor
            .overlay {
                if let image = item.thumbnail, image.size.width > 0 && image.size.height > 0 {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(configuration.cornerRadius)
                        .padding(configuration.thumbnailImagePadding)
                } else {
                    unsavedThumbnailPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .stroke(
                        isSelected ? configuration.selectionColor : Color.clear,
                        lineWidth: configuration.selectionBorderWidth
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    icons.selectionBadge
                        .resizable()
                        .scaledToFit()
                        .font(
                            .system(
                                size: configuration.selectionBadgeFontSize,
                                weight: .semibold
                            )
                        )
                        .foregroundColor(configuration.selectionColor)
                        .frame(
                            width: configuration.selectionBadgeSize,
                            height: configuration.selectionBadgeSize
                        )
                        .padding(configuration.selectionBadgePadding)
                }
            }
    }

    var unsavedThumbnailPlaceholder: some View {
        let placeholderTint = configuration.unsavedPlaceholderTintColor

        return VStack(
            alignment:. center,
            spacing: configuration.unsavedPlaceholderSpacing
        ) {
            Spacer()

            icons.unsavedPlaceholder
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .font(
                    .system(
                        size: configuration.unsavedPlaceholderIconFontSize,
                        weight: .regular
                    )
                )
                .foregroundStyle(
                    placeholderTint.opacity(configuration.unsavedPlaceholderIconOpacity)
                )
                .frame(
                    width: configuration.unsavedPlaceholderIconSize,
                    height: configuration.unsavedPlaceholderIconSize
                )

            Text(strings.notSavedYet)
                .font(configuration.unsavedPlaceholderFont)
                .foregroundStyle(placeholderTint)
                .multilineTextAlignment(configuration.unsavedPlaceholderTextAlignment)
                .lineLimit(configuration.unsavedPlaceholderLineLimit)
                .minimumScaleFactor(configuration.unsavedPlaceholderMinimumScaleFactor)
                .padding(configuration.unsavedPlaceholderTextPadding)

            Spacer()
        }
    }
}

#if DEBUG

private enum FileViewPreviewData {
    static func thumbnail(
        color: UIColor, size: CGSize = CGSize(width: 200, height: 200)
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    let fileList = FileList(
        fileSuffix: "zip",
        items: [
            .init(
                thumbnail: FileViewPreviewData.thumbnail(color: .systemBlue),
                fileURL: URL(fileURLWithPath: "/tmp/Test.zip")
            ),
            .init(
                thumbnail: FileViewPreviewData.thumbnail(color: .systemOrange),
                fileURL: URL(fileURLWithPath: "/tmp/Sketch.zip")
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Draft.zip")
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/LongName.zip")
            )
        ]
    )
    return FileView(
        fileList: fileList
    )
}

#endif
