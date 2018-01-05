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
let USER_TIMEOUT_INTERVAL = TimeInterval(3)
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
            self.updateList()
        } else {
            // simply update the list, because the order of the users may have changed.
            self.updateList()
        }
    }

    func updateList() {

        var users = Array(self.usersMap.values).filter({user in
            return user.identified
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
        print("User is discovered: ", peripheral.name ?? "unknown", peripheral.identifier, RSSI)
        
        let iCloudID = advertisementData[CBAdvertisementDataLocalNameKey]
        
        var bleUser = self.usersMap[peripheral.identifier.uuidString]
        if bleUser == nil {
            bleUser = BLEUser.init(peripheral: peripheral)
            bleUser!.iCloudID = nil
            bleUser!.peripheral.delegate = self
            
            self.usersMap[bleUser!.peripheralId] = bleUser!
        }
        
        if !bleUser!.identified {
            // We check if we can get the username from the advertisement data,
            // in case the advertising peer application is working at foreground
            // if we get the name from advertisement we don't have to establish a peripheral connection
            if iCloudID != nil && (iCloudID as! String).count > 0 {
                bleUser!.iCloudID = iCloudID as! String?
                bleUser!.identified = true
                
                // we update our list for callback block
                self.updateList()
            } else {
                // nope we could not get the username from CBAdvertisementDataLocalNameKey,
                // we have to connect to the peripheral and try to get the characteristic data
                // add we will extract the username from characteristics.
                
                if peripheral.state == CBPeripheralState.disconnected {
                    self.centralManager?.connect(peripheral, options:nil)
                }
            }
        }
        
        // update the rss and update time
        bleUser!.setRssi(rssi: RSSI.floatValue)
        bleUser!.updateTime = NSDate().timeIntervalSince1970
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
            print(error!)
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
            print(error!)
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
            print(error!)
            return
        }
        let valueStr = NSString(data: characteristic.value!, encoding:String.Encoding.utf8.rawValue)
        // if the value is not nil, we found our username!
        if valueStr != nil {
            let user = self.usersMap[peripheral.identifier.uuidString]
            user?.iCloudID = valueStr! as String
            user?.identified = true
            
            let recordId = CKRecordID(recordName: valueStr! as String)
            
            let fetchingUser = CKFetchRecordsOperation.init(recordIDs: [recordId])
            fetchingUser.qualityOfService = .utility
            fetchingUser.database = self.publicDB
            
            fetchingUser.fetchRecordsCompletionBlock = { fetchedUsers, error in
                if error != nil {
                    print(error!.localizedDescription)
                    return
                }
                
                let fetchedUser = fetchedUsers![recordId]
                user?.record = fetchedUser
                self.updateList()
            }
            fetchingUser.start()
            
            self.updateList()
            
            // cancel the subscription to our characteristic
            peripheral.setNotifyValue(false, for:characteristic)
            
            // and disconnect from the peripehral
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
}
