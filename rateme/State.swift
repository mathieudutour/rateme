//
//  State.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

// Listeners are updatable and have an identity so they can be compared
protocol Subscriber
{
    func update(state : State)
    var identifier : String { get set }
}

// helper that can be use in implementations of Updatable to make it unique and identifieable so it can be filtered.
func generateIdentifier() -> String {
    return NSUUID().uuidString
}

class State {
    static let sharedInstance : State = {
        let instance = State()
        return instance
    }()
    
    var subscribers : Array<Subscriber> = []
    var discovery: Discovery?
    
    var loading = true
    var loggedin = false
    var icloudUnavailable = false
    var recordId: CKRecordID?
    var currentUser: CKRecord?
    let publicDB = CKContainer.default().publicCloudDatabase
    var closeUsers: [BLEUser] = []

    
    init() {
        iCloudUserIDAsync() {
            recordID, error in
            if let userID = recordID?.recordName {
                self.recordId = CKRecordID(recordName: userID)
                self.publicDB.fetch(withRecordID: self.recordId!) { fetchedUser, error in
                    if (error != nil) {
                        print(error!.localizedDescription)
                        self.loading = false
                        self.dispatch()
                        return
                    }
                    
                    if (fetchedUser?["username"] == nil) {
                        print("no user")
                        self.loading = false
                        self.loggedin = false
                        self.currentUser = fetchedUser
                        self.dispatch()
                        return
                    }
                    
                    fetchedUser?["lastSeen"] = NSDate()
                    
                    self.loading = false
                    self.loggedin = true
                    self.currentUser = fetchedUser
                    print(self.currentUser!)
                    self.startDiscovery()
                    self.dispatch()
                    
                    CKContainer.default().discoverUserIdentity(withUserRecordID: self.recordId!) { (info, fetchError) in
                        let username = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!)
                        if (username != self.currentUser?["username"] as! String) {
                            self.currentUser?["username"] = username as CKRecordValue?
                            self.dispatch()
                        }
                        self.publicDB.save(self.currentUser!) { savedUser, savedError in
                        
                        }
                    }
                }
            } else {
                self.loading = false
                self.icloudUnavailable = true
                self.dispatch()
            }
        }
    }
    
    func signup(avatar: URL) {
        let container = CKContainer.default()
        
        container.requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
            guard error == nil else { return }
            
            if status == CKApplicationPermissionStatus.granted {
                container.discoverUserIdentity(withUserRecordID: self.recordId!) { (info, fetchError) in
                    // use info.firstName and info.lastName however you need
                    self.currentUser?["lastSeen"] = NSDate()
                    self.currentUser?["username"] = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!) as CKRecordValue?
                    self.currentUser?["score"] = 2.5 as CKRecordValue?
                    self.currentUser?["rating"] = 0 as CKRecordValue?
                    self.currentUser?["avatar"] = CKAsset(fileURL: avatar as URL)
                    
                    let operation = CKModifyRecordsOperation(recordsToSave: [self.currentUser!], recordIDsToDelete: nil)
                    
                    operation.perRecordProgressBlock = { record, progress in
                        print("progress")
                    }
                    
                    operation.completionBlock = {
                        self.loggedin = true
                        self.startDiscovery()
                        self.dispatch()
                    }
                    
                    self.publicDB.add(operation)
                }
            }
        }
    }
    
    
    
    
    func startDiscovery() {
        // start Discovery
        self.discovery = Discovery.init(icloudID: (self.recordId?.recordName)!, usersBlock: {users, usersChanged in
            print("Discovering users: %lu", users.count)
            var usersToQuery: [BLEUser] = []
            self.closeUsers = users.map({user in
                let index = self.closeUsers.index(where: {closeUser in
                    return closeUser.iCloudID == user.iCloudID
                })
                if (index != nil) {
                    self.closeUsers[index!].promixity = user.promixity
                    return self.closeUsers[index!]
                } else {
                    usersToQuery.append(user)
                    return user
                }
            })
            if (usersToQuery.count > 0) {
                let query = CKQuery(
                    recordType: "Users",
                    predicate: NSPredicate(format: "recordID IN %@", usersToQuery.filter({user in
                        return user.iCloudID != nil
                    }).map({user in
                        return CKRecordID(recordName: user.iCloudID!)
                    }))
                )
                
                self.publicDB.perform(query, inZoneWith: nil) { (records, error) in
                    for record in records! {
                        let index = self.closeUsers.index(where: {closeUser in
                            return closeUser.iCloudID! == record.recordID.recordName
                        })
                        if (index != nil) {
                            self.closeUsers[index!].record = record
                        } else {
                            print("no found")
                        }
                    }
                    self.dispatch()
                }
            } else {
                self.dispatch()
            }
        })
    }

    func dispatch() {
        self.subscribers.forEach { $0.update(state: self) }
    }
    
    func subscribe(listener: Subscriber) {
        self.subscribers.append(listener)
        listener.update(state: self)
    }
    
    func unsubscribe(listener: Subscriber ) {
        self.subscribers = self.subscribers.filter({ $0.identifier != listener.identifier })
    }
    
    /// async gets iCloud record name of logged-in user
    func iCloudUserIDAsync(complete: @escaping (_ instance: CKRecordID?, _ error: NSError?) -> ()) {
        CKContainer.default().fetchUserRecordID() {
            recordID, error in
            if error != nil {
                print(error!.localizedDescription)
                complete(nil, error as NSError?)
            } else {
                print("fetched ID \(recordID?.recordName)")
                complete(recordID, nil)
            }
        }
    }
}
