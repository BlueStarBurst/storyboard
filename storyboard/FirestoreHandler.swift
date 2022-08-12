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
    
    func getUser(username: String) -> [String:Any]? {
        
        var returnData: [String:Any]? = nil
        
        FirebaseManager.shared.db.collection("users").whereField("username", isEqualTo: username.lowercased()).getDocuments() { (querySnapshot, err) in
            print(err)
            if let err = err {
                print("Document does not exist")
                
            } else {
                for document in querySnapshot!.documents {
                    returnData = document.data()
                }
            }
        }
        
        return returnData
    }
    
    func getUser(id: String, completionHandler: @escaping ([String:Any]?) -> Void) {
        
        let docRef = FirebaseManager.shared.db.collection("users").document(id)
        
        docRef.getDocument { (document, error) in

            if let document = document, document.exists {
                completionHandler(document.data())
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
            
            if self.currentUser?["incomingFriends"] != nil {
                guard case let inc as [String] = self.currentUser?["incomingFriends"] else { return }
                    
                
            }
        })
    }
}
