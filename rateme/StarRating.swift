//
//  StarRating.swift
//  rateme
//
//  Created by Mathieu Dutour on 20/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class StarRating: UIView {
    var rating = 0 {
        didSet {
            setNeedsLayout()
        }
    }
    var ratingButtons: [StarButton] = []

    let starCount = 5
    let spacing = 0
    let buttonSize = 60

    @objc func ratingButtonTapped(button: StarButton) {
        rating = ratingButtons.index(of: button)! + 1
        updateButtonSelectionStates()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        for _ in 0..<starCount {
            let button = StarButton(frame: CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize), image: UIImage(named: "star.png"))
            button.imageColorOn = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.circleColor = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.lineColor = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.backgroundColor = UIColor.clear
            button.addTarget(self, action: #selector(ratingButtonTapped(button:)), for: .touchDown)
            ratingButtons.append(button)
            addSubview(button)
        }
    }

    override func layoutSubviews() {
        // Set the button's width and height to a square the size of the frame's height.
        let buttonSize = Int(frame.size.height)
        var buttonFrame = CGRect(x: 0, y: 0, width: buttonSize, height: buttonSize)

        // Offset each button's origin by the length of the button plus some spacing.
        for (index, button) in ratingButtons.enumerated() {
            buttonFrame.origin.x = CGFloat(index * (buttonSize + spacing))
            button.frame = buttonFrame
        }

        updateButtonSelectionStates()
    }

    private func updateButtonSelectionStates() {
        for (index, button) in ratingButtons.enumerated() {
            if index >= rating {
                if button.isSelected {
                    button.deselect()
                }
            } else {
                if !button.isSelected {
                    button.select(animated: index == rating - 1)
                }
            }
        }
    }
}
