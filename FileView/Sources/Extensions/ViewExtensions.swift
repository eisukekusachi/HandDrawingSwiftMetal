//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import SwiftUI

extension View {
    /// Runs `action` only once for the lifetime of this view identity
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
    }

    /// Disables the control and shows it in gray when `isDisabled` is true.
    public func grayedOutWhenDisabled(
        _ isDisabled: Bool,
        enabledColor: Color = Color.accentColor,
        disabledColor: Color = Color.gray.opacity(0.35)
    ) -> some View {
        disabled(isDisabled)
            .foregroundStyle(isDisabled ? disabledColor : enabledColor)
    }

    /// Cancel + destructive action confirmation alert.
    func alertDestructiveConfirmation(
        title: String,
        message: String,
        destructiveButtonTitle: String,
        cancelButtonTitle: String,
        isPresented: Binding<Bool>,
        onDestructive: @escaping () -> Void
    ) -> some View {
        modifier(
            DestructiveConfirmAlertModifier(
                title: title,
                message: message,
                destructiveButtonTitle: destructiveButtonTitle,
                cancelButtonTitle: cancelButtonTitle,
                isPresented: isPresented,
                onDestructive: onDestructive
            )
        )
    }

    /// Alert with a single-line `TextField`, Cancel, and a confirm button.
    func alertWithTextField(
        title: String,
        textFieldPrompt: String,
        message: String,
        confirmButtonTitle: String,
        cancelButtonTitle: String,
        text: Binding<String>,
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            TextFieldAlertModifier(
                title: title,
                textFieldPrompt: textFieldPrompt,
                message: message,
                text: text,
                isPresented: isPresented,
                confirmButtonTitle: confirmButtonTitle,
                cancelButtonTitle: cancelButtonTitle,
                onConfirm: onConfirm
            )
        )
    }
}

// MARK: - Modifiers

private struct OnFirstAppearModifier: ViewModifier {
    @State private var didAppear = false
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !didAppear else { return }
                didAppear = true
                action()
            }
    }
}

private struct DestructiveConfirmAlertModifier: ViewModifier {
    let title: String
    let message: String
    let destructiveButtonTitle: String
    let cancelButtonTitle: String
    @Binding var isPresented: Bool
    let onDestructive: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(cancelButtonTitle, role: .cancel) {}
                Button(destructiveButtonTitle, role: .destructive) { onDestructive() }
            } message: {
                Text(message)
            }
    }
}

private struct TextFieldAlertModifier: ViewModifier {
    let title: String
    let textFieldPrompt: String
    let message: String
    @Binding var text: String
    @Binding var isPresented: Bool
    let confirmButtonTitle: String
    let cancelButtonTitle: String
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                TextField(textFieldPrompt, text: $text)
                Button(cancelButtonTitle, role: .cancel) {}
                Button(confirmButtonTitle) { onConfirm() }
            } message: {
                Text(message)
            }
    }
}
