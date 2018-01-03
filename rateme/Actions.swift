//
//  State.swift
//  rateme
//
//  Created by Mathieu Dutour on 11/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

let RATING = "Rating"

// MARK: - initial state
extension Redux {
    func initialState() {
        iCloudUserIDAsync() {
            recordID in
            let userID = recordID.recordName
            // storing the current userId
            self.state.recordId = CKRecordID(recordName: userID)
            
            // starting to fetch the current user
            self.fetchUser(recordId: self.state.recordId!, complete: { fetchedUser in
                if fetchedUser["username"] == nil {
                    self.signup(recordId: self.state.recordId!, record: fetchedUser)
                } else {
                    self.login(recordId: self.state.recordId!, record: fetchedUser)
                }
            })
        }
    }

    // async gets iCloud record name of logged-in user
    private func iCloudUserIDAsync(complete: @escaping (_ instance: CKRecordID) -> ()) {
        CKContainer.default().fetchUserRecordID() {
            recordID, error in
            if error != nil {
                print(error!.localizedDescription)
                self.state.loading = false
                self.state.icloudUnavailable = true
                self.dispatch()
            } else {
                print("fetched ID \(recordID?.recordName ?? "unknown")")
                complete(recordID!)
            }
        }
    }
    
    // get
    private func fetchUser(recordId: CKRecordID, complete: @escaping (_ instance: CKRecord) -> ()) {
        // starting to fetch the current user
        let fetchingCurrentUser = CKFetchRecordsOperation.init(recordIDs: [recordId])
        fetchingCurrentUser.qualityOfService = .userInteractive
        fetchingCurrentUser.database = self.publicDB
        
        fetchingCurrentUser.fetchRecordsCompletionBlock = { fetchedUsers, error in
            if error != nil {
                print(error!.localizedDescription)
                self.state.loading = false
                self.state.icloudUnavailable = true
                self.dispatch()
                return
            }
            
            let fetchedUser = fetchedUsers![self.state.recordId!]
            complete(fetchedUser!)
        }
        fetchingCurrentUser.start()
    }
    
