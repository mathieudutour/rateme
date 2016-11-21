//
//  WaveHeader.swift
//  rateme
//
//  Created by Mathieu Dutour on 19/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

class WaveHeader: AnimatedBackground {
    var rootView: UIView?
    var lineLayers: [CAShapeLayer] = []

    var initialized = false
    var amplitudeIncrement = CGFloat(5)
    var maxAmplitude = CGFloat(60)
    var minAmplitude = CGFloat(0)
    var startingAmplitudes: [CGFloat] = []
    var waveLength: CGFloat = 0
    var finalX: CGFloat = 0
    var amplitudeArray: [CGFloat] = []
    var animating = false
    var waveCrestAnimations: [CAKeyframeAnimation] = []
    var waveCrestTimer = Timer()

    func initialize() {
        //find root view - the waves look weird if you go only by the size of the container
        //Also depending on how the view is initialized. You can find the root view in two ways.
        self.rootView = self.window?.subviews[0]
        if !(self.rootView != nil) {
            self.rootView = self
            while self.rootView?.superview != nil {
                self.rootView = self.rootView?.superview
            }
        }

        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        //default wave properties
        self.waveLength = (self.rootView?.frame.size.width)!
        self.finalX = 5 * self.waveLength

        //available amplitudes
        self.amplitudeArray = self.createAmplitudeOptions()

        self.clipsToBounds = true

        self.lineLayers = []
        self.startingAmplitudes = []
        for i in 0...2 {
            self.lineLayers.append(CAShapeLayer())
            self.lineLayers[i].fillColor = UIColor.white.cgColor
            self.lineLayers[i].strokeColor = UIColor.white.cgColor
            self.lineLayers[i].opacity = 0.5

            //creating a linelayer frame
            self.lineLayers[i].anchorPoint = CGPoint(x:0, y: 0)
            self.lineLayers[i].frame = CGRect(x: 0, y: self.frame.size.height - 30, width: self.finalX, height: (self.rootView?.frame.size.height)!)

            self.startingAmplitudes.append(CGFloat(arc4random_uniform(UInt32(60))))
        }

        //adding notification for when the app enters the foreground/background
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(stopAnimation),
                                               name: NSNotification.Name.UIApplicationDidEnterBackground,
                                               object: nil
        )

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(startAnimation),
                                               name: NSNotification.Name.UIApplicationWillEnterForeground,
                                               object: nil
        )

        startAnimation()

        initialized = true
    }

    func startAnimation() {
        if !self.animating {
            animateLayer()

            self.waveCrestAnimations = []

            for (i, layer) in self.lineLayers.enumerated() {
                //Phase Shift Animation
                let horizontalAnimation = CAKeyframeAnimation(keyPath: "position.x")

                horizontalAnimation.values = [(layer.position.x - self.waveLength * 2), (layer.position.x - self.waveLength)]

                horizontalAnimation.duration = CFTimeInterval(arc4random_uniform(UInt32(3)) + 3)
                horizontalAnimation.repeatCount = HUGE
                horizontalAnimation.isRemovedOnCompletion = false
                horizontalAnimation.fillMode = kCAFillModeForwards
                layer.add(horizontalAnimation, forKey: "horizontalAnimation")

                //Wave Crest Animations
                let waveCrestAnimation = CAKeyframeAnimation(keyPath: "path")
                waveCrestAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
                waveCrestAnimation.values = self.getBezierPathValues(index: i)
                waveCrestAnimation.duration = 2
                waveCrestAnimation.isRemovedOnCompletion = false
                waveCrestAnimation.fillMode = kCAFillModeForwards
                layer.add(waveCrestAnimation, forKey:"waveCrestAnimation")
                waveCrestAnimation.delegate = self

                self.waveCrestAnimations.append(waveCrestAnimation)

                self.layer.addSublayer(layer)
            }

            self.waveCrestTimer = Timer.scheduledTimer(timeInterval: 2,
                                                       target: self,
                                                       selector: #selector(updateWaveCrestAnimation),
                                                       userInfo: nil,
                                                       repeats: true)

            self.animating = true

            self.waveCrestTimer.fire()
        }
    }

    func stopAnimation() {
        print("stop animating")
        self.waveCrestTimer.invalidate()
        self.lineLayers.forEach({layer in
            layer.removeAnimation(forKey: "horizontalAnimation")
            layer.removeAnimation(forKey: "waveCestAnimation")
        })
        self.animating = false
    }

    private func createAmplitudeOptions() -> [CGFloat] {
        var tempAmplitudeArray: [CGFloat] = []
        var i = self.minAmplitude
        while i <= self.maxAmplitude {
            tempAmplitudeArray.append(i)
            i += self.amplitudeIncrement
        }
        return tempAmplitudeArray as [CGFloat]
    }

    private func getBezierPathValues(index: Int) -> [CGPath] {
        //creating wave starting point
        let startPoint = CGPoint(x: 0, y: 0)

        //grabbing random amplitude to shrink/grow to
        let randomIndex = NSNumber(value: arc4random_uniform(UInt32(self.amplitudeArray.count)))

        let finalAmplitude = self.amplitudeArray[randomIndex.intValue]
        var values: [CGPath] = []

        //shrinking
        if self.startingAmplitudes[index] >= finalAmplitude {
            var j = self.startingAmplitudes[index]
            while j >= finalAmplitude {
                //create a UIBezierPath along distance
                let line = UIBezierPath()
                line.move(to: CGPoint(x: startPoint.x, y: startPoint.y))

                var tempAmplitude = j
                var i = self.waveLength / 2
                while i <= self.finalX {
                    line.addQuadCurve(to: CGPoint(x: startPoint.x + i, y: startPoint.y), controlPoint:CGPoint(x: startPoint.x + i - (self.waveLength / 4), y: startPoint.y + tempAmplitude))
                    tempAmplitude = -tempAmplitude
                    i += self.waveLength / 2
                }

                line.addLine(to: CGPoint(x: self.finalX, y: 5 * (self.rootView?.frame.size.height)! - self.maxAmplitude))
                line.addLine(to: CGPoint(x: 0, y: 5 * (self.rootView?.frame.size.height)! - self.maxAmplitude))
                line.close()

                values.append(line.cgPath)

                j -= self.amplitudeIncrement
            }
        } else { //growing
            var j = self.startingAmplitudes[index]
            while j <= finalAmplitude {
                //create a UIBezierPath along distance
                let line = UIBezierPath()
                line.move(to: CGPoint(x: startPoint.x, y: startPoint.y))

                var tempAmplitude = j
                var i = self.waveLength / 2
                while i <= self.finalX {
                    line.addQuadCurve(to: CGPoint(x: startPoint.x + i, y: startPoint.y), controlPoint: CGPoint(x: startPoint.x + i - (self.waveLength / 4), y: startPoint.y + tempAmplitude))
                    tempAmplitude = -tempAmplitude
                    i += self.waveLength / 2
                }

                line.addLine(to: CGPoint(x: self.finalX, y: 5 * (self.rootView?.frame.size.height)! - self.maxAmplitude))
                line.addLine(to: CGPoint(x: 0, y: 5 * (self.rootView?.frame.size.height)! - self.maxAmplitude))
                line.close()

                values.append(line.cgPath)

                j += self.amplitudeIncrement
            }

        }

        self.startingAmplitudes[index] = finalAmplitude

        return values

    }

    @objc func updateWaveCrestAnimation(timer: Timer) {
        for (i, layer) in self.lineLayers.enumerated() {
            layer.removeAnimation(forKey: "waveCrestAnimation")
            self.waveCrestAnimations[i].values = self.getBezierPathValues(index: i)
            layer.add(self.waveCrestAnimations[i], forKey:"waveCrestAnimation")
        }
    }

    func updateWhenScrolling(tableView: UITableView) {
        var headerRect = CGRect(x: 0, y: -headerHeigh, width: tableView.bounds.width, height: headerHeigh)
        if tableView.contentOffset.y < -headerHeigh {
            headerRect.origin.y = tableView.contentOffset.y
            headerRect.size.height = -tableView.contentOffset.y
        }

        self.frame = headerRect
    }
}
