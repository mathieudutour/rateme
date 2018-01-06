//
//  InViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import AVFoundation

let headerHeigh: CGFloat = 300.0
private let smallRange = NSRange(location: 3, length: 2)
private let bigRange = NSRange(location: 0, length: 3)
private let smallFont = UIFont.systemFont(ofSize: 60, weight: UIFont.Weight.thin)
private let bigFont = UIFont.systemFont(ofSize: 120, weight: UIFont.Weight.thin)

class InViewController: UITableViewController, Subscriber {
    var identifier = Redux.generateIdentifier()
    var users: [BLEUser] = []
    let numberFormater = NumberFormatter()
    
    var swooshSound = NSURL(fileURLWithPath: Bundle.main.path(forResource: "swoosh", ofType: "mp3")!)
    var audioPlayer = AVAudioPlayer()
    
    lazy var bulletinManager: BulletinManager = {
        
        let page = RateBulletinItem()
        
        page.actionButtonTitle = "Rate"
        page.alternativeButtonTitle = "Not now"
        
        page.appearance.actionButtonColor = PURPLE
        page.appearance.alternativeButtonColor = PURPLE
        page.appearance.actionButtonTitleColor = PINK
        page.isDismissable = true
        
        page.alternativeHandler = { (item: ActionBulletinItem) in
            item.manager?.dismissBulletin()
        }
        
        page.actionHandler = { (item: ActionBulletinItem) in
            if page.starRating.rating > 0 {
                Redux.rate(iCloudId: (page.userToRate?.iCloudID!)!, rating: page.starRating.rating)
                DispatchQueue.main.async {
                    self.audioPlayer.play()
                    self.navigationController?.popViewController(animated: true)
                    item.manager?.dismissBulletin()
                }
            } else {
                // TODO shake
            }
        }
        
        return BulletinManager(rootItem: page)
        
    }()

    @IBOutlet weak var waveHeader: WaveHeader!
    @IBOutlet weak var scoreLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        waveHeader.initialize()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: swooshSound as URL)
            audioPlayer.prepareToPlay()
        } catch {}

        tableView.tableHeaderView = nil
        tableView.addSubview(waveHeader)

        tableView.contentInset = UIEdgeInsets(top: headerHeigh, left: 0, bottom: 0, right: 0)
        tableView.contentOffset = CGPoint(x: 0, y: headerHeigh)
        waveHeader.updateWhenScrolling(tableView: tableView)

        numberFormater.numberStyle = .decimal
        numberFormater.maximumFractionDigits = 3
        numberFormater.minimumFractionDigits = 3
        numberFormater.roundingMode = .halfUp

        Redux.subscribe(listener: self)
        
        bulletinManager.backgroundViewStyle = .blurredLight
        bulletinManager.prepare()
    }

    deinit {
        Redux.unsubscribe(listener: self)
    }

    func update(state: State, previousState: State) {
        self.users = state.nearbyUsers.filter({user in
            print(user.record?.recordID ?? "")
            return user.record != nil
        })

        if (state.currentUser?["score"]) != nil {
            DispatchQueue.main.async {
                let score = NSMutableAttributedString(string: self.numberFormater.string(from: NSNumber(value: state.currentUser?["score"] as! Double * 5.0))!)
                score.addAttribute(NSAttributedStringKey.font, value: bigFont, range: bigRange)
                score.addAttribute(NSAttributedStringKey.font, value: smallFont, range: smallRange)
                self.scoreLabel.attributedText = score
                self.tableView.reloadData()
                self.waveHeader.updateWhenScrolling(tableView: self.tableView)
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        if self.users.count > 0 {
            tableView.separatorStyle = .singleLine
            tableView.backgroundView = nil
            return 1
        }
        
        let noDataLabel: UILabel     = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
        noDataLabel.text          = "Nobody around"
        noDataLabel.textColor     = UIColor.black
        noDataLabel.textAlignment = .center
        tableView.backgroundView  = noDataLabel
        tableView.separatorStyle  = .none
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as! CloseUserCell
        cell.user = self.users[indexPath.row]
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        (bulletinManager.currentItem as! RateBulletinItem).userToRate = self.users[indexPath.row]
        bulletinManager.presentBulletin(above: self)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        waveHeader.updateWhenScrolling(tableView: tableView)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableViewAutomaticDimension
    }

}
