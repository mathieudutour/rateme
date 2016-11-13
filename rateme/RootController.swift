//
//  ViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

class ViewController: UINavigationController, Subscriber {
    var identifier = generateIdentifier()

    override func viewDidLoad() {
        super.viewDidLoad()
        State.sharedInstance.subscribe(listener: self)
    }
    
    deinit {
        State.sharedInstance.unsubscribe(listener: self)
    }
    
    func update(state: State) {
        print("Updating switches")
        
    }

}

