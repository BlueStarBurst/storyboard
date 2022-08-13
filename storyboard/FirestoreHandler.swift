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


class DataHandler: NSObject, ObservableObject {
    
    var currentUser: [String:Any]?
    
    @Published var friends: [[String:String]] = []
    @Published var incFriendRequests: [[String:String]] = []
    @Published var outFriendRequests: [[String:String]] = []
    
    var events: [String:[String:Any]] = [:]
    var incomingEvents: [String:[String:Any]] = [:]
    
    var outListener: Any?
    var incListener: Any?
    var friendListener: Any?
    var eventsListener: Any?
    var incEventsListener: Any?
    
    var uid: String?
    
    var eventPageUpdate : () -> Void = {}
    var friendPageUpdate : () -> Void = {}
    
    func callAllUpdates() {
        self.eventPageUpdate()
        self.friendPageUpdate()
    }
    
    @ObservedObject static var shared = DataHandler()
    
    override init() {
        super.init()
        self.load()
        
    }
    
    func load(onComplete: @escaping () -> Void = {}) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        self.uid = uid
        
        print(self.uid)
        
        self.getSelf(onComplete: {
            onComplete()
            //            self.getOutgoing()
            self.setupListeners()
        })
    }
    
    func setupListeners() {
        
        if (self.outListener == nil) {
            
            self.outListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("outgoingFriends").addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    
                    if (diff.type == .added) {
                        print("ADDED OUTGOING")
                        print(diff.document.data())
                        withAnimation {
                            self.outFriendRequests.append(self.niceString(map: diff.document.data()))
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED OUTGOING")
                        if let index = self.outFriendRequests.firstIndex(of: self.niceString(map: diff.document.data())) {
                            withAnimation {
                                self.outFriendRequests.remove(at: index)
                            }
                        }
                    }
                    
                    self.callAllUpdates()                }
            }
            
        }
        
        if (self.incListener == nil) {
            
            self.incListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingFriends").addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        print("ADDED INCOMING")
                        print(diff.document.data())
                        self.incFriendRequests.append(self.niceString(map: diff.document.data()))
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED INCOMING")
                        if let index = self.incFriendRequests.firstIndex(of: self.niceString(map: diff.document.data())) {
                            withAnimation {
                                self.incFriendRequests.remove(at: index)
                            }
                        }
                    }
                    
                    self.callAllUpdates()
                }
                
                
            }
            
        }
        
        
        if (self.friendListener == nil) {
            
            self.friendListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("friends").addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    if (diff.type == .added) {
                        print("ADDED FRIEND")
                        print(diff.document.data())
                        withAnimation {
                            self.friends.append(self.niceString(map: diff.document.data()))
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED FRIEND")
                        if let index = self.friends.firstIndex(of: self.niceString(map: diff.document.data())) {
                            withAnimation {
                                self.friends.remove(at: index)
                            }
                        }
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
        
        if (self.eventsListener == nil) {
            
            self.eventsListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("events").addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    let dat = diff.document.data()
                    if (diff.type == .added) {
                        print("ADDED EVENT")
                        print(diff.document.data())
                        
                        withAnimation {
                            self.events[diff.document.documentID] = dat
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED EVENT")
                        self.events.removeValue(forKey: diff.document.documentID)
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
        
        if (self.incEventsListener == nil) {
            
            self.incEventsListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingEvents").addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    let dat = diff.document.data()
                    if (diff.type == .added) {
                        print("ADDED INC EVENT")
                        print(diff.document.data())
                        
                        withAnimation {
                            self.incomingEvents[diff.document.documentID] = dat
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED INC EVENT")
                        self.incomingEvents.removeValue(forKey: diff.document.documentID)
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
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
        print(map)
        return [
            "username": (map["username"] ?? "") as! String,
            "fullname": (map["fullname"] ?? "") as! String,
            "pfp": (map["pfp"] ?? "") as! String,
            "id": (map["id"] ?? "") as! String,
            "display": (map["display"] ?? "") as! String
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
        if self.currentUser?["display"] != nil {
            let privRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("friends").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting docs")
                } else {
                    var friends: [[String:String]] = []
                    for doc in querySnapshot!.documents {
                        self.getUser(id: doc.documentID, completionHandler: { map in
                            friends.append(self.niceString(map: map!))
                        })
                    }
                    self.friends = friends
                }
            }
        }
    }
    
    func getOutgoing() {
        self.outFriendRequests = []
        if self.currentUser?["display"] != nil {
            let privRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("outgoingFriends").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting docs")
                } else {
                    for doc in querySnapshot!.documents {
                        self.getUser(id: doc.documentID, completionHandler: { map in
                            self.outFriendRequests.append(self.niceString(map: map!))
                        })
                    }
                }
            }
        }
    }
    
    func getIncoming() {
        self.incFriendRequests = []
        if self.currentUser?["display"] != nil {
            let privRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingFriends").getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting docs")
                } else {
                    for doc in querySnapshot!.documents {
                        self.getUser(id: doc.documentID, completionHandler: { map in
                            self.incFriendRequests.append(self.niceString(map: map!))
                        })
                    }
                }
            }
        }
    }
    
    func addFriend(username: String, completionhandler: @escaping () -> Void) {
        
        if (self.uid == nil) {
            return
        }
        
        getUser(username: username, completionHandler: { data in
            
            var shouldStop = false
            
            // if incoming
            let myIncRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingFriends").document(data["id"] as! String)
            
            let myFriendRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("friends").document(data["id"] as! String)
            
            let myOutRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("outgoingFriends").document(data["id"] as! String)
            
            let fIncRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("incomingFriends").document(self.uid ?? "")
            
            let fFriendRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("friends").document(self.uid ?? "")
            
            let fOutRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("outgoingFriends").document(self.uid ?? "")
            
            myIncRef.getDocument { (document, error) in
                if let document = document, document.exists {
                    
                    try? myFriendRef.setData([
                        "username":data["username"],
                        "display": data["display"],
                        "fullname":data["fullname"],
                        "pfp": data["pfp"],
                        "id": data["id"]
                    ]) { error in
                        if error != nil {
                            return
                        }
                        try? fFriendRef.setData([
                            "username":self.currentUser!["username"],
                            "display": self.currentUser!["display"],
                            "fullname":self.currentUser!["fullname"],
                            "pfp": self.currentUser!["pfp"],
                            "id": self.currentUser!["id"]
                        ])
                        try? fOutRef.delete()
                        try? myIncRef.delete() { err in
                            if let err = err {
                                print("ERROR WITH FRIEND")
                            } else {
                                completionhandler()
                            }
                        }
                        
                    }
                    
                    shouldStop = true
                } else {
                    try? myOutRef.setData([
                        "username":data["username"],
                        "display": data["display"],
                        "fullname":data["fullname"],
                        "pfp": data["pfp"],
                        "id": data["id"]
                    ]) { error in
                        if error != nil {
                            return
                        }
                        
                        try? fIncRef.setData([
                            "username":self.currentUser!["username"],
                            "display": self.currentUser!["display"],
                            "fullname":self.currentUser!["fullname"],
                            "pfp": self.currentUser!["pfp"],
                            "id": self.currentUser!["id"]
                        ]) { error in
                            if error != nil {
                                return
                            }
                            
                            completionhandler()
                        }
                    }
                }
            }
            
            
            
            if shouldStop == true {
                return
            }
            
            // outgoing
            
            
        })
        
    }
    
    func removeOutFriend(username: String, completionHandler: @escaping () -> Void) {
        
        if (self.uid == nil) {
            return
        }
        
        getUser(username: username, completionHandler: { data in
            
            
            // if incoming
            let myIncRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingFriends").document(data["id"] as! String)
            
            let myFriendRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("friends").document(data["id"] as! String)
            
            let myOutRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("outgoingFriends").document(data["id"] as! String)
            
            let fIncRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("incomingFriends").document(self.uid ?? "")
            
            let fFriendRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("friends").document(self.uid ?? "")
            
            let fOutRef = FirebaseManager.shared.db.collection("users").document(data["id"] as! String).collection("outgoingFriends").document(self.uid ?? "")
            
            print("ATTEMPT")
            try? myOutRef.delete()
            try? myIncRef.delete()
            try? fOutRef.delete()
            try? fFriendRef.delete()
            try? myFriendRef.delete()
            try? fIncRef.delete()
            
            completionHandler()
            
        })
        
    }
    
    
    func createEvent(data: [String:Any], completionHandler: @escaping () -> Void) {
        
        var ref: DocumentReference? = nil
        ref = FirebaseManager.shared.db.collection("events").addDocument(data: data) { error in
            if error != nil {
                return
            }
            let eventRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("events").document(ref!.documentID)
            
            (data["invited"] as! [String]).forEach { friend in
                self.getUser(username: friend, completionHandler: { datas in
                    let fFriendRef = FirebaseManager.shared.db.collection("users").document(datas["id"] as! String).collection("incomingEvents").document(ref!.documentID)
                    
                    fFriendRef.setData(data) { err in
                        if error != nil {
                            return
                        }
                    }
                })
            }
            
            eventRef.setData(data) { err in
                if error != nil {
                    return
                }
                completionHandler()
            }
        }
    }
}
