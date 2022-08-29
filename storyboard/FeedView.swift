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
    @Published var friendsDict: [String:[String:Any]] = [:]
    
    func update() {
        self.feed = []
        for post in DataHandler.shared.feed {
            self.feed.append([
                "img": post["img"] as? String ?? "",
                "id": post["id"] as? String ?? ""
            ])
        }
        self.friendsDict = DataHandler.shared.friendsDict
//        self.friendsDict[DataHandler.shared.uid ?? ""] = DataHandler.shared.currentUser
        print("FRIENDSDICT")
        print(friendsDict)
    }
}

struct FeedView: View {
    @Binding var isTakingPicture: Bool
    
    @StateObject var model = FeedViewModel()
    
    var body: some View {
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
                        
                        FriendLabel(name: user?["fullname"] as? String ?? "", username: user?["display"] as? String ?? "", id: user?["id"] as? String ?? "", image: user?["pfp"] as? String).onAppear {
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
    }
}

//struct FeedView_Previews: PreviewProvider {
//    static var previews: some View {
//        FeedView()
//    }
//}
