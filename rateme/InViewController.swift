//
//  InViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

let headerHeigh: CGFloat = 300.0

class InViewController: UITableViewController, Subscriber {
    var identifier = generateIdentifier()
    var users: [BLEUser] = []
    let smallFont = UIFont.systemFont(ofSize: 60, weight: UIFontWeightThin)
    let bigFont = UIFont.systemFont(ofSize: 120, weight: UIFontWeightThin)
    let numberFormater = NumberFormatter()

    @IBOutlet weak var waveHeader: WaveHeader!
    @IBOutlet weak var scoreLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        waveHeader.initialize()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableHeaderView = nil
        tableView.addSubview(waveHeader)

        tableView.contentInset = UIEdgeInsets(top: headerHeigh, left: 0, bottom: 0, right: 0)
        tableView.contentOffset = CGPoint(x: 0, y: headerHeigh)
        waveHeader.updateWhenScrolling(tableView: tableView)

        numberFormater.numberStyle = .decimal
        numberFormater.maximumFractionDigits = 3
        numberFormater.minimumFractionDigits = 3
        numberFormater.roundingMode = .halfUp

        Redux.sharedInstance.subscribe(listener: self)
    }

    deinit {
        Redux.sharedInstance.unsubscribe(listener: self)
    }

    func update(state: State, previousState: State) {
        self.users = state.closeUsers.filter({user in
            return user.record != nil
        })

        if (state.currentUser?["score"]) != nil {
            let score = NSMutableAttributedString(string: numberFormater.string(from: NSNumber(value: state.currentUser?["score"] as! Double * 5.0))!)
            let bigRange = NSRange(location: 0, length: 3)
            score.addAttribute(NSFontAttributeName, value: bigFont, range: bigRange)
            let smallRange = NSRange(location: 3, length: 2)
            score.addAttribute(NSFontAttributeName, value: smallFont, range: smallRange)
            scoreLabel.attributedText = score
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: "cell")! as! CloseUserCell

        cell.user = self.users[indexPath.row]

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "RatePeople") as! RatePeopleViewController
        vc.userToRate = self.users[indexPath.row]
        self.navigationController?.pushViewController(vc, animated: true)
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