    private func startDiscovery() {
        // start Discovery
        self.discovery = Discovery.init(icloudID: (self.state.recordId?.recordName)!, usersBlock: {users, usersChanged in
            print("Discovering users: %lu", users.count)
            var usersToQuery: [BLEUser] = []
            self.state.closeUsers = users.map({user in
                let index = self.state.closeUsers.index(where: {closeUser in
                    return closeUser.iCloudID == user.iCloudID
                })
                if index != nil {
                    self.state.closeUsers[index!].promixity = user.promixity
                    return self.state.closeUsers[index!]
                } else {
                    usersToQuery.append(user)
                    return user
                }
            })
            if usersToQuery.count > 0 {
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
                        let index = self.state.closeUsers.index(where: {closeUser in
                            return closeUser.iCloudID! == record.recordID.recordName
                        })
                        if index != nil {
                            self.state.closeUsers[index!].record = record
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

    private func listenToRatings() {
        let subscription = CKQuerySubscription(
            recordType: RATING,
            predicate: NSPredicate(format: "ratee == %@", self.state.recordId!.recordName),
            options: .firesOnRecordCreation
        )

        let info = CKNotificationInfo()

        info.alertBody = "You have been rated"
        info.shouldBadge = true

        subscription.notificationInfo = info

        publicDB.save(subscription) { record, error in }
    }
}

// MARK: - signup
extension Redux {
    func signup(recordId: CKRecordID, record: CKRecord) {
        let container = CKContainer.default()
        container.requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
            guard error == nil else { return }
            
            if status == CKApplicationPermissionStatus.granted {
                container.discoverUserIdentity(withUserRecordID: recordId) { (info, fetchError) in
                    record["lastSeen"] = NSDate()
                    record["username"] = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!) as CKRecordValue?
                    record["score"] = 0.5 as CKRecordValue?
                    record["ratings"] = 0 as CKRecordValue?
                    // self.currentUser?["avatar"] = CKAsset(fileURL: avatar as URL)
                    self.state.currentUser = record
                    
                    let operation = CKModifyRecordsOperation(recordsToSave: [self.state.currentUser!], recordIDsToDelete: nil)
                    
                    operation.qualityOfService = .userInteractive
                    
                    operation.completionBlock = {
                        self.state.loading = true
                        self.state.loggedin = true
                        self.listenToRatings()
                        self.startDiscovery()
                        self.dispatch()
                    }
                    
                    self.publicDB.add(operation)
                }
            }
        }
    }
}

// MARK: - login
extension Redux {
    func login(recordId: CKRecordID, record: CKRecord) {
        record["lastSeen"] = NSDate()
        
        self.state.loading = false
        self.state.loggedin = true
        self.state.currentUser = record
        print(self.state.currentUser!)
        self.listenToRatings()
        self.startDiscovery()
        self.dispatch()
        
        let container = CKContainer.default()
        
        container.requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
            guard error == nil else { return }
            
            if status == CKApplicationPermissionStatus.granted {
                container.discoverUserIdentity(withUserRecordID: self.state.recordId!) { (info, fetchError) in
                    let username = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!)
                    if (username != self.state.currentUser?["username"] as! String) {
                        self.state.currentUser?["username"] = username as CKRecordValue?
                        self.dispatch()
                    }
                    self.publicDB.save(self.state.currentUser!) { savedUser, savedError in
                        
                    }
                }
            }
        }
    }
}

// MARK: - rate
extension Redux {
    static func rate(iCloudId: String, rating: NSInteger) {
        let instance = Redux.sharedInstance
        let rater = CKReference.init(recordID: instance.state.recordId!, action: CKReferenceAction.deleteSelf)
        let ratee = CKReference.init(recordID: CKRecordID(recordName: iCloudId), action: CKReferenceAction.deleteSelf)
        let query = CKQuery(
            recordType: RATING,
            predicate: NSPredicate(format: "rater == %@ AND ratee == %@ AND creationDate > %@", rater, ratee, NSDate().addingTimeInterval(-24 * 60 * 60))
        )
        
        instance.publicDB.perform(query, inZoneWith: nil) { (last24hRatings, error) in
            if (last24hRatings != nil && (last24hRatings?.count)! > 0) {
                print("already rated")
                return
            }
            instance.publicDB.fetch(withRecordID: CKRecordID(recordName: iCloudId)) { fetchedUser, error in
                let ratingRecord = CKRecord(recordType: "Rating")
                ratingRecord["rating"] = (Double(rating - 1) / 4.0) as CKRecordValue?
                ratingRecord["rater"] = rater
                ratingRecord["ratee"] = ratee
                ratingRecord["createdAt"] = NSDate().timeIntervalSince1970 as CKRecordValue?
                
                if fetchedUser?["ratings"] == nil {
                    fetchedUser?["ratings"] = 0 as CKRecordValue?
                }
                if fetchedUser?["score"] == nil {
                    fetchedUser?["score"] = 0.5 as CKRecordValue?
                }
                
                let weight = exp(((instance.state.currentUser?["score"] as! Double) - (fetchedUser?["score"] as! Double)) * 5) / 1000
                fetchedUser?["score"] = (instance.state.currentUser?["score"] as! Double) * (1 - weight) + (Double(rating) / 5.0 * weight) as CKRecordValue?
                fetchedUser?["ratings"] = fetchedUser?["ratings"] as! Int + 1 as CKRecordValue?
                
                let operations = CKModifyRecordsOperation(recordsToSave: [ratingRecord, fetchedUser!], recordIDsToDelete: nil)
                
                operations.completionBlock = {
                    instance.dispatch()
                }
                
                instance.publicDB.add(operations)
            }
        }
    }
}

