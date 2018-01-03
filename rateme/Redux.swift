//
//  State.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

class Redux {
    static let sharedInstance: Redux = {
        let instance = Redux()
        return instance
    }()

    private var subscribers: Array<Subscriber> = []
    var discovery: Discovery?

    let publicDB = CKContainer.default().publicCloudDatabase

    var previousState = State()
    var state = State()

    init() {
        initialState()
    }

    func dispatch() {
        self.subscribers.forEach { $0.update(state: self.state, previousState: self.previousState) }
        self.previousState = self.state.deepCopy()
    }
    
    // helper that can be use in implementations of Subscribers to make it unique and identifieable so it can be filtered (see `unsubscribe`).
    static func generateIdentifier() -> String {
        return NSUUID().uuidString
    }

    static func subscribe(listener: Subscriber) {
        let instance = Redux.sharedInstance
        instance.subscribers.append(listener)
        listener.update(state: instance.state, previousState: instance.previousState)
    }

    static func unsubscribe(listener: Subscriber ) {
        let instance = Redux.sharedInstance
        instance.subscribers = instance.subscribers.filter({ $0.identifier != listener.identifier })
    }
}
