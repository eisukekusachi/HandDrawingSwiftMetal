//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import FileView
import SwiftUI
import UIKit

extension HandDrawingViewController {
    func showFileView() {
        let fileView = FileView(
            fileList: viewModel.fileList,
            eventHandler: .init(
                onTapCreate: { [weak self] in self?.createFile() },
                onTapRename: { [weak self] index, newName in self?.renameFile(index, newName) },
                onTapDelete: { [weak self] index in self?.deleteFile(index) },
                onSelectItem: { [weak self] zipFileURL in self?.selectFile(zipFileURL) }
            ),
            currentOpenFileURL: viewModel.zipFileURL
        )

        let vc = UIHostingController(rootView: fileView)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(vc, animated: true)
    }
}

private extension HandDrawingViewController {
    func createFile() {
        viewModel.showActivityIndicator(true)
        Task { @MainActor in
            defer { viewModel.showActivityIndicator(false) }

            do {
                let zipFileURL = try await viewModel.onTapNewCanvas(
                    fileName: Calendar.currentDate,
                    device: sharedDevice,
                    commandQueue: canvasView.sharedCommandQueue
                )
                try await viewModel.loadCanvas(
                    device: sharedDevice,
                    zipFileURL: zipFileURL
                )
                try await initializeCanvas(viewModel.textureSize)
                updateDrawingComponents()
                presentedViewController?.dismiss(animated: true)
                showToast(.success)
            } catch {
                showAlert(error)
            }
        }
    }

    func renameFile(_ index: Int, _ newName: String) -> String? {
        do {
            return try viewModel.onTapRenameFile(index, newName)
        } catch {
            showAlert(error)
            return nil
        }
    }

    func deleteFile(_ index: Int) {
        viewModel.showActivityIndicator(true)
        Task { @MainActor in
            defer { viewModel.showActivityIndicator(false) }

            do {
                let didInitializeCanvas = try await viewModel.onTapDeleteFile(
                    index: index,
                    device: sharedDevice,
                    commandQueue: canvasView.sharedCommandQueue
                )
                guard didInitializeCanvas else { return }

                try await initializeCanvas(viewModel.textureSize)
                textureLayerView.update(
                    viewModel.textureLayersState
                )
                updateDrawingComponents()
                presentedViewController?.dismiss(animated: true)
            } catch {
                showAlert(error)
            }
        }
    }

    func selectFile(_ zipFileURL: URL) {
        loadCanvas(zipFileURL: zipFileURL)
        presentedViewController?.dismiss(animated: true)
    }
}
