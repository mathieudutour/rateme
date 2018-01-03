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
    var recordId: CKRecordID?
    var currentUser: CKRecord?
    var closeUsers: [BLEUser] = []
    
    func deepCopy() -> State {
        let stateCopy = State()
        stateCopy.loading = self.loading
        stateCopy.loggedin = self.loggedin
        stateCopy.icloudUnavailable = self.icloudUnavailable
        stateCopy.recordId = self.recordId
        stateCopy.currentUser = self.currentUser
        stateCopy.closeUsers = self.closeUsers
        return stateCopy
    }
}
