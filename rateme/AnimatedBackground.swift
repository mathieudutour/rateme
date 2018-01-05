//
//  AnimatedBackground.swift
//  rateme
//
//  Created by Mathieu Dutour on 20/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class AnimatedBackground: UIView, CAAnimationDelegate {
    var gradient = CAGradientLayer()
    // F2E3E0
    var toColors = [
        PINK.cgColor,
        PINK.cgColor
    ]
    // FCE3E0
    var fromColors = [
        SECONDARY_PINK.cgColor,
        SECONDARY_PINK.cgColor
    ]

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.gradient.frame = self.bounds
        self.gradient.colors = self.fromColors
        self.layer.insertSublayer(self.gradient, at: 0)

        // F2E3E0
        self.backgroundColor = PINK

        animateLayer()
    }

    func animateLayer () {
        self.gradient.colors = self.toColors

        let animation = CABasicAnimation(keyPath: "colors")

        animation.fromValue = self.fromColors
        animation.toValue = self.toColors
        animation.duration = 3.00
        animation.isRemovedOnCompletion = true
        animation.fillMode = kCAFillModeForwards
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.delegate = self

        self.gradient.add(animation, forKey:"animateGradient")
    }

    func animationDidStop(_ anim: CAAnimation, finished: Bool) {
        if finished {
            self.toColors = self.fromColors
            self.fromColors = self.gradient.colors as! [CGColor]
            animateLayer()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.gradient.frame = self.bounds
    }
}
