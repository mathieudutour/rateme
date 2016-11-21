//
//  ICouldUnavailableViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class ICouldUnavailableViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func openSettings(_ sender: Any) {
        UIApplication.shared.open(NSURL(string:"Prefs:root=CASTLE")! as URL, completionHandler: { (success) in
            print("Settings opened: \(success)") // Prints true
        })
    }
}
