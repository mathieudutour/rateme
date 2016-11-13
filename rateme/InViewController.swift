//
//  InViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class InViewController: UIViewController, Subscriber {
    var identifier = generateIdentifier()
    var discovery: Discovery?
    var users: NSArray?

    @IBOutlet weak var score: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        State.sharedInstance.subscribe(listener: self)
    }
    
    deinit {
        State.sharedInstance.unsubscribe(listener: self)
    }
    
    func update(state: State) {
        score.text = "\(state.currentUser!["score"])"
    }
    
}
