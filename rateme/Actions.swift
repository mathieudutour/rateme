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
                    self.state.tempRecord = fetchedUser
                    self.state.needToSignup = true
                    self.state.loading = false
                    self.dispatch()
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
        self.discovery = Discovery.init(icloudID: (self.state.recordId?.recordName)!, usersBlock: {users in
            self.state.nearbyUsers = users.map({user in
                let index = self.state.nearbyUsers.index(where: {closeUser in
                    return closeUser.iCloudID == user.iCloudID
                })
                if index != nil {
                    self.state.nearbyUsers[index!].promixity = user.promixity
                    return self.state.nearbyUsers[index!]
                } else {
                    return user
                }
            })
            
            self.dispatch()
        })
    }

    private func listenToRatings() {
        let subscription = CKQuerySubscription(
            recordType: RATING,
            predicate: NSPredicate(format: "ratee == %@", CKReference.init(
                recordID: CKRecordID(recordName: self.state.recordId!.recordName),
                action: CKReferenceAction.deleteSelf
            )),
            options: .firesOnRecordCreation
        )

        let info = CKNotificationInfo()

        info.alertBody = "You have been rated"
        info.shouldBadge = true

        subscription.notificationInfo = info

        publicDB.save(subscription) { record, error in
            if (error != nil) {
                print(error!)
            }
        }
    }
}

// MARK: - signup
extension Redux {
    static func signup(recordId: CKRecordID, record: CKRecord, avatar: URL?, complete: @escaping () -> ()) {
        let instance = Redux.sharedInstance
        let container = CKContainer.default()
        container.discoverUserIdentity(withUserRecordID: recordId) { (info, fetchError) in
            record["lastSeen"] = NSDate()
            record["username"] = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!) as CKRecordValue?
            record["score"] = 0.5 as CKRecordValue?
            record["ratings"] = 0 as CKRecordValue?
            if (avatar != nil) {
                record["avatar"] = CKAsset(fileURL: avatar!)
            }
            instance.state.currentUser = record
        
            let operation = CKModifyRecordsOperation(recordsToSave: [instance.state.currentUser!], recordIDsToDelete: nil)
        
            operation.qualityOfService = .userInteractive
        
            operation.completionBlock = {
                instance.state.loading = false
                instance.state.loggedin = true
                instance.state.needToSignup = false
                instance.state.tempRecord = nil
                instance.listenToRatings()
                instance.startDiscovery()
                instance.dispatch()
                complete()
            }
        
            instance.publicDB.add(operation)
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
                if (error != nil) {
                    print(error!)
                    return
                }
                let ratingRecord = CKRecord(recordType: "Rating")
                ratingRecord["rating"] = starsToScore(rating) as CKRecordValue?
                ratingRecord["rater"] = rater
                ratingRecord["ratee"] = ratee
                
                if fetchedUser?["ratings"] == nil {
                    fetchedUser?["ratings"] = 0 as CKRecordValue?
                }
                if fetchedUser?["score"] == nil {
                    fetchedUser?["score"] = 0.5 as CKRecordValue?
                }
                
                fetchedUser?["score"] = getNewScore(
                    raterScore: instance.state.currentUser?["score"] as! Double,
                    rateeScore: fetchedUser?["score"] as! Double,
                    rating: Double(rating)
                ) as CKRecordValue?
                fetchedUser?["ratings"] = fetchedUser?["ratings"] as! Int + 1 as CKRecordValue?
                
                let index = instance.state.nearbyUsers.index(where: {closeUser in
                    return closeUser.iCloudID == iCloudId
                })
                if index != nil {
                    instance.state.nearbyUsers[index!].record = fetchedUser
                    instance.dispatch()
                }
                
                let operations = CKModifyRecordsOperation(recordsToSave: [ratingRecord, fetchedUser!], recordIDsToDelete: nil)
                
                operations.completionBlock = {
                    instance.dispatch()
                }
                
                instance.publicDB.add(operations)
            }
        }
    }
}

