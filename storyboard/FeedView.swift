//
//  FeedView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 8/20/22.
//

import SwiftUI
import AVFoundation
import FirebaseMessaging
import FirebaseStorage
import FirebaseCore
import FirebaseFirestore
import SDWebImageSwiftUI

class FeedViewModel: ObservableObject {
    
    @Published var feed: [[String: String]] = []
    @Published var oldfeed: [[String: String]] = []
    @Published var friendsDict: [String:[String:Any]] = [:]
    @Published var showComments = false
    
    @Published var comments: [[String: String]] = []
    
    @Published var currentUser: String = ""
    @Published var currentDocID: String = ""
    
    func update() {
        self.oldfeed = self.feed
        self.feed = []
        var index = 0
        for post in DataHandler.shared.feed {
            self.feed.append([
                "img": post["img"] as? String ?? "",
                "id": post["id"] as? String ?? "",
                "docID": post["docID"] as? String ?? "",
                "liked": (post["liked"] as? Bool ?? false) ? "true" : "false",
                "index": String(index),
                "likes": index < self.oldfeed.count ? self.oldfeed[index]["likes"] ?? "0" : "0"
            ])
            DataHandler.shared.getPost(user: post["id"] as? String ?? "", docID: post["docID"] as? String ?? "", index: index, completionHandler: {(postR, ind) in
                print(ind)
                self.feed[ind]["likes"] = String(postR["likes"] as? Int ?? 0)
            })
            index += 1
        }
        self.friendsDict = DataHandler.shared.friendsDict
        //        self.friendsDict[DataHandler.shared.uid ?? ""] = DataHandler.shared.currentUser
        print("FRIENDSDICT")
//        print(friendsDict)
    }
    
    func updateComments() {
        print("COMMENTS")
        self.comments = DataHandler.shared.comments
        self.showComments = true
        print(self.comments)
    }
}

struct FeedView: View {
    
    @Binding var isTakingPicture: Bool
    
    @StateObject var model = FeedViewModel()
    
    @State var eventScroll = CGFloat(100)
    
    enum Field: Hashable {
        case myField
    }
    
    @FocusState private var focusedField: Field?
    
