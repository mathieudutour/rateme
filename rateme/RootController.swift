//
//  ViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class RootController: UINavigationController, Subscriber, CAAnimationDelegate {
    var identifier = generateIdentifier()
    var gradient : CAGradientLayer?
    var toColors = [UIColor(red: 0.949, green: 0.89, blue: 0.88, alpha: 1.0).cgColor, UIColor(red: 0.949, green: 0.89, blue: 0.88, alpha: 1.0).cgColor]
    var fromColors = [UIColor(red:0.99, green:0.88, blue:0.84, alpha:1.0).cgColor, UIColor(red:0.99, green:0.88, blue:0.84, alpha:1.0).cgColor]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationBarHidden(true, animated: false)
        State.sharedInstance.subscribe(listener: self)
    }
    
    deinit {
        State.sharedInstance.unsubscribe(listener: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.gradient = CAGradientLayer()
        self.gradient?.frame = self.view.bounds
        self.gradient?.colors = self.fromColors
        self.view.layer.addSublayer(self.gradient!)
        
        self.animateLayer()
    }
    
    func update(state: State) {
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        if (state.loading) {
            self.pushViewController(storyboard.instantiateViewController(withIdentifier: "Loading"), animated: false)
        } else if (state.icloudUnavailable) {
            self.pushViewController(storyboard.instantiateViewController(withIdentifier: "iCouldUnavailable"), animated: false)
        } else if (!state.loggedin) {
            self.pushViewController(storyboard.instantiateViewController(withIdentifier: "Signup"), animated: false)
        } else if (state.loggedin) {
            self.pushViewController(storyboard.instantiateViewController(withIdentifier: "In"), animated: false)
        }
    }
    
    func animateLayer () {
        self.gradient?.colors = self.toColors
        
        let animation = CABasicAnimation(keyPath: "colors")
        
        animation.fromValue = self.fromColors
        animation.toValue = self.toColors
        animation.duration = 3.00
        animation.isRemovedOnCompletion = true
        animation.fillMode = kCAFillModeForwards
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        animation.delegate = self
        
        self.gradient?.add(animation, forKey:"animateGradient")
    }
    
    func animationDidStop(_ anim: CAAnimation, finished: Bool) {
        if finished {
            self.toColors = self.fromColors;
            self.fromColors = self.gradient?.colors as! [CGColor]
            animateLayer()
        }
    }
}

