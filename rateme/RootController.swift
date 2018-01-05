//
//  ViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class RootController: UINavigationController, Subscriber {
    var identifier = Redux.generateIdentifier()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setNavigationBarHidden(true, animated: false)
        Redux.subscribe(listener: self)
    }

    deinit {
        Redux.unsubscribe(listener: self)
    }

    func update(state: State, previousState: State) {
        DispatchQueue.main.async {
            let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
            if state.loading && previousState.loading != state.loading {
                self.setViewControllers([storyboard.instantiateViewController(withIdentifier: "Loading")], animated: false)
            } else if state.icloudUnavailable && previousState.icloudUnavailable != state.icloudUnavailable {
                self.setViewControllers([storyboard.instantiateViewController(withIdentifier: "iCouldUnavailable")], animated: false)
            } else if state.needToSignup && previousState.needToSignup != state.needToSignup {
                self.setViewControllers([storyboard.instantiateViewController(withIdentifier: "Signup")], animated: false)
            } else if state.loggedin && previousState.loggedin != state.loggedin {
                self.setViewControllers([storyboard.instantiateViewController(withIdentifier: "In")], animated: false)
            }
        }
    }
}
