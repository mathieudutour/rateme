//
//  Subscriber.swift
//  rateme
//
//  Created by Mathieu Dutour on 03/01/2018.
//  Copyright © 2018 Mathieu Dutour. All rights reserved.
//

import Foundation

// Listeners are updatable and have an identifier so they can be compared
protocol Subscriber {
    func update(state: State, previousState: State)
    var identifier: String { get set }
}
