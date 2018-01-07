//
//  CloseUserCell.swift
//  rateme
//
//  Created by Mathieu Dutour on 17/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

private let smallRange = NSRange(location: 3, length: 2)
private let bigRange = NSRange(location: 0, length: 3)
private let smallFont = UIFont.systemFont(ofSize: 10, weight: UIFont.Weight.thin)
private let bigFont = UIFont.systemFont(ofSize: 17, weight: UIFont.Weight.thin)

class CloseUserCell: UITableViewCell {
    private var numberFormater = NumberFormatter()

    @IBOutlet weak var username: UILabel!
    @IBOutlet weak var score: UILabel!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var wrapper: UIView!
    
    var user: BLEUser? {
        didSet {
            setUsernameAndScore()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        numberFormater.numberStyle = .decimal
        numberFormater.maximumFractionDigits = 3
        numberFormater.minimumFractionDigits = 3
        numberFormater.roundingMode = .halfUp
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        avatar.contentMode = .scaleAspectFill
        avatar.layer.cornerRadius = 19.5
        avatar.layer.borderColor = UIColor.white.cgColor
        avatar.layer.borderWidth = 1.0
        avatar.clipsToBounds = true
        
        wrapper.layer.cornerRadius = 12
    }

    func setUsernameAndScore() {
        if username != nil {
            if user != nil {
                self.username.text = user?.record?["username"] as! String?
                let score = NSMutableAttributedString(string: self.numberFormater.string(from: NSNumber(value: user?.record?["score"] as! Double * 5.0))!)
                score.addAttribute(NSAttributedStringKey.font, value: bigFont, range: bigRange)
                score.addAttribute(NSAttributedStringKey.font, value: smallFont, range: smallRange)
                let avatarAsset = user?.record?["avatar"] as! CKAsset?
                if (avatarAsset != nil) {
                    guard let imageData = NSData(contentsOf: avatarAsset!.fileURL) else {
                        print("Invalid Image")
                        return
                    }
                    self.avatar.image = UIImage(data: imageData as Data)
                } else {
                    self.avatar.image = nil
                }
                
                self.score.attributedText = score
            } else {
                self.username.text = "username"
                let score = NSMutableAttributedString(string: numberFormater.string(from: 2.5)!)
                score.addAttribute(NSAttributedStringKey.font, value: bigFont, range: bigRange)
                score.addAttribute(NSAttributedStringKey.font, value: smallFont, range: smallRange)
                self.score.attributedText = score
            }
        }
    }

}
