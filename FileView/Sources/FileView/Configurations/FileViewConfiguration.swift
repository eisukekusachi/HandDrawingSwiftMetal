//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/12.
//

import SwiftUI

/// Appearance settings for `FileView`.
public struct FileViewConfiguration {
    // MARK: Layout

    /// Height of the title area under each thumbnail
    public var titleBarHeight: CGFloat
    /// Height of the top toolbar
    public var navigationBarHeight: CGFloat
    /// Horizontal inset of the file grid and toolbar
    public var horizontalPadding: CGFloat
    /// Vertical inset around the file grid
    public var verticalPadding: CGFloat
    /// Fixed spacing between grid columns and rows
    public var columnSpacing: CGFloat
    /// Spacing between leading toolbar buttons
    public var toolbarButtonSpacing: CGFloat
    /// Preferred thumbnail width used only to decide column count; actual cell width is flexible
    public var preferredThumbnailWidth: CGFloat
    /// Corner radius of each thumbnail
    public var cornerRadius: CGFloat
    /// Inset around a saved thumbnail image inside its cell
    public var thumbnailImagePadding: CGFloat
    /// Width of the selection stroke around a thumbnail
    public var selectionBorderWidth: CGFloat
    /// Size of the selection badge in the thumbnail corner
    public var selectionBadgeSize: CGFloat
    /// Inset of the selection badge from the thumbnail corner
    public var selectionBadgePadding: CGFloat
    /// Vertical spacing inside the unsaved-thumbnail placeholder
    public var unsavedPlaceholderSpacing: CGFloat
    /// Size of the unsaved-thumbnail placeholder icon
    public var unsavedPlaceholderIconSize: CGFloat
    /// Inset around the unsaved-thumbnail placeholder text
    public var unsavedPlaceholderTextPadding: CGFloat
    /// Max lines for the unsaved-thumbnail placeholder text
    public var unsavedPlaceholderLineLimit: Int
    /// Minimum scale factor for the unsaved-thumbnail placeholder text
    public var unsavedPlaceholderMinimumScaleFactor: CGFloat
    /// Opacity applied to the unsaved-thumbnail placeholder icon tint
    public var unsavedPlaceholderIconOpacity: Double

    // MARK: Colors

    /// Background of the file list and toolbar
    public var backgroundColor: Color
    /// Fill behind each thumbnail
    public var thumbnailBackgroundColor: Color
    /// Color of each item title
    public var titleColor: Color
    /// Selection stroke and badge color
    public var selectionColor: Color
    /// Enabled color for the delete toolbar button
    public var deleteButtonEnabledColor: Color
    /// Tint for the unsaved-thumbnail placeholder
    public var unsavedPlaceholderTintColor: Color

    // MARK: Typography

    /// Font for each item title
    public var titleFont: Font
    /// Point size used when the selection badge is an SF Symbol
    public var selectionBadgeFontSize: CGFloat
    /// Point size used when the unsaved placeholder icon is an SF Symbol
    public var unsavedPlaceholderIconFontSize: CGFloat
    /// Font for the unsaved-thumbnail placeholder text
    public var unsavedPlaceholderFont: Font
    /// Alignment for the unsaved-thumbnail placeholder text
    public var unsavedPlaceholderTextAlignment: TextAlignment

    // MARK: Animation

    /// Insertion/removal scale for grid items (`1` = no scale change)
    public var itemTransitionScale: CGFloat
    /// Duration of the grid insert/remove animation
    public var itemAnimationDuration: TimeInterval

    public init(
        titleBarHeight: CGFloat = 50,
        navigationBarHeight: CGFloat = 44,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 24,
        columnSpacing: CGFloat = 12,
        toolbarButtonSpacing: CGFloat = 20,
        preferredThumbnailWidth: CGFloat = 200,
        cornerRadius: CGFloat = 24,
        thumbnailImagePadding: CGFloat = 16,
        selectionBorderWidth: CGFloat = 2,
        selectionBadgeSize: CGFloat = 22,
        selectionBadgePadding: CGFloat = 10,
        unsavedPlaceholderSpacing: CGFloat = 10,
        unsavedPlaceholderIconSize: CGFloat = 44,
        unsavedPlaceholderTextPadding: CGFloat = 8,
        unsavedPlaceholderLineLimit: Int = 3,
        unsavedPlaceholderMinimumScaleFactor: CGFloat = 0.8,
        unsavedPlaceholderIconOpacity: Double = 0.85,
        backgroundColor: Color = Color(uiColor: .systemBackground),
        thumbnailBackgroundColor: Color = Color(red: 0.92, green: 0.92, blue: 0.92),
        titleColor: Color = .gray,
        selectionColor: Color = .accentColor,
        deleteButtonEnabledColor: Color = .red,
        unsavedPlaceholderTintColor: Color = Color(red: 0.22, green: 0.24, blue: 0.28),
        titleFont: Font = .body.bold(),
        selectionBadgeFontSize: CGFloat = 22,
        unsavedPlaceholderIconFontSize: CGFloat = 44,
        unsavedPlaceholderFont: Font = .subheadline.weight(.medium),
        unsavedPlaceholderTextAlignment: TextAlignment = .center,
        itemTransitionScale: CGFloat = 0.85,
        itemAnimationDuration: TimeInterval = 0.3
    ) {
        self.titleBarHeight = titleBarHeight
        self.navigationBarHeight = navigationBarHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.columnSpacing = columnSpacing
        self.toolbarButtonSpacing = toolbarButtonSpacing
        self.preferredThumbnailWidth = preferredThumbnailWidth
        self.cornerRadius = cornerRadius
        self.thumbnailImagePadding = thumbnailImagePadding
        self.selectionBorderWidth = selectionBorderWidth
        self.selectionBadgeSize = selectionBadgeSize
        self.selectionBadgePadding = selectionBadgePadding
        self.unsavedPlaceholderSpacing = unsavedPlaceholderSpacing
        self.unsavedPlaceholderIconSize = unsavedPlaceholderIconSize
        self.unsavedPlaceholderTextPadding = unsavedPlaceholderTextPadding
        self.unsavedPlaceholderLineLimit = unsavedPlaceholderLineLimit
        self.unsavedPlaceholderMinimumScaleFactor = unsavedPlaceholderMinimumScaleFactor
        self.unsavedPlaceholderIconOpacity = unsavedPlaceholderIconOpacity
        self.backgroundColor = backgroundColor
        self.thumbnailBackgroundColor = thumbnailBackgroundColor
        self.titleColor = titleColor
        self.selectionColor = selectionColor
        self.deleteButtonEnabledColor = deleteButtonEnabledColor
        self.unsavedPlaceholderTintColor = unsavedPlaceholderTintColor
        self.titleFont = titleFont
        self.selectionBadgeFontSize = selectionBadgeFontSize
        self.unsavedPlaceholderIconFontSize = unsavedPlaceholderIconFontSize
        self.unsavedPlaceholderFont = unsavedPlaceholderFont
        self.unsavedPlaceholderTextAlignment = unsavedPlaceholderTextAlignment
        self.itemTransitionScale = itemTransitionScale
        self.itemAnimationDuration = itemAnimationDuration
    }
}
