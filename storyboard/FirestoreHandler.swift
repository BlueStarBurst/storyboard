//
//  FirestoreHandler.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 8/11/22.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseStorage
import FirebaseCore
import FirebaseFirestore
import JWTKit


class DataHandler: NSObject {
    
    var currentUser: [String:Any]?
    
    var friends: [[String:Any]]?
    var incFriendRequests: [[String:Any]]?
    var outFriendRequests: [[String:Any]]?
    
    var uid: String?
    
    static let shared = DataHandler()
    
    override init() {
        super.init()
        self.load()
        
    }
    
    func load() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.uid = uid
        
        print(self.uid)
        
        self.getSelf()
    }
    
    func load(onComplete: @escaping () -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.uid = uid
        
        print(self.uid)
        
        self.getSelf(onComplete: onComplete)
    }
    
    func getUser(username: String, completionHandler: @escaping ([String:Any]) -> Void) {
        
        FirebaseManager.shared.db.collection("users").whereField("username", isEqualTo: username.lowercased()).getDocuments() { (querySnapshot, err) in
            print(err)
            if let err = err {
                print("Document does not exist")
                
            } else {
                for document in querySnapshot!.documents {
                    completionHandler( document.data() )
                }
            }
        }
        
//        return returnData
    }
    
    func niceString(map: [String:Any]) -> [String:String] {
        return [
            "username": map["username"] as! String,
            "fullname": map["fullname"] as! String,
            "pfp": map["pfp"] as! String,
            "id": map["id"] as! String,
            "display": map["display"] as! String
        ]
    }
    
    func getUsers(username: String, completionHandler: @escaping ([[String:String]]) -> Void) {
        
        var returnData: [[String:String]] = []
        
        FirebaseManager.shared.db.collection("users").order(by: "username").start(at: [username.lowercased()]).end(at: [username.lowercased() + String("\u{f8ff}")]).limit(to: 25)
    
            .getDocuments() { (querySnapshot, err) in
            print(err)
            if let err = err {
                print("Document does not exist")
                
            } else {
                for document in querySnapshot!.documents {
                    returnData.append(self.niceString(map:document.data()))
                }
                completionHandler(returnData)
            }
        }

    }
    
    func getUser(id: String, completionHandler: @escaping ([String:Any]?) -> Void) {
        
        let docRef = FirebaseManager.shared.db.collection("users").document(id)
        
        docRef.getDocument { (document, error) in
            
            print(document)
            print(error)
            
            if error != nil {
                completionHandler(nil)
            }
            
            if let document = document, document.exists {
                completionHandler(document.data())
            } else {
                completionHandler(nil)
            }
        }
        //        return returnData
    }
    
    func getSelf() {
        if self.uid == nil {
            return
        }
        self.getUser(id: self.uid!, completionHandler: { user in
            self.currentUser = user
        })
    }
    
    func getSelf(onComplete: @escaping () -> Void) {
        if self.uid == nil {
            return
        }
        self.getUser(id: self.uid!, completionHandler: { user in
            self.currentUser = user
            onComplete()
        })
    }
    
    func getFriends(handler: [[String:String]]?) {
        if self.currentUser?["friends"] != nil {
            let privRef = FirebaseManager.shared.db.collection("users").document(uid).collection("private").document("data")
            guard case let friends as [String] = self.currentUser?["friends"] else { return }
            
            friends.forEach { friendID in
                
                self.getUser(id: friendID, completionHandler: { friend in
                    self.friends?.append([
                        "username": friend!["username"],
                        "fullname": friend!["fullname"],
                        "pfp": friend!["pfp"],
                        "id": friend!["id"]
                    ])
                })
                
                
            }
            
        }
    }
}
