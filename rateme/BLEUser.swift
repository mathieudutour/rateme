//
//  BLEUser.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import Foundation
import CoreBluetooth
import CloudKit

class BLEUser {
    let peripheral: CBPeripheral
    let peripheralId: String
    var updateTime: TimeInterval
    var identified = false
    var promixity: Double?
    var iCloudID: String?
    var rssi: Float?
    var record: CKRecord?
    
    var velocity = 0.0
    var targetValue = 0.0
    var currentValue = 0.0
    
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        self.peripheralId = peripheral.identifier.uuidString
        self.updateTime = NSDate().timeIntervalSince1970
    }
    
    func setRssi(rssi: Float) {
        self.rssi = rssi
        self.promixity = convertRSSItoProximity(rssi: rssi)
    }

    func convertRSSItoProximity(rssi: Float) -> Double {
        // eased value doesn't support negative values
        self.targetValue = abs(Double(rssi))
        // determine speed at which the ease will happen
        // this is based on difference between target and current value
        velocity += (targetValue - currentValue) * 0.01
        velocity *= 0.7
        
        // ease the current value
        currentValue += velocity
        
        // limit how small the ease can get
        if (abs(targetValue - currentValue) < 0.001) {
            currentValue = targetValue
            velocity = 0.0
        }
        
        // keep above zero
        currentValue = max(0.0, currentValue)
        return currentValue * -1.0
    }
}
