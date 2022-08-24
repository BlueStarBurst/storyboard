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
import FirebaseMessaging

struct ChatMessage: Identifiable {
    var id: String { documentId }
    
    let documentId: String
    let fromId, text: String
    let name: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data["fromId"] as? String ?? ""
        self.text = data["text"] as? String ?? ""
        self.name = data["name"] as? String ?? ""
    }
}


class DataHandler: NSObject, ObservableObject {
    
    var currentUser: [String:Any]?
    var currentEvent: String?
    
    var chatMessages = [ChatMessage]()
    
    var currentChatName: String = ""
    
    var isMessageView = false
    
    var isFriendMessage = false
    
    @Published var friends: [[String:String]] = []
    @Published var friendsDict: [String:[String:Any]] = [:]
    @Published var incFriendRequests: [[String:String]] = []
    @Published var outFriendRequests: [[String:String]] = []
    
    var feed: [[String:Any]] = []
    
    var events: [String:[String:Any]] = [:]
    var incomingEvents: [String:[String:Any]] = [:]
    
    var attendingEvent: [[String:String]] = []
    var invitingEvent: [[String:String]] = []
    
    var outListener: ListenerRegistration?
    var incListener: ListenerRegistration?
    var friendListener: ListenerRegistration?
    var eventsListener: ListenerRegistration?
    var incEventsListener: ListenerRegistration?
    var chatListener: ListenerRegistration?
    var postListener: ListenerRegistration?
    
    var uid: String?
    
    var eventPageUpdate : () -> Void = {}
    var friendPageUpdate : () -> Void = {}
    var updateMessage: () -> Void = {}
    var messageViewUpdate: () -> Void = {}
    var onFinishEditing: () -> Void = {}
    var feedUpdate: () -> Void = {}
    
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

