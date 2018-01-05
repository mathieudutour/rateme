//
//  State.swift
//  rateme
//
//  Created by Mathieu Dutour on 03/01/2018.
//  Copyright © 2018 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

class State: NSObject {
    var loading = true
    var loggedin = false
    var icloudUnavailable = false
    var needToSignup = false
    var tempRecord: CKRecord?
    var recordId: CKRecordID?
    var currentUser: CKRecord?
    var nearbyUsers: [BLEUser] = []
    
    func deepCopy() -> State {
        let stateCopy = State()
        stateCopy.loading = self.loading
        stateCopy.loggedin = self.loggedin
        stateCopy.needToSignup = self.needToSignup
        stateCopy.tempRecord = self.tempRecord
        stateCopy.icloudUnavailable = self.icloudUnavailable
        stateCopy.recordId = self.recordId
        stateCopy.currentUser = self.currentUser
        stateCopy.nearbyUsers = self.nearbyUsers
        return stateCopy
    }
}
