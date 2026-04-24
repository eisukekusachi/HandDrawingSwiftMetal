//
//  ViewExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/24.
//

import SwiftUI

extension View {
    /// Alert with a single-line `TextField`, Cancel, and a confirm button.
    func alertWithTextField(
        title: String,
        textFieldPrompt: String,
        message: String,
        confirmButtonTitle: String,
        cancelButtonTitle: String = "Cancel",
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

    /// Cancel + destructive action
    func alertDestructiveConfirmation(
        title: String,
        message: String,
        destructiveButtonTitle: String,
        cancelButtonTitle: String = "Cancel",
        isPresented: Binding<Bool>,
        onDestructive: @escaping () -> Void
    ) -> some View {
        modifier(
            DestructiveConfirmAlertModifier(
                title: title,
                message: message,
                isPresented: isPresented,
                destructiveButtonTitle: destructiveButtonTitle,
                cancelButtonTitle: cancelButtonTitle,
                onDestructive: onDestructive
            )
        )
    }

    /// Single dismiss button. `message` is read when the alert is shown.
    func alert(
        title: String,
        message: Binding<String>,
        buttonTitle: String = "OK",
        isPresented: Binding<Bool>
    ) -> some View {
        modifier(
            AcknowledgeAlertModifier(
                title: title,
                isPresented: isPresented,
                message: message,
                buttonTitle: buttonTitle
            )
        )
    }

    /// Runs `action` only once for the lifetime of this view identity
    func onFirstAppear(_ action: @escaping () -> Void) -> some View {
        modifier(OnFirstAppearModifier(action: action))
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

private struct DestructiveConfirmAlertModifier: ViewModifier {
    let title: String
    let message: String
    @Binding var isPresented: Bool
    let destructiveButtonTitle: String
    let cancelButtonTitle: String
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

private struct AcknowledgeAlertModifier: ViewModifier {
    let title: String
    @Binding var isPresented: Bool
    @Binding var message: String
    let buttonTitle: String

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                Button(buttonTitle, role: .cancel) {}
            } message: {
                Text($message.wrappedValue)
            }
    }
}
