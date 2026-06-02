//
//  PopupViewModelTests.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import Testing
import UIKit
@testable import HandDrawingSwiftMetal

@MainActor
struct PopupViewModelTests {

    typealias Subject = PopupViewModel

    @Suite
    @MainActor
    struct `Popup Rect Top Placement` {
        @Test
        func `Places popup below anchor centered when it fits in container`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 150, y: 0),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: 10,
                placement: .top
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // The popup stays horizontally centered on the anchor
            #expect(result.midX == buttonRect.midX)
            // With .top placement, the popup sits below the target
            #expect(result.minY == buttonRect.minY + buttonRect.height + targetSpacing)
            // Horizontal position stays aligned to the anchor center
            #expect(result.minX == buttonRect.midX - popupSize.width / 2)
            #expect(result.maxX == buttonRect.midX + popupSize.width / 2)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= 400)
        }

        @Test
        func `Places popup below anchor and corrects leading overflow at top leading`() {
            let popupSize: CGSize = CGSize(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 20, y: 0),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let horizontalPadding: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: horizontalPadding,
                placement: .top
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // Centering on the anchor would cross the leading inset
            #expect(buttonRect.midX - popupSize.width / 2 == -30)

            // The popup is shifted so its leading edge meets the leading inset
            #expect(result.minX == horizontalPadding)
            // With .top placement, the popup sits below the target
            #expect(result.minY == buttonRect.minY + buttonRect.height + targetSpacing)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= 400)
        }

        @Test
        func `Places popup below anchor and corrects trailing overflow at top trailing`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 360, y: 0),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let horizontalPadding: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: horizontalPadding,
                placement: .top
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // Centering on the anchor would cross the trailing edge of the container
            #expect(buttonRect.midX + popupSize.width / 2 == 510)

            // The popup is shifted so its trailing edge meets the trailing inset
            #expect(result.maxX == containerWidth - horizontalPadding)
            // With .top placement, the popup sits below the target
            #expect(result.minY == buttonRect.minY + buttonRect.height + targetSpacing)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= containerWidth)
        }

        @Test
        func `Keeps popup within container when container is narrower than popup and padding`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 10, y: 0),
                size: .init(width: 20, height: 20)
            )
            let containerWidth: CGFloat = 120

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: 8,
                horizontalPadding: 16,
                placement: .top
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // When the popup can't fit, keep the leading edge within the container to avoid a negative x.
            #expect(result.minX >= 0)
        }
    }

    @Suite
    @MainActor
    struct `Popup Rect Bottom Placement` {
        @Test
        func `Places popup above anchor centered when it fits in container`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 150, y: 200),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: 10,
                placement: .bottom
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // The popup stays horizontally centered on the anchor
            #expect(result.midX == buttonRect.midX)
            // With .bottom placement, the popup sits above the target
            #expect(result.maxY == buttonRect.minY - targetSpacing)
            // Horizontal position stays aligned to the anchor center
            #expect(result.minX == buttonRect.midX - popupSize.width / 2)
            #expect(result.maxX == buttonRect.midX + popupSize.width / 2)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= containerWidth)
        }

        @Test
        func `Places popup above anchor and corrects leading overflow at bottom leading`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 20, y: 200),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let horizontalPadding: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: horizontalPadding,
                placement: .bottom
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // Centering on the anchor would cross the leading inset
            #expect(buttonRect.midX - popupSize.width / 2 == -30)

            // The popup is shifted so its leading edge meets the leading inset.
            #expect(result.minX == horizontalPadding)
            // With .bottom placement, the popup sits above the target
            #expect(result.maxY == buttonRect.minY - targetSpacing)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= containerWidth)
        }

        @Test
        func `Places popup above anchor and corrects trailing overflow at bottom trailing`() {
            let popupSize: CGSize = .init(width: 200, height: 100)
            let buttonRect: CGRect = .init(
                origin: .init(x: 360, y: 200),
                size: .init(width: 100, height: 20)
            )
            let targetSpacing: CGFloat = 10
            let horizontalPadding: CGFloat = 10
            let containerWidth: CGFloat = 400

            let subject: Subject = .init(
                size: popupSize,
                targetSpacing: targetSpacing,
                horizontalPadding: horizontalPadding,
                placement: .bottom
            )
            subject.targetFrame = buttonRect

            let result = subject.popupRect(
                containerWidth: containerWidth
            )

            // Centering on the anchor would cross the trailing edge of the container
            #expect(buttonRect.midX + popupSize.width / 2 == 510)

            // The popup is shifted so its trailing edge meets the trailing inset.
            #expect(result.maxX == containerWidth - horizontalPadding)
            // With .bottom placement, the popup sits above the target
            #expect(result.maxY == buttonRect.minY - targetSpacing)

            // The popup stays within the container horizontal insets
            #expect(result.minX >= 0)
            #expect(result.maxX <= containerWidth)
        }
    }

    @Suite
    @MainActor
    struct `Hide Popup` {
        @Test
        func `Default initializer hides the popup`() {
            let subject: Subject = .init(
                size: TestHelpers.randomSize(),
                placement: .top
            )

            #expect(subject.isHidden == true)
        }

        @Test(
            arguments: [true, false]
        )
        func `toggleView flips isHidden`(initialState: Bool) {
            let subject: Subject = .init(
                size: TestHelpers.randomSize(),
                placement: .top,
                isHidden: initialState
            )

            subject.toggleView()
            #expect(subject.isHidden == !initialState)

            subject.toggleView()
            #expect(subject.isHidden == initialState)
        }

        @Test
        func `hide sets isHidden to true`() {
            let subject: Subject = .init(
                size: TestHelpers.randomSize(),
                placement: .top,
                isHidden: false
            )

            subject.hide()

            #expect(subject.isHidden == true)
        }
    }

    @Suite
    @MainActor
    struct `Enable Component Interaction` {
        @Test
        func `enableComponentInteraction updates isUserInteractionEnabled`() {
            let subject: Subject = .init(
                size: TestHelpers.randomSize(),
                placement: .top
            )

            subject.enableComponentInteraction(false)
            #expect(subject.isUserInteractionEnabled == false)

            subject.enableComponentInteraction(true)
            #expect(subject.isUserInteractionEnabled == true)
        }
    }
}
