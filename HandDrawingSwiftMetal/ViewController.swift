//
//  ViewController.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2021/11/27.
//

import UIKit
class ViewController: UIViewController {
    private lazy var canvas: Canvas = {
        let view = Canvas()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private lazy var brushButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setTitle("Brush", for: .normal)
        view.setTitleColor(.gray, for: .normal)
        return view
    }()
    private lazy var eraserButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setTitle("Eraser", for: .normal)
        view.setTitleColor(.gray, for: .normal)
        return view
    }()
    private lazy var clearButton: UIButton = {
        let view = UIButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setTitle("Clear", for: .normal)
        view.setTitleColor(.gray, for: .normal)
        return view
    }()
    private lazy var stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alignment = .center
        view.distribution = .equalSpacing
        return view
    }()
    private lazy var diameterSliderView: VerticalSliderView = {
        let view = VerticalSliderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.tintColor = .lightGray
        return view
    }()
    private let maxDiameter: Float = 44.0
    override func viewDidLoad() {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        view.addSubview(canvas)
        view.addSubview(stackView)
        view.addSubview(diameterSliderView)
        stackView.addArrangedSubview(brushButton)
        stackView.addArrangedSubview(eraserButton)
        stackView.addArrangedSubview(clearButton)
        NSLayoutConstraint.activate([
            canvas.leftAnchor.constraint(equalTo: view.leftAnchor),
            canvas.topAnchor.constraint(equalTo: view.topAnchor),
            canvas.rightAnchor.constraint(equalTo: view.rightAnchor),
            canvas.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 12),
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            diameterSliderView.bottomAnchor.constraint(equalTo: stackView.topAnchor, constant: -24),
            diameterSliderView.widthAnchor.constraint(equalToConstant: 44),
            diameterSliderView.heightAnchor.constraint(equalToConstant: 120)
        ])
        brushButton.addTarget(self, action: #selector(selectBrush), for: .touchUpInside)
        eraserButton.addTarget(self, action: #selector(selectEraser), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearCanvas), for: .touchUpInside)
        diameterSliderView.slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        selectBrush()
    }
    @objc func selectBrush() {
        canvas.tool = 0
        diameterSliderView.slider.value = canvas.brushDiameter / maxDiameter
    }
    @objc func selectEraser() {
        canvas.tool = 1
        diameterSliderView.slider.value = canvas.eraserDiameter / maxDiameter
    }
    @objc func clearCanvas() {
        canvas.clearAllTextures()
        canvas.refreshCanvas()
    }
    @objc func sliderValueChanged(_ sender: UISlider) {
        if canvas.tool == 0 {
            canvas.brushDiameter = sender.value * maxDiameter
        } else if canvas.tool == 1 {
            canvas.eraserDiameter = sender.value * maxDiameter
        }
    }
}
class VerticalSliderView: UIView {
    let slider: UISlider = {
        let view = UISlider()
        view.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private lazy var sliderWidth: CGFloat = { frame.size.height }()
    private lazy var sliderHeight: CGFloat = { frame.size.width }()
    private var runOnce: Bool = false
    override func layoutSubviews() {
        if !runOnce && frame.size != .zero {
            runOnce = true
            addSubview(slider)
            NSLayoutConstraint.activate([
                slider.leftAnchor.constraint(equalTo: leftAnchor, constant: -sliderWidth * 0.5 + sliderHeight * 0.5),
                slider.topAnchor.constraint(equalTo: topAnchor, constant: sliderWidth * 0.5 - sliderHeight * 0.5),
                slider.widthAnchor.constraint(equalToConstant: sliderWidth),
                slider.heightAnchor.constraint(equalToConstant: sliderHeight)
            ])
        }
    }
}
