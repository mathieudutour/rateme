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
    var toColors = [
        UIColor(red: 0.949, green: 0.89, blue: 0.88, alpha: 1.0).cgColor,
        UIColor(red: 0.949, green: 0.89, blue: 0.88, alpha: 1.0).cgColor
    ]
    var fromColors = [
        UIColor(red:0.99, green:0.88, blue:0.84, alpha:1.0).cgColor,
        UIColor(red:0.99, green:0.88, blue:0.84, alpha:1.0).cgColor
    ]

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.gradient.frame = self.bounds
        self.gradient.colors = self.fromColors
        self.layer.insertSublayer(self.gradient, at: 0)

        self.backgroundColor = UIColor(red: 0.949, green: 0.89, blue: 0.88, alpha: 1.0)

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
