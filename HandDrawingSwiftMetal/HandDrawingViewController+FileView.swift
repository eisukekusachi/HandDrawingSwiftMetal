//
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import Core
import FileView
import SwiftUI
import UIKit

extension HandDrawingViewController {
    func showFileView() {
        let fileView = FileView(
            fileList: viewModel.fileList,
            eventHandler: .init(
                onTapCreate: { [weak self] in self?.onTapCreate() },
                onTapRename: { [weak self] index, newName in self?.onTapRename(index, newName) },
                onTapDelete: { [weak self] index in self?.onTapDelete(index) },
                onSelectItem: { [weak self] zipFileURL in self?.onSelectItem(zipFileURL) }
            ),
            currentOpenFileURL: viewModel.zipFileURL(
                projectName: viewModel.project.currentProjectName
            )
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
    func onTapCreate() {
        Task {
            do {
                try await viewModel.createFile(
                    fileName: Calendar.currentDate,
                    device: sharedDevice,
                    commandQueue: canvasView.sharedCommandQueue
                )
                presentedViewController?.dismiss(animated: true)
            } catch {
                showAlert(error)
            }
        }
    }

    func onTapRename(_ index: Int, _ newName: String) -> String? {
        viewModel.renameFile(index: index, newName: newName)
    }

    func onTapDelete(_ index: Int) {
        Task {
            let dismissesFileView = viewModel.isOpenFile(at: index)
            do {
                try await viewModel.deleteFile(
                    index: index,
                    device: sharedDevice,
                    commandQueue: canvasView.sharedCommandQueue
                )
                if dismissesFileView {
                    presentedViewController?.dismiss(animated: true)
                }
            } catch {
                showAlert(error)
            }
        }
    }

    func onSelectItem(_ zipFileURL: URL) {
        Task {
            do {
                try await viewModel.loadFile(
                    device: sharedDevice,
                    zipFileURL: zipFileURL
                )
                presentedViewController?.dismiss(animated: true)
            } catch {
                showAlert(error)
            }
        }
    }
}
