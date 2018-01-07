//
//  Discovery.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CoreBluetooth
import CloudKit

let SERVICE_UUID = CBUUID(string: "B9407F30-F5F8-466E-AFF9-25556B57FE88")
let USER_TIMEOUT_INTERVAL = TimeInterval(6)
let UPDATE_INTERVAL = TimeInterval(2)

class Discovery: NSObject {
    var timer: Timer?
    var peripheralManager: CBPeripheralManager?
    var centralManager: CBCentralManager?
    var usersMap: [String : BLEUser] = [:]
    let queue = DispatchQueue(label: "me.dutour.mathieu.discovery")
    let usersBlock: (([BLEUser]) -> Void)
    let icloudID: String
    let publicDB = CKContainer.default().publicCloudDatabase

    init(icloudID: String, usersBlock: @escaping ([BLEUser]) -> Void) {
        self.icloudID = icloudID
        self.usersBlock = usersBlock
        super.init()

        self.peripheralManager = CBPeripheralManager(delegate: self, queue: self.queue)
        self.centralManager = CBCentralManager(delegate: self, queue: self.queue, options: [
            CBCentralManagerOptionShowPowerAlertKey: true // show an alert if bluethooth is off
        ])
        
        // stop looking for nearby users when going in the background
        NotificationCenter.default.addObserver(self,
            selector: #selector(stopTimer),
            name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil
        )

        // start looking again for nearby users when going in the foreground
        NotificationCenter.default.addObserver(self,
            selector: #selector(startTimer),
            name: NSNotification.Name.UIApplicationWillEnterForeground,
            object: nil
        )

        self.startTimer()
    }

    @objc private func startTimer() {
        if self.centralManager?.state == CBManagerState.poweredOn {
            self.startDetecting()
        }

        self.timer = Timer.scheduledTimer(
            timeInterval: UPDATE_INTERVAL,
            target: self,
            selector: #selector(checkList),
            userInfo: nil,
            repeats: true
        )
        
        self.timer?.fire()
    }

    @objc private func stopTimer() {
        if (self.timer != nil) {
            self.timer!.invalidate()
            self.timer = nil
        }
        
        self.centralManager?.stopScan()
        print("stopped detecting")
    }

    func startDetecting() {
        let services = [SERVICE_UUID]
        let scanOptions = [CBCentralManagerScanOptionAllowDuplicatesKey: false]

        // we only listen to the service that belongs to our uuid
        // this is important for performance and battery consumption
        self.centralManager?.scanForPeripherals(withServices: services, options:scanOptions)
        
        print("started detecting")
    }

    @objc func checkList() {
        let currentTime = NSDate().timeIntervalSince1970
        
        var discardedKeys: [String] = []
        
        for key in self.usersMap.keys {
            let bleUser = self.usersMap[key]!
            
            let diff = currentTime - bleUser.updateTime
            
            // We remove the user if we haven't seen him for the userTimeInterval amount of seconds.
            // You can simply set the userTimeInterval variable anything you want.
            if diff > USER_TIMEOUT_INTERVAL {
                discardedKeys.append(key)
            }
        }
        
        // update the list if we removed a user.
        if discardedKeys.count > 0 {
            self.usersMap = self.usersMap.reduce([:], {prev, a in
                var mutablePrev = prev
                if !discardedKeys.contains(a.key) {
                    mutablePrev[a.key] = a.value
                }
                return mutablePrev
            })
        }
        
        // fetch the users for which we don't have the record
        for key in self.usersMap.keys {
            let bleUser = self.usersMap[key]!
            if (bleUser.iCloudID == nil) {
                // if we don't have an iCloudID, connect to by bluetooth and get it
                if bleUser.peripheral.state == CBPeripheralState.disconnected {
                    print("connecting to the peripheral", bleUser.peripheral.identifier)
                    self.centralManager?.connect(bleUser.peripheral, options:nil)
                }
            } else if (bleUser.iCloudID != nil && bleUser.record == nil && !bleUser.fetchingRecord) {
                // if we don't have an record, fetch it from the db
                bleUser.fetchingRecord = true
                
                let recordId = CKRecordID(recordName: bleUser.iCloudID! as String)
                fetchUser(recordId: recordId, {fetchedUser, error in
                    bleUser.fetchingRecord = false
                    if error != nil {
                        print("failed to fetch user", error!)
                        
                        // we probably didn't have a good icloudID so remove it and fetch it again by bluetooth
                        bleUser.iCloudID = nil
                        self.checkList()
                    } else if (fetchedUser != nil) {
                        bleUser.record = fetchedUser
                        self.updateList()
                    }
                })
            }
        }
        
        // simply update the list, because the order of the users may have changed.
        self.updateList()
    }

