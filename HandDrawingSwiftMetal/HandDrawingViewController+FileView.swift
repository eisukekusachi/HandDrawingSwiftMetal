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
                onTapCreate: { [weak self] in
                    guard let self else { return }
                    Task {
                        await self.viewModel.createFile(
                            fileName: Calendar.currentDate,
                            device: self.sharedDevice,
                            commandQueue: self.canvasView.sharedCommandQueue
                        )
                    }
                },
                onTapRename: { [weak self] index, newName in
                    self?.viewModel.renameFile(index: index, newName: newName)
                },
                onTapDelete: { [weak self] index in
                    guard let self else { return }
                    Task {
                        await self.viewModel.deleteFile(
                            index: index,
                            device: self.sharedDevice,
                            commandQueue: self.canvasView.sharedCommandQueue
                        )
                    }
                },
                onSelectItem: { [weak self] zipFileURL in
                    guard let self else { return }
                    Task {
                        await self.viewModel.selectFile(
                            device: self.sharedDevice,
                            zipFileURL: zipFileURL
                        )
                    }
                }
            ),
            currentOpenFileURL: viewModel.currentZipFileURL
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