            self.updateToken()
            self.setupListeners()
        })
    }
    
    func showMessages() {
        self.isMessageView = true
        self.updateMessage()
    }
    
    func hideMessages() {
        self.isMessageView = false
        self.updateMessage()
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
            
            self.incListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingFriends").order(by: "timestamp").addSnapshotListener { querySnapshot, error in
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
                        let dat = diff.document.data()
                        print("ADDED FRIEND")
                        print(diff.document.data())
                        withAnimation {
                            self.friends.append(self.niceString(map: dat))
                            self.friendsDict[diff.document.documentID] = dat
                        }
                    }
                    
                    if (diff.type == .modified) {
                        print("REMOVED FRIEND")
                        let dat = diff.document.data()
                        if let index = self.friends.firstIndex(of: self.niceString(map: diff.document.data())) {
                            withAnimation {
                                self.friends.remove(at: index)
                                self.friends.append(self.niceString(map: dat))
                                self.friendsDict[diff.document.documentID] = dat
                            }
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED FRIEND")
                        if let index = self.friends.firstIndex(of: self.niceString(map: diff.document.data())) {
                            withAnimation {
                                self.friends.remove(at: index)
                                self.friendsDict.removeValue(forKey: diff.document.documentID)
                            }
                        }
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
        
        if (self.eventsListener == nil) {
            
            self.eventsListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("events").order(by: "date", descending: true).addSnapshotListener { querySnapshot, error in
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
                        withAnimation {
                            self.events.removeValue(forKey: diff.document.documentID)
                        }
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
        
        if (self.incEventsListener == nil) {
            
            self.incEventsListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("incomingEvents").order(by: "date", descending: true).addSnapshotListener { querySnapshot, error in
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
                        withAnimation {
                            self.incomingEvents.removeValue(forKey: diff.document.documentID)
                        }
                    }
                    
                    self.callAllUpdates()
                }
            }
            
        }
        
        if (self.postListener == nil) {
            
            self.postListener = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("feed").order(by: "timestamp").limit(to: 50).addSnapshotListener { querySnapshot, error in
                guard let snapshot = querySnapshot else {
                    return
                }
                snapshot.documentChanges.forEach { diff in
                    let dat = diff.document.data()
                    if (diff.type == .added) {
                        print("ADDED POST")
                        print(diff.document.data())
                        
                        withAnimation {
                            self.feed.insert(dat, at:0)
                        }
                    }
                    
                    if (diff.type == .removed) {
                        print("REMOVED POST")
//                        if let index = self.friends.firstIndex(of: diff.document.data()) {
//                            withAnimation {
//                                self.feed.remove(at:index)
//                            }
//                        }
                    }
                    
                    self.feedUpdate()
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

    func gets(handler: [[String:String]]?) {
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
    
    func updateFriends() {
        let data = [
            "username":self.currentUser!["username"],
            "display": self.currentUser!["display"],
            "fullname":self.currentUser!["fullname"],
            "pfp": self.currentUser!["pfp"],
            "id": self.currentUser!["id"]
        ]
        
        for friend in friends {
            FirebaseManager.shared.db.collection("users").document(friend["id"]!).collection("friends").document(self.uid ?? "").setData(data as [String : Any])
        }
        
        for friend in incFriendRequests {
            FirebaseManager.shared.db.collection("users").document(friend["id"]!).collection("outgoingFriends").document(self.uid ?? "").setData(data as [String : Any])
        }
        
        for friend in outFriendRequests {
            FirebaseManager.shared.db.collection("users").document(friend["id"]!).collection("incomingFriends").document(self.uid ?? "").setData(data as [String : Any])
        }
        
        self.onFinishEditing()
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
                                HTTPHandler().POST(url: "/addPostsToFeeds", data: ["friendId": data["id"], "myId": self.uid ?? ""], completion: { data in
                                    print("FEED IS BEING ADJUSTED")
                                })
                                
                                self.sendPush(token: (data["token"] as? String) ?? "", fromName: (self.currentUser?["fullname"] as? String) ?? "", title: "New Friend", body: (((data["fullname"] as? String) ?? "") + " has accepted your friend request!"))
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
                        "id": data["id"],
                        "timestamp": Timestamp()
                    ]) { error in
                        if error != nil {
                            return
                        }
                        
                        try? fIncRef.setData([
                            "username":self.currentUser!["username"],
                            "display": self.currentUser!["display"],
                            "fullname":self.currentUser!["fullname"],
                            "pfp": self.currentUser!["pfp"],
                            "id": self.currentUser!["id"],
                            "timestamp": Timestamp()
                        ]) { error in
                            if error != nil {
                                return
                            }
                            self.sendPush(token: (data["token"] as? String) ?? "", fromName: (self.currentUser?["fullname"] as? String) ?? "", title: "New Friend Request", body: (((data["fullname"] as? String) ?? "") + " has sent you a friend request!"))
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
            
            myFriendRef.getDocument { (document, error) in
                if let document = document {
                    if document.exists {
                        HTTPHandler().POST(url: "/removePostsFromFeed", data: ["friendId": data["id"], "myId": self.uid ?? ""], completion: { data in
                            print("FEED IS BEING ADJUSTED")
                        })
                        HTTPHandler().POST(url: "/deleteFriend", data: ["friendId": data["id"], "myId": self.uid ?? ""], completion: { data in
                            print("SUCCESS REMOVING FRIEND MESSAGES")
                            
                        })
                    }
                }
            }
            
            print("ATTEMPT")
            fFriendRef.delete()
            myFriendRef.delete()
            myOutRef.delete()
            myIncRef.delete()
            fOutRef.delete()
            
            fIncRef.delete()
            
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
                self.getUser(id: friend, completionHandler: { datas in
                    let fFriendRef = FirebaseManager.shared.db.collection("users").document(datas?["id"] as? String ?? "").collection("incomingEvents").document(ref!.documentID)
                    
                    fFriendRef.setData(data) { err in
                        if error != nil {
                            return
                        }
                    }
                    
                    self.sendPush(token: (datas?["token"] as? String) ?? "", fromName: data["name"] as? String ?? "", title: data["name"] as? String ?? "", body: ((self.currentUser?["fullname"] as? String) ?? "") + " has invited you to an event!")
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
    
    func updateEvent(data: [String:Any], id: String, completionHandler: @escaping () -> Void) {
        let doc = FirebaseManager.shared.db.collection("events").document(id)
        
        doc.setData(data)
        
        for attendee in data["attending"] as! [String] {
            getUser(id: attendee, completionHandler: { user in
                FirebaseManager.shared.db.collection("users").document(attendee).collection("events").document(id).setData(data)
            })
        }
        
        for attendee in data["invited"] as! [String] {
            getUser(id: attendee, completionHandler: { user in
                FirebaseManager.shared.db.collection("users").document(attendee).collection("incomingEvents").document(id).setData(data)
            })
        }
    }
    
    func joinEvent(id: String) {
        var event = events[id]
        var att = event?["attending"] as! [String]
        var inv = event?["invited"] as! [String]
        
        att.append(self.uid!)
        inv = inv.filter{ $0 != self.uid}
    
        event?["attending"] = att
        event?["invited"] = inv
        
        updateEvent(data: event!, id: id, completionHandler: {})
    
    }
    
    func leaveEvent(id: String) {
        var event = events[id]
        var att = event?["attending"] as! [String]
        var inv = event?["invited"] as! [String]
        
        att = att.filter{ $0 != self.uid}
        inv = inv.filter{ $0 != self.uid}
        
        event?["attending"] = att
        event?["invited"] = inv
        
        FirebaseManager.shared.db.collection("users").document(self.uid!).collection("events").document(id).delete()
        FirebaseManager.shared.db.collection("users").document(self.uid!).collection("incomingEvents").document(id).delete()
        
        if (att.count + inv.count == 0) {
            HTTPHandler().POST(url: "/deleteEvent", data: ["eventId": id], completion: {data in
                print("SUCCESS IN DELETION")
            })
        } else {
            updateEvent(data: event!, id: id, completionHandler: {})
        }
    }
    
    func sendMessage(message: String) {
        
        if self.isFriendMessage == true {
            sendFriendMessage(message: message)
            return
        }
        
        if self.currentEvent == nil {
            return
        }
        let doc = FirebaseManager.shared.db.collection("events")
            .document(currentEvent!)
            .collection("messages")
            .document()
        
        let messageData = ["fromId": self.uid, "text": message, "timestamp": Timestamp(), "name": self.currentUser?["fullname"] ?? ""] as [String:Any]
        
        doc.setData(messageData) { error in
            if let error = error {
                print(error)
                return
            }
            
            print("successfully saved message")
        }
        
        for username in self.events[self.currentEvent ?? ""]?["invited"] as? [String] ?? [] {
            sendPush(username: username, fromName: (self.currentUser?["fullname"] ?? "") as! String, title: self.currentChatName, body: message)
        }
    }
    
    func openEventChat(id: String?) {
        
        self.isFriendMessage = false
        
        if id == nil {
            return
        }
        
        self.currentEvent = id
        
        self.currentChatName = self.events[id!]?["name"] as! String
        
        self.attendingEvent = []
        for ids in self.events[id!]?["attending"] as! [String] {
            getUser(id: ids, completionHandler: { user in
                self.attendingEvent.append(self.niceString(map: user!))
                self.messageViewUpdate()
            })
        }
        
        self.invitingEvent = []
        for ids in self.events[id!]?["invited"] as! [String] {
            getUser(id: ids, completionHandler: { user in
                self.invitingEvent.append(self.niceString(map: user!))
                self.messageViewUpdate()
            })
        }
        
        self.getMessages()
        self.showMessages()
        
    }
    
    func openIncomingEventChat(id: String?) {
        
        self.isFriendMessage = false
        
        if id == nil {
            return
        }
        
        self.currentEvent = id
        
        self.currentChatName = self.incomingEvents[id!]?["name"] as! String
        
        self.getMessages()
        self.showMessages()
        
    }
    
    func openFriendChat(id: String?, name: String?) {
        
        self.isFriendMessage = true
        
        if id == nil {
            return
        }
        
        self.currentEvent = id
        
        self.currentChatName = name ?? ""
        
        self.getFriendMessages()
        self.showMessages()
    }
    
    func getMessages() {
        
        if (chatListener != nil) {
            chatListener?.remove()
        }
        
        self.chatMessages = []
        self.chatListener = FirebaseManager.shared.db
            .collection("events")
            .document(self.currentEvent ?? "")
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener {querySnapshot, error in
                if let error = error {
                    print(error)
                }
                
                querySnapshot?.documentChanges.forEach( {change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                        self.messageViewUpdate()
                    }
                })
            }
    }
    
    func getFriendMessages() {
        if (chatListener != nil) {
            chatListener?.remove()
        }
        
        self.chatMessages = []
        self.chatListener = FirebaseManager.shared.db
            .collection("users")
            .document(self.uid ?? "")
            .collection("messages")
            .document("messages")
            .collection(self.currentEvent ?? "")
            .order(by: "timestamp")
            .addSnapshotListener {querySnapshot, error in
                if let error = error {
                    print(error)
                }
                
                querySnapshot?.documentChanges.forEach( {change in
                    if change.type == .added {
                        let data = change.document.data()
                        self.chatMessages.append(.init(documentId: change.document.documentID, data: data))
                        self.messageViewUpdate()
                    }
                })
            }
    }
    
    func sendFriendMessage(message: String) {
        if self.currentEvent == nil {
            return
        }
        let doc = FirebaseManager.shared.db.collection("users")
            .document(self.uid ?? "")
            .collection("messages")
            .document("messages")
            .collection(self.currentEvent!)
            .document()
        
        let docF = FirebaseManager.shared.db.collection("users")
            .document(self.currentEvent!)
            .collection("messages")
            .document("messages")
            .collection(self.uid ?? "")
            .document()
        
        let messageData = ["fromId": self.uid, "text": message, "timestamp": Timestamp(), "name": self.currentUser?["fullname"] ?? ""] as [String:Any]
        
        doc.setData(messageData) { error in
            if let error = error {
                print(error)
                return
            }
            
            print("successfully saved message")
        }
        
        docF.setData(messageData) { error in
            if let error = error {
                print(error)
                return
            }
            
            print("successfully saved friend message")
        }
        
        self.sendPush(toId: self.currentEvent!, fromName: (self.currentUser?["fullname"] ?? "") as! String, title: (self.currentUser?["fullname"] ?? "") as! String, body: message)
    }
    
    
    func sendPush(toId: String, fromName: String, title: String, body: String) {
        
        getUser(id: toId, completionHandler: { user in
            
            HTTPHandler().POST(url: "/sendMessage", data: ["title": title, "body": body, "token": user?["token"] ?? ""], completion: { data in
                print("Something Happened")
            })
            
        })
    }
    
    func sendPush(username: String, fromName: String, title: String, body: String) {
        
        getUser(username: username, completionHandler: { user in
            
            HTTPHandler().POST(url: "/sendMessage", data: ["title": title, "body": body, "token": user["token"] ?? ""], completion: { data in
                print("Something Happened")
            })
            
        })
    }
    
    func sendPush(token: String, fromName: String, title: String, body: String) {
        
        HTTPHandler().POST(url: "/sendMessage", data: ["title": title, "body": body, "token": token], completion: { data in
            print("Something Happened")
        })

    }
    
    func updateToken() {
        Messaging.messaging().token { token, error in
            if let error = error {
                print(error)
            } else if let token = token {
                print("UPDATING TOKEN")
                let docRef = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").updateData([
                    "token": token
                ]) { err in
                    if let err = err {
                        print(err)
                    } else {
                        print("TOKEN UPDATED")
                    }
                }
            }
        }
    }
    
    func createPost(url: String) {
        
        if (url == "") {
            return
        }
        
        let time = Timestamp()
        let data = [
            "img": url,
            "timestamp": time,
            "id": self.uid ?? ""
        ] as [String : Any]
        
        let docP = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("posts").document()
        
        docP.setData(data)
        
        let docID = docP.documentID
        
        let docF = FirebaseManager.shared.db.collection("users").document(self.uid ?? "").collection("feed").document(docID)
        
        docF.setData(data)
        
        for friend in friends {
            guard let id = friend["id"] else { return }
            let doc = FirebaseManager.shared.db.collection("users").document(id as! String).collection("feed").document(docID)
            doc.setData(data)
        }
    }
    
}
