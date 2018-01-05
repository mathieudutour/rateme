//
//  SignupViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit
import UserNotifications

class SignupViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    lazy var bulletinManager: BulletinManager = {
        
        let loginWithICloud = createLoginWithICloudItem()
        
        let notificationPrimer = createNotificationPrivateItem()
        loginWithICloud.nextItem = notificationPrimer
        
        let chooseAvatar = createChooseAvatarPrimerItem()
        notificationPrimer.nextItem = chooseAvatar
        
        return BulletinManager(rootItem: loginWithICloud)
        
    }()
    
    lazy var lastBulletinManager: BulletinManager = {
        let chooseAvatar = createChooseAvatarItem()
        return BulletinManager(rootItem: chooseAvatar)
    }()

    var avatarURL: URL?
    let imagePicker = UIImagePickerController()
    @IBOutlet weak var getStartedButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        getStartedButton.layer.cornerRadius = 12
        
        self.bulletinManager.backgroundViewStyle = .blurredLight
        bulletinManager.prepare()
    }

    @IBAction func getStarted(_ sender: Any) {
        bulletinManager.presentBulletin(above: self)
    }

    func resizeImage(image: UIImage, newSize: CGFloat) -> UIImage {
        let scale = newSize / (image.size.width > image.size.height ? image.size.height : image.size.width)
        let newHeight = image.size.height * scale
        let newWidth = image.size.width * scale
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContext(newSize)
        image.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        let image = info[UIImagePickerControllerEditedImage] ?? info[UIImagePickerControllerOriginalImage]
        DispatchQueue.main.async {
            picker.dismiss(animated: true, completion: {
                self.lastBulletinManager.backgroundViewStyle = .blurredLight
                self.lastBulletinManager.prepare()
                (self.lastBulletinManager.currentItem as! ChooseAvatarBulletinItem).image = (image as? UIImage)
                self.lastBulletinManager.presentBulletin(above: self)
            })
        }
        if image != nil {
            let localPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("me.rate.temp.avatar")

            let path = localPath?.relativePath
            let resizedImage = resizeImage(image: image as! UIImage, newSize: 200)
            let data = UIImageJPEGRepresentation(resizedImage, 0.75)
            do {
                try data?.write(to: localPath!, options: .atomic)
                //this block grabs the NSURL so you can use it in CKASSET
                let photoURL = NSURL(fileURLWithPath: path!)
                avatarURL = photoURL as URL
            } catch {
                print("error")
            }
        }
    }
}

extension SignupViewController {
    fileprivate func createLoginWithICloudItem() -> PageBulletinItem {
        let loginWithICloud = PageBulletinItem(title: "iCloud")
        
        loginWithICloud.descriptionText = "RateMe uses iCloud to identify the users. It will only share your name and your identifier, nothing confidential."
        loginWithICloud.actionButtonTitle = "Next"
        
        loginWithICloud.appearance.actionButtonColor = PURPLE
        loginWithICloud.appearance.actionButtonTitleColor = PINK
        
        loginWithICloud.actionHandler = { (item: ActionBulletinItem) in
            item.manager?.displayActivityIndicator(color: PURPLE)
            CKContainer.default().requestApplicationPermission(
                CKApplicationPermissions.userDiscoverability
            ) { (status, error) in
                if (error != nil) {
                    print(error!)
                }
                
                DispatchQueue.main.async {
                    if status == CKApplicationPermissionStatus.granted {
                        item.manager?.displayNextItem()
                    } else {
                        item.manager?.dismissBulletin()
                    }
                    item.manager?.hideActivityIndicator()
                }
            }
        }
        
        return loginWithICloud
    }

    fileprivate func createNotificationPrivateItem() -> PageBulletinItem {
        let notificationPrimer = PageBulletinItem(title: "Push Notifications")
        
        notificationPrimer.descriptionText = "Whenever someone rates you, we can send you a push notification."
        notificationPrimer.actionButtonTitle = "Sounds good"
        notificationPrimer.alternativeButtonTitle = "I'll pass"
        notificationPrimer.image = #imageLiteral(resourceName: "NotificationPrompt")
        notificationPrimer.imageAccessibilityLabel = "Notifications Icon"
        
        notificationPrimer.appearance.actionButtonColor = PURPLE
        notificationPrimer.appearance.actionButtonTitleColor = PINK
        notificationPrimer.appearance.alternativeButtonColor = PURPLE
        
        notificationPrimer.actionHandler = { (item: ActionBulletinItem) in
            item.manager?.displayActivityIndicator(color: PURPLE)
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print(error)
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        item.manager?.displayNextItem()
                        item.manager?.hideActivityIndicator()
                    }
                }
            }
            CKContainer.default().requestApplicationPermission(
                CKApplicationPermissions.userDiscoverability
            ) { (status, error) in
                if (error != nil) {
                    print(error!)
                }
                
                DispatchQueue.main.async {
                    if status == CKApplicationPermissionStatus.granted {
                        item.manager?.displayNextItem()
                    } else {
                        item.manager?.dismissBulletin()
                    }
                    item.manager?.hideActivityIndicator()
                }
            }
        }
        
        notificationPrimer.alternativeHandler = { (item: ActionBulletinItem) in
            item.manager?.displayNextItem()
        }
        
        return notificationPrimer
    }
    
    private func openSourceOptionAlert(item: BulletinItem) {
        item.manager?.dismissBulletin()
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cancelActionButton: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            self.bulletinManager.presentBulletin(above: self)
        }
        actionSheet.addAction(cancelActionButton)
        
        let cameraActionButton: UIAlertAction = UIAlertAction(title: "Camera", style: .default) { action -> Void in
            self.imagePicker.sourceType = .camera
            self.present(self.imagePicker, animated: true, completion: nil)
        }
        actionSheet.addAction(cameraActionButton)
        
        let galleryActionButton: UIAlertAction = UIAlertAction(title: "Photo Library", style: .default) { action -> Void in
            self.imagePicker.sourceType = .photoLibrary
            self.present(self.imagePicker, animated: true, completion: nil)
        }
        actionSheet.addAction(galleryActionButton)
        
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    fileprivate func createChooseAvatarPrimerItem() -> PageBulletinItem {
        let chooseAvatar = PageBulletinItem(title: "Profile Picture")
        
        chooseAvatar.descriptionText = "We need your best profile so that people give you better ratings. Super important."
        chooseAvatar.actionButtonTitle = "For Sure"
        
        chooseAvatar.appearance.actionButtonColor = PURPLE
        chooseAvatar.appearance.actionButtonTitleColor = PINK
        
        chooseAvatar.actionHandler = openSourceOptionAlert
        
        return  chooseAvatar
    }

    fileprivate func createChooseAvatarItem() -> ChooseAvatarBulletinItem {
        let chooseAvatar = ChooseAvatarBulletinItem(title: "Profile Picture")
        
        chooseAvatar.actionButtonTitle = "All good"
        
        chooseAvatar.appearance.actionButtonColor = PURPLE
        chooseAvatar.appearance.actionButtonTitleColor = PINK
        
        chooseAvatar.imageHandler = openSourceOptionAlert
        
        chooseAvatar.actionHandler = { (item: ActionBulletinItem) in
            item.manager?.displayActivityIndicator(color: PURPLE)
            Redux.signup(
                recordId: Redux.sharedInstance.state.recordId!,
                record: Redux.sharedInstance.state.tempRecord!,
                avatar: self.avatarURL,
                complete: {
                    DispatchQueue.main.async {
                        item.manager?.dismissBulletin()
                    }
                }
            )
        }
        
        return  chooseAvatar
    }
}