    @State private var contentSize: CGSize = .zero
    @State private var message: String?
    
    
    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: {isTakingPicture = true}) {
                        Label("", systemImage: "plus")
                            .imageScale(.large)
                    }
                    Spacer()
                    Text("feed")
                    Spacer()
                    Button(action: {}) {
                        Label("", systemImage: "plus")
                            .imageScale(.large)
                    }.opacity(0.0)
                }
                .padding([.trailing , .leading ], 15)
                .background(Color.black)
                .onAppear {
                    model.update()
                    DataHandler.shared.commentsUpdate = model.updateComments
                    DataHandler.shared.feedUpdate = model.update
                }
                //            .overlay(
                //                Rectangle()
                //                    .fill(Color.white.opacity(0.9))
                //                    .frame(height:1, alignment: .bottom)
                //                    .offset(y: 15)
                //            )
                if (model.feed.count > 0) {
                    List(model.feed, id: \.self) { post in
                        if (post["img"] != "") {
                            WebImage(url: URL(string: post["img"] ?? ""))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                .padding([.top], 5)
                                
                            let user = model.friendsDict[post["id"] ?? ""] ?? ( (DataHandler.shared.uid == post["id"]) ? DataHandler.shared.currentUser : nil)
                            HStack {
                                FriendLabel(name: user?["fullname"] as? String ?? "", username: user?["display"] as? String ?? "", id: user?["id"] as? String ?? "", image: user?["pfp"] as? String).onAppear {
                                }
                                Button(action: {
                                    if (post["liked"] == "true") {
                                        DataHandler.shared.unlikePost(user: post["id"] ?? "", docID: post["docID"] ?? "")
                                    } else {
                                        DataHandler.shared.likePost(user: post["id"] ?? "", docID: post["docID"] ?? "")
                                    }
                                }, label: {
                                    Image(systemName: post["liked"] == "true" ? "heart.fill" : "heart").imageScale(.large)
                                        .foregroundColor(post["liked"] == "true" ? Color.pink : Color.white)
                                }).buttonStyle(PlainButtonStyle())
                                Text(post["likes"] ?? "")
                                Button(action: {
                                    withAnimation {
                                        model.currentUser = post["id"] ?? ""
                                        model.currentDocID = post["docID"] ?? ""
                                        model.comments = []
                                        DataHandler.shared.getComments(user: post["id"] ?? "", docID: post["docID"] ?? "")
                                        model.showComments = true
                                    }
                                }, label: {
                                    Image(systemName: "plus.bubble").imageScale(.large)
                                }).buttonStyle(PlainButtonStyle())
                                
                            }
                            
                        }
                    }
                    
                    .listStyle(PlainListStyle())
                    
                    
                }
                else {
                    Text("It's quiet... for now!")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 25)
                        .foregroundColor(Color.gray.opacity(0.8))
                        .padding(.top, 40)
                    Text("Add a friend to recieve their events and stories!")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 25)
                        .foregroundColor(Color.gray.opacity(0.8))
                    Spacer()
                }
            }
            if (model.showComments) {
                VStack {
                    VStack {
                        HStack {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: 30, height: 8)
                                .cornerRadius(2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(15)
                        
                        HStack {
                            
                            ScrollView {
                                ZStack(alignment: .topLeading) {
                                    Color(red: 46.0/255, green: 46.0/255, blue: 46.0/255)
                                    //                            Color.gray
                                        .opacity(1)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    Text(message ?? "Message")
                                        .padding()
                                        .opacity(message == nil ? 0.5 : 0)
                                        
                                    TextEditor(text: Binding($message, replacingNilWith: ""))
                                        if #available(iOS 16.0, *) {
                                            .scrollContentBackground(.hidden)
                                        }
                                        .frame(minHeight: 30, alignment: .leading)
                                        .cornerRadius(6.0)
                                        .multilineTextAlignment(.leading)
                                        .padding(9)
                                        .background(Color.clear)
                                        .opacity(1)
                                    
                                    
                                }
                                .overlay(GeometryReader { geo in
                                    Color.clear.opacity(0).onAppear {
                                        contentSize = geo.size
                                    }
                                })
                            }
                            .frame(maxHeight: contentSize.height)
                            Image(systemName: "paperplane.fill")
                                .opacity(message != "" && message != nil ? 1 : 0.5)
                                .frame(width: 20, height: 20)
                                .padding(.vertical)
                                .padding(.horizontal, 10)
                                .background(Color.pink.opacity(message != "" && message != nil ? 1 : 0.5))
                                .clipShape(Circle())
                                .onTapGesture {
                                    if (message != "" && message != nil) {
                                        DataHandler.shared.sendComment(message: message ?? "", user: model.currentUser, docID: model.currentDocID)
                                        message = ""
                                    }
                                }
                                .padding(.horizontal, 15)
                        }.onTapGesture {
                            self.hideKeyboard()
                            focusedField = nil
                        }
                        
                        ScrollView {
                            
                            VStack {
                                
                                ForEach (model.comments, id: \.self) { comment in
                                    
                                    HStack {
                                        WebImage(url: URL(string:comment["pfp"] ?? ""))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: 60, maxHeight: 60)
                                            .scaledToFill()
                                            .edgesIgnoringSafeArea(.all)
                                            .background(Color.pink)
                                            .clipShape(Circle())
                                            .padding(.trailing, 5)
                                            .onTapGesture {
                                                withAnimation {
                                                    DataHandler.shared.updateCurrentUserPage(id: (comment["id"] ?? ""), currentUser: ((DataHandler.shared.uid ?? "") == (comment["id"] ?? "1")) ? true : false)
                                                }
                                            }
                                        Text(comment["fullname"] ?? "").bold() + Text(" " + (comment["message"] ?? ""))
                                        Spacer()
                                    
                                    }
                                }
                            }
                            
                            
                        }
                        Spacer()
                    }.frame(height: 700)
                    //                    .offset(y: 20)
                        .gesture(DragGesture()
                            .onChanged {
                                print($0)
                                print("ALOHA")
                            }
                        )
                    
                    
                }
                .padding(5)
                .background(Color.black)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .offset(y: CGFloat(eventScroll))
                .transition(.move(edge: .bottom))
                .gesture(DragGesture()
                    .onChanged {
                        if ($0.location.y < 0) {
                            return
                        }
                        eventScroll = $0.location.y
                    }
                    .onEnded {
                        print($0.translation.height)
                        withAnimation(.easeInOut) {
                            if (eventScroll > 250) {
                                eventScroll = 100
                                model.showComments = false
                            } else {
                                eventScroll = 100
                            }
                        }
                    })
            }
        }
        .transition(.move(edge: .bottom))
        .frame(maxWidth: .infinity)
        .onAppear {
            UITextView.appearance().backgroundColor = .clear
        }
        .onTapGesture {
            self.hideKeyboard()
            focusedField = nil
        }
        
    }
    
}


//struct FeedView_Previews: PreviewProvider {
//    static var previews: some View {
//        FeedView()
//    }
//}
