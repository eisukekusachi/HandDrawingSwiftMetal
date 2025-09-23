//
//  Toast.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/26.
//

import CanvasView
import UIKit

class Toast: UIView {

    private let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont(name: "Helvetica", size: 16.0)
        label.textColor = .white
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .vertical)
        label.setContentCompressionResistancePriority(UILayoutPriority(1000), for: .horizontal)
        return label
    }()

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = .white
        return view
    }()

    private var startDelay: Double = 0.0
    private var startDuration: Double = 0.15

    private var duration: Double = 2.0

    private var endDelay: Double = 0.0
    private var endDuration: Double = 0.2

    private var topAnchorForHidingView: NSLayoutConstraint?

    private var isRemoving: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        addSubview(label)
        addSubview(imageView)

        translatesAutoresizingMaskIntoConstraints = false

        let margin: CGFloat = 18.0
        let iconSize: CGFloat = 28.0

        NSLayoutConstraint.activate([
            imageView.leftAnchor.constraint(equalTo: leftAnchor, constant: margin),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: iconSize),
            imageView.heightAnchor.constraint(equalToConstant: iconSize),

            label.topAnchor.constraint(equalTo: topAnchor, constant: margin),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -margin),
            label.leftAnchor.constraint(equalTo: imageView.rightAnchor, constant: margin),
            label.rightAnchor.constraint(equalTo: rightAnchor, constant: -margin),
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: iconSize)
        ])

        backgroundColor = UIColor.init(white: 0.0, alpha: 0.78)

        alpha = 0.0
        layer.cornerRadius = 8.0
        layer.masksToBounds = true

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapView)))
    }

    override func layoutSubviews() {
        guard let parentView = getParentViewController(self)?.view else { return }

        if topAnchorForHidingView == nil {

            NSLayoutConstraint.activate([
                centerXAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.centerXAnchor),
                widthAnchor.constraint(equalTo: parentView.widthAnchor, multiplier: 0.8)
            ])

            let bottomOffset: CGFloat = -8.0

            let bottomConstraint = bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.bottomAnchor, constant: bottomOffset)
            bottomConstraint.priority = UILayoutPriority(750)
            bottomConstraint.isActive = true

            topAnchorForHidingView = topAnchor.constraint(equalTo: parentView.bottomAnchor)
            topAnchorForHidingView?.priority = UILayoutPriority(999)
            topAnchorForHidingView?.isActive = true

            parentView.layoutIfNeeded()

            showTemporarily()
        }
    }
}

extension Toast {
    func showMessage(_ model: CanvasMessage) {
        label.text = model.title
        imageView.image = model.icon
        duration = model.duration
    }
}

extension Toast {
    @objc
    private func tapView() {
        removeViewWithAnimation()
    }

    private func showTemporarily() {
        guard let parentView = getParentViewController(self)?.view else { return }

        // Show the toast.
        topAnchorForHidingView?.isActive = false

        UIView.animate(withDuration: startDuration, delay: startDelay, options: .curveEaseIn, animations: { [weak self] in
            self?.alpha = 1.0
            parentView.layoutIfNeeded()
        })

        // Hide the toast.
        DispatchQueue.main.asyncAfter(deadline: .now() + (startDuration + startDelay + duration)) { [weak self] in
            self?.removeViewWithAnimation()
        }
    }
    private func removeViewWithAnimation() {
        guard !isRemoving, let parentView = getParentViewController(self)?.view else { return }
        isRemoving = true

        self.topAnchorForHidingView?.isActive = true

        UIView.animate(withDuration: endDuration, delay: endDelay, options: .curveEaseOut, animations: { [weak self] in
            self?.alpha = 0.0
            parentView.layoutIfNeeded()
        },
        completion: { [weak self] _ in
            self?.removeFromSuperview()
        })
    }

    private func getParentViewController(_ view: UIView) -> UIViewController? {
        var parentResponder: UIResponder? = view
        while true {
            guard let nextResponder = parentResponder?.next else { return nil }
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            parentResponder = nextResponder
        }
    }
}
