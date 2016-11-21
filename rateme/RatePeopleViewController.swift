//
//  RatePeopleViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 20/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import AVFoundation

class RatePeopleViewController: UIViewController, UIGestureRecognizerDelegate {
    var userToRate: BLEUser? {
        didSet {
            username.text = userToRate?.record?["username"] as! String?
        }
    }

    var swooshSound = NSURL(fileURLWithPath: Bundle.main.path(forResource: "swoosh", ofType: "mp3")!)
    var audioPlayer = AVAudioPlayer()

    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var starRating: StarRating!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: swooshSound as URL)
        } catch {

        }
        audioPlayer.prepareToPlay()
    }

    @IBAction func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
        if starRating.rating > 0 {
            Redux.sharedInstance.rate(iCloudId: (userToRate?.iCloudID)!, rating: starRating.rating)
            audioPlayer.play()
            self.navigationController?.popViewController(animated: true)
        } else {
            // TODO shake
        }
    }
}
