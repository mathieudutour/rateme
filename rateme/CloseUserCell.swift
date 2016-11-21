//
//  CloseUserCell.swift
//  rateme
//
//  Created by Mathieu Dutour on 17/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class CloseUserCell: UITableViewCell {
    let numberFormater = NumberFormatter()

    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var score: UILabel!

    var user: BLEUser? {
        didSet {
            setUsernameAndScore()
        }
    }
    
    func setUsernameAndScore() {
        if username != nil {
            if user != nil {
                numberFormater.numberStyle = .decimal
                numberFormater.maximumFractionDigits = 3
                numberFormater.minimumFractionDigits = 3
                numberFormater.roundingMode = .halfUp
                self.username.text = user?.record?["username"] as! String?
                self.score.attributedText = NSMutableAttributedString(string: numberFormater.string(from: NSNumber(value: user?.record?["score"] as! Double * 5.0))!)
            } else {
                self.username.text = "username"
                self.score.text = "2.500"
            }
        }
    }

}