    func updateList() {
        var iCloudIds : [String : Bool] = [:]
        var users = Array(self.usersMap.values).filter({user in
            if (user.record != nil && user.iCloudID != nil && iCloudIds[user.iCloudID!] == nil) {
                iCloudIds[user.iCloudID!] = true
                print(user.record!)
                return true
            }
            return false
        })

        // we sort the list according to "proximity".
        // so the client will receive ordered users according to the proximity.
        users = users.sorted(by: {a, b in
            return a.promixity! > b.promixity!
        })

        self.usersBlock(users)
    }
}

extension Discovery: CBCentralManagerDelegate {
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
                
        var bleUser = self.usersMap[peripheral.identifier.uuidString]
        if bleUser == nil {
            print("User is discovered: ", peripheral.identifier)
            self.usersMap[peripheral.identifier.uuidString] = BLEUser(peripheral: peripheral)
            bleUser = self.usersMap[peripheral.identifier.uuidString]
            bleUser!.peripheral.delegate = self
        }
        
        let potentialICloudID = advertisementData[CBAdvertisementDataLocalNameKey]
        
        if (bleUser!.iCloudID == nil && potentialICloudID != nil) {
            bleUser!.iCloudID = potentialICloudID as! String?
        }
        
        // update the rss and update time
        bleUser!.setRssi(rssi: RSSI.floatValue)
        bleUser!.updateTime = NSDate().timeIntervalSince1970
        
        // we update our list for callback block
        self.checkList()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Peripheral failed to connect: ", peripheral.identifier)
        if (error != nil) {
            print("failed to connect peripheral", error!)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Peripheral disconnected: ", peripheral.identifier)
        if (error != nil) {
            print(error!)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let user = self.usersMap[peripheral.identifier.uuidString]
        print("Peripheral Connected: ", user!.peripheralId)
        
        // Search only for services that match our UUID
        // the connection does not guarantee that we will discover the services.
        // if the device is too far away, it may not be possible to discover the service we want.
        peripheral.discoverServices([SERVICE_UUID])
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            self.startDetecting()
        } else {
            print("Central manager state: ", central.state);
        }
    }
}

extension Discovery: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == CBManagerState.poweredOn {
            self.startAdvertising()
        } else {
            print("Peripheral manager state: ", peripheral.state);
        }
    }
    
    func startAdvertising() {
        let advertisingData = [
            CBAdvertisementDataLocalNameKey: self.icloudID,
            CBAdvertisementDataServiceUUIDsKey: [SERVICE_UUID],
        ] as [String : Any]
        
        // create our characteristics
        let characteristic = CBMutableCharacteristic(
            type: SERVICE_UUID,
            properties: CBCharacteristicProperties.read,
            value: self.icloudID.data(using: String.Encoding.utf8),
            permissions: CBAttributePermissions.readable
        )
        
        // create the service with the characteristics
        let service = CBMutableService(type: SERVICE_UUID, primary: true)
        service.characteristics = [characteristic]
        self.peripheralManager?.add(service)
        
        self.peripheralManager?.startAdvertising(advertisingData)
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if (error != nil) {
            print("couldn't start advertising")
            print(error?.localizedDescription ?? "unknown error")
        } else {
            print("started advertising")
        }
    }
}

extension Discovery: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (error != nil) {
            print("failed to discover services", error!)
            return
        }
        // loop the services
        // since we are looking for only one service, services array probably contains only one or zero item
        for service in peripheral.services! {
            peripheral.discoverCharacteristics(nil, for:service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (error != nil) {
            print("failed to discover characteristic", error!)
            return
        }
        // loop through to find our characteristic
        for characteristic in service.characteristics! {
            if characteristic.uuid.isEqual(SERVICE_UUID) {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (error != nil) {
            print("failed to update value for characteristic", error!)
            return
        }
        let valueStr = NSString(data: characteristic.value!, encoding:String.Encoding.utf8.rawValue)
        // if the value is not nil, we found our username!
        if valueStr != nil {
            if let user = self.usersMap[peripheral.identifier.uuidString] {
                user.iCloudID = valueStr! as String
                self.checkList()
                
                // cancel the subscription to our characteristic
                peripheral.setNotifyValue(false, for:characteristic)
                
                // and disconnect from the peripehral
                self.centralManager?.cancelPeripheralConnection(peripheral)
            }
        }
    }
}
