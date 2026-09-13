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
        let fileList = viewModel.makeFileList()

        let fileView = FileView(
            fileList: fileList,
            eventHandler: .init(
                onTapCreate: { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        do {
                            let zipFileURL = try await self.viewModel.onTapNewCanvas(
                                fileList,
                                fileName: Calendar.currentDate,
                                device: self.sharedDevice,
                                commandQueue: self.canvasView.sharedCommandQueue
                            )
                            self.loadCanvas(zipFileURL: zipFileURL)
                            self.presentedViewController?.dismiss(animated: true)
                        } catch {
                            self.showAlert(error)
                        }
                    }
                },
                onTapRename: { [weak self] index, newName in
                    guard let self else { return nil }
                    return self.viewModel.onTapRenameFile(
                        fileList,
                        index: index,
                        newName: newName
                    )
                },
                onTapDelete: { [weak self] index in
                    guard let self else { return }
                    Task { @MainActor in
                        do {
                            let didInitializeCanvas = try await self.viewModel.onTapDeleteFile(
                                fileList,
                                index: index,
                                device: self.sharedDevice,
                                commandQueue: self.canvasView.sharedCommandQueue
                            )
                            guard didInitializeCanvas else { return }

                            try await self.initializeCanvas(self.viewModel.textureSize)
                            self.textureLayerView.update(
                                self.viewModel.textureLayersState
                            )
                            self.updateDrawingComponents()
                            self.presentedViewController?.dismiss(animated: true)
                        } catch {
                            self.showAlert(error)
                        }
                    }
                },
                onSelectItem: { [weak self] zipFileURL in
                    guard let self else { return }
                    self.loadCanvas(zipFileURL: zipFileURL)
                    self.presentedViewController?.dismiss(animated: true)
                }
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
