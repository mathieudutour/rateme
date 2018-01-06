//
//  StarRating.swift
//  rateme
//
//  Created by Mathieu Dutour on 20/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

let spacing = 0
let buttonSize = 60

class StarRating: UIStackView {
    var rating = 0 {
        didSet {
            setNeedsLayout()
        }
    }
    var ratingButtons: [StarButton] = []

    @objc func ratingButtonTapped(button: StarButton) {
        rating = ratingButtons.index(of: button)! + 1
        updateButtonSelectionStates()
    }

    public convenience init(starCount: Int) {
        self.init()
        
        self.axis = .horizontal
        self.alignment = .center
        self.distribution = .fillEqually
        self.spacing = 0

        for i in 0..<starCount {
            let button = StarButton(frame: CGRect(x: i * buttonSize, y: 0, width: buttonSize, height: buttonSize), image: UIImage(named: "star.png"))
            button.imageColorOn = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.circleColor = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.lineColor = UIColor(red:0.36, green:0.21, blue:0.44, alpha:1.0)
            button.backgroundColor = UIColor.clear
            button.heightAnchor.constraint(equalToConstant: CGFloat(buttonSize)).isActive = true
            button.addTarget(self, action: #selector(ratingButtonTapped(button:)), for: .touchDown)
            ratingButtons.append(button)
            addArrangedSubview(button)
        }
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
