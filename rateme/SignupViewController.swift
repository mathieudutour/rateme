//
//  SignupViewController.swift
//  rateme
//
//  Created by Mathieu Dutour on 12/11/2016.
//  Copyright © 2016 Mathieu Dutour. All rights reserved.
//

import UIKit
import CloudKit

class SignupViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var avatarImageView: UIImageView!
    var avatarURL: NSURL?
    let imagePicker = UIImagePickerController()

    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        avatarImageView.layer.cornerRadius = avatarImageView.frame.height/2
        avatarImageView.clipsToBounds = true
    }
    
    @IBAction func loadAvatar(_ sender: Any) {
        let actionSheet = UIAlertController(title: "Choose option", message: "Option to select", preferredStyle: .actionSheet)
        
        let cancelActionButton: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            print("Cancel")
        }
        actionSheet.addAction(cancelActionButton)
        
        let cameraActionButton: UIAlertAction = UIAlertAction(title: "Camera", style: .default)
        { action -> Void in
            self.imagePicker.sourceType = .camera
            self.present(self.imagePicker, animated: true, completion: nil)
        }
        actionSheet.addAction(cameraActionButton)
        
        let galleryActionButton: UIAlertAction = UIAlertAction(title: "Photo Library", style: .default)
        { action -> Void in
            self.imagePicker.sourceType = .photoLibrary
            self.present(self.imagePicker, animated: true, completion: nil)
        }
        actionSheet.addAction(galleryActionButton)
        
        self.present(actionSheet, animated: true, completion: nil)
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
        picker.dismiss(animated: true, completion: nil)
        let image = info[UIImagePickerControllerOriginalImage]
        if (image != nil) {
            let imageURL = info[UIImagePickerControllerReferenceURL] as! NSURL
            let imagePath =  imageURL.path!
            let localPath = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(imagePath)
            
            let path = localPath?.relativePath
            let resizedImage = resizeImage(image: image as! UIImage, newSize: 200)
            let data = UIImagePNGRepresentation(resizedImage)
            do {
                try data?.write(to: localPath!, options: .atomic)
                //this block grabs the NSURL so you can use it in CKASSET
                let photoURL = NSURL(fileURLWithPath: path!)
                avatarURL = photoURL
            } catch {
                print("error")
            }
            avatarImageView.image = resizedImage
        }
    }

    @IBAction func signup(_ sender: Any) {
        State.sharedInstance.signup(avatar: avatarURL! as URL)
    }
}
