//
//  PopupView
//
//  Created by Eisuke Kusachi on 2026/08/22.
//

import CoreGraphics
import Testing
@testable import PopupView

@Suite(.serialized)
@MainActor
struct PopupViewModelTests {
    private typealias Subject = PopupViewModel

    @MainActor
    struct Visibility {
        @Test
        func `Verify that show() stays concealed until the reveal delay elapses`() async throws {
            let subject = Subject()

            subject.show()

            // The popup is present but not visible.
            #expect(!subject.isHidden)
            #expect(subject.isConcealed)

            await Task.yield()

            // The popup is still present but not visible.
            #expect(subject.isConcealed)

            // Default reveal delay is 10ms. Sleep past it, then yield so the
            // MainActor reveal Task can set isConcealed before we assert.
            try await Task.sleep(nanoseconds: 50_000_000)
            await Task.yield()

            // The popup is visible.
            #expect(!subject.isConcealed)
        }

        @Test
        func `Verify that show() with a zero reveal delay is not concealed`() {
            let subject = Subject(
                revealDelayNanoseconds: 0
            )

            subject.show()

            // The popup is present and visible.
            #expect(!subject.isHidden)
            #expect(!subject.isConcealed)
        }

        @Test
        func `Verify that show(immediately: true) is not concealed without waiting and ignores the reveal delay`() {
            let subject = Subject(
                revealDelayNanoseconds: 1_000_000_000
            )

            subject.show(immediately: true)

            // The popup is present and visible immediately.
            #expect(!subject.isHidden)
            #expect(!subject.isConcealed)
        }

        @Test
        func `Verify that isHidden: false is visible without calling show()`() {
            let subject = Subject(isHidden: false)

            #expect(!subject.isHidden)
            #expect(!subject.isConcealed)
        }

        @Test
        func `Verify that the default initializer stays hidden and concealed`() {
            let subject = Subject()

            #expect(subject.isHidden)
            #expect(subject.isConcealed)
        }

        @Test
        func `Verify that hide() hides the popup`() {
            let subject = Subject()

            subject.show(immediately: true)
            subject.hide()

            #expect(subject.isHidden)
            #expect(subject.isConcealed)
        }
    }

    @MainActor
    struct Placement {
        private let containerWidth: CGFloat = 500
        private let containerHeight: CGFloat = 500

        @Test
        func `Verify that aboveAnchor places the popup above the target`() {
            let target = CGRect(
                x: 0,
                y: 400,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .aboveAnchor
            )

            #expect(rect.maxY == target.minY - subject.targetSpacing)
        }

        @Test
        func `Verify that belowAnchor places the popup below the target`() {
            let target = CGRect(
                x: 0,
                y: 50,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .belowAnchor
            )

            #expect(rect.minY == target.maxY + subject.targetSpacing)
        }

        @Test
        func `Verify that aboveAnchor clamps the popup to the top of the container`() {
            let target = CGRect(
                x: 0,
                y: 50,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .aboveAnchor
            )

            #expect(rect.minY == 0)
        }

        @Test
        func `Verify that belowAnchor clamps the popup to the bottom of the container`() {
            let target = CGRect(
                x: 0,
                y: 400,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .belowAnchor
            )

            #expect(rect.maxY == containerHeight)
        }

        @Test
        func `Verify that the popup is centered on the target horizontally`() {
            let target = CGRect(
                x: 200,
                y: 200,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .aboveAnchor
            )

            #expect(rect.midX == target.midX)
        }

        @Test
        func `Verify that the popup is clamped to the left of the container`() {
            let target = CGRect(
                x: 0,
                y: 200,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .aboveAnchor
            )

            #expect(rect.minX == subject.horizontalPadding)
        }

        @Test
        func `Verify that the popup is clamped to the right of the container`() {
            let target = CGRect(
                x: 400,
                y: 200,
                width: 100,
                height: 50
            )
            let subject = Subject(width: 200)
            subject.setTargetFrame(target)
            subject.updateMeasuredHeight(200)

            let rect = subject.popupRect(
                containerWidth: containerWidth,
                containerHeight: containerHeight,
                placement: .aboveAnchor
            )

            #expect(rect.maxX == containerWidth - subject.horizontalPadding)
        }
    }
}
