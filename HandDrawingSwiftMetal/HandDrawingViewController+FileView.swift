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
            eventHandler: FileViewEventHandler(
                onTapCreate: { [weak self] in
                    self?.viewModel.onTapCreate()
                },
                onTapRename: { [weak self] index, newName in
                    self?.viewModel.onTapRename(index, newName)
                },
                onTapDelete: { [weak self] index in
                    self?.viewModel.onTapDeleteFile(index)
                },
                onSelectItem: { [weak self] zipFileURL in
                    self?.viewModel.onSelectFile(zipFileURL)
                }
            ),
            currentOpenFileURL: viewModel.fileURL(
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