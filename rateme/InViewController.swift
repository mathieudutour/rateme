//
//  InViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit

class InViewController: UIViewController, Subscriber, UITableViewDelegate, UITableViewDataSource {
    var identifier = generateIdentifier()
    var users: [BLEUser] = []

    @IBOutlet weak var usersTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.usersTableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        State.sharedInstance.subscribe(listener: self)
    }
    
    deinit {
        State.sharedInstance.unsubscribe(listener: self)
    }
    
    func update(state: State) {
        self.users = state.closeUsers.filter({user in
            return user.record != nil
        })
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = self.usersTableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
        
        let record = self.users[indexPath.row].record!
        
        cell.textLabel?.text = record["username"] as! String?
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
}
