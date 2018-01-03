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
protocol Subscriber {
    func update(state: State, previousState: State)
    var identifier: String { get set }
}

// helper that can be use in implementations of Updatable to make it unique and identifieable so it can be filtered.
func generateIdentifier() -> String {
    return NSUUID().uuidString
}

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

let RATING = "Rating"

class Redux {
    static let sharedInstance: Redux = {
        let instance = Redux()
        return instance
    }()

    var subscribers: Array<Subscriber> = []
    var discovery: Discovery?

    let publicDB = CKContainer.default().publicCloudDatabase

    var previousState = State()
    var state = State()

    init() {
        let container = CKContainer.default()
        iCloudUserIDAsync() {
            recordID, error in
            if let userID = recordID?.recordName {
                // storing the current userId
                self.state.recordId = CKRecordID(recordName: userID)
                
                // starting to fetch the current user
                let fetchingCurrentUser = CKFetchRecordsOperation.init(recordIDs: [self.state.recordId!])
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

                    if fetchedUser?["username"] == nil {
                        // signup
                        container.requestApplicationPermission(CKApplicationPermissions.userDiscoverability) { (status, error) in
                            guard error == nil else { return }

                            if status == CKApplicationPermissionStatus.granted {
                                container.discoverUserIdentity(withUserRecordID: self.state.recordId!) { (info, fetchError) in
                                    // use info.firstName and info.lastName however you need
                                    fetchedUser?["lastSeen"] = NSDate()
                                    fetchedUser?["username"] = ((info!.nameComponents?.givenName)! + " " + (info!.nameComponents?.familyName)!) as CKRecordValue?
                                    fetchedUser?["score"] = 0.5 as CKRecordValue?
                                    fetchedUser?["ratings"] = 0 as CKRecordValue?
//                                    self.currentUser?["avatar"] = CKAsset(fileURL: avatar as URL)
                                    self.state.currentUser = fetchedUser

                                    let operation = CKModifyRecordsOperation(recordsToSave: [self.state.currentUser!], recordIDsToDelete: nil)

                                    operation.perRecordProgressBlock = { record, progress in
                                        print("progress")
                                    }

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

                        return
                    }

                    fetchedUser?["lastSeen"] = NSDate()

                    self.state.loading = false
                    self.state.loggedin = true
                    self.state.currentUser = fetchedUser
                    print(self.state.currentUser!)
                    self.listenToRatings()
                    self.startDiscovery()
                    self.dispatch()

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
                fetchingCurrentUser.start()
            } else {
                self.state.loading = false
                self.state.icloudUnavailable = true
                self.dispatch()
            }
        }
    }

    func rate(iCloudId: String, rating: NSInteger) {
        let rater = CKReference.init(recordID: self.state.recordId!, action: CKReferenceAction.deleteSelf)
        let ratee = CKReference.init(recordID: CKRecordID(recordName: iCloudId), action: CKReferenceAction.deleteSelf)
        let query = CKQuery(
            recordType: RATING,
            predicate: NSPredicate(format: "rater == %@ AND ratee == %@ AND creationDate > %@", rater, ratee, NSDate().addingTimeInterval(-24 * 60 * 60))
        )

        self.publicDB.perform(query, inZoneWith: nil) { (last24hRatings, error) in
            if (last24hRatings != nil && (last24hRatings?.count)! > 0) {
                print("already rated")
                return
            }
            self.publicDB.fetch(withRecordID: CKRecordID(recordName: iCloudId)) { fetchedUser, error in
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

                let weight = exp(((self.state.currentUser?["score"] as! Double) - (fetchedUser?["score"] as! Double)) * 5) / 1000
                fetchedUser?["score"] = (self.state.currentUser?["score"] as! Double) * (1 - weight) + (Double(rating) / 5.0 * weight) as CKRecordValue?
                fetchedUser?["ratings"] = fetchedUser?["ratings"] as! Int + 1 as CKRecordValue?

                let operations = CKModifyRecordsOperation(recordsToSave: [ratingRecord, fetchedUser!], recordIDsToDelete: nil)

                operations.completionBlock = {
                    self.dispatch()
                }

                self.publicDB.add(operations)
            }
        }

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

    private func dispatch() {
        self.subscribers.forEach { $0.update(state: self.state, previousState: self.previousState) }
        self.previousState = self.state.deepCopy()
    }

    func subscribe(listener: Subscriber) {
        self.subscribers.append(listener)
        listener.update(state: self.state, previousState: self.previousState)
    }

    func unsubscribe(listener: Subscriber ) {
        self.subscribers = self.subscribers.filter({ $0.identifier != listener.identifier })
    }

    /// async gets iCloud record name of logged-in user
    private func iCloudUserIDAsync(complete: @escaping (_ instance: CKRecordID?, _ error: NSError?) -> ()) {
        CKContainer.default().fetchUserRecordID() {
            recordID, error in
            if error != nil {
                print(error!.localizedDescription)
                complete(nil, error as NSError?)
            } else {
                print("fetched ID \(recordID?.recordName ?? "unknown")")
                complete(recordID, nil)
            }
        }
    }

    private func listenToRatings() {
        let subscription = CKQuerySubscription(
            recordType: RATING,
            predicate: NSPredicate(format: "ratee == %@", self.state.recordId!.recordName),
            options: .firesOnRecordCreation
        )

        let info = CKNotificationInfo()

        info.alertBody = "Someone just rated you!"
        info.shouldBadge = true

        subscription.notificationInfo = info

        publicDB.save(subscription) { record, error in }
    }
}
