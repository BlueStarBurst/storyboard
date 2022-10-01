//
//  UserPage.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 9/22/22.
//

import SwiftUI
import SDWebImageSwiftUI

class UserPageModel: ObservableObject {
    
    @Published var currentUserPage = ""
    @Published var posts: [[String: String]] = []
    @Published var dat: [String:Any] = [:]
    
    func update() {
        withAnimation {
            self.posts = []
            for post in DataHandler.shared.posts {
                self.posts.append([
                    "img": post["img"] as? String ?? "",
                    "id": post["id"] as? String ?? ""
                ])
            }
            self.dat = DataHandler.shared.userPageDat ?? [:]
            self.currentUserPage = DataHandler.shared.currentUserPage ?? ""
//            DataHandler.shared.pageUpdate(3)
        }
    }
    
}

struct UserPage: View {
    @StateObject var model = UserPageModel()
    @State var gridLayout: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
    
    @State var showImg = false
    @State var imgUrl = ""
    @State var eventScroll: CGFloat = CGFloat(0)
    @State var startScroll: CGFloat = CGFloat(0)
    @State var dragging = false
    
    var body: some View {
        ZStack {
        VStack {
            if (model.dat.keys.count > 0) {
            HStack {
                WebImage(url: URL(string:model.dat["pfp"] as! String ))
                    .resizable()
                    .scaledToFill()
//                    .frame(height: )
                    .frame(maxWidth: 80, maxHeight: 80)
                    .scaledToFill()
//                    .scaledToFill()
                    .background(Color.pink)
                    .clipShape(Circle())
//                    .padding(.trailing, 5)
                VStack {
                    HStack {
                        Text(model.dat["fullname"] as! String)
                            .frame(alignment: .leading)
                            .font(.system(size: 22))
                        Spacer()
                    }
                    HStack {
                        Text("@" + (model.dat["display"] as! String))
                            .font(.system(size: 17))
                            .frame(alignment: .leading)
                            .foregroundColor(Color.gray)
                        Spacer()
                    }
                }
                Spacer()
                Menu {
                    Button(action: {DataHandler.shared.removeOutFriend(username: model.dat["username"] as! String, completionHandler: {
                        print("remove Data")
                        model.update()
                    })}) {
                        Label("Block User", systemImage: "trash.fill")
                    }
                    Button(role: .destructive, action: {DataHandler.shared.removeOutFriend(username: model.dat["username"] as! String, completionHandler: {
                        print("remove Data")
                        model.update()
                    })}) {
                        Label("Remove Friend", systemImage: "trash.fill")
                    }
                } label: {
                    VStack {
                        Image(systemName: "ellipsis")
                        
                            .padding(3)
                        //                    .imageScale(.large)
                            .rotationEffect(Angle(degrees: 90))
                    }
                }
            }
            .frame(alignment: .center)
            .padding(.horizontal, 10)
//            .padding(.bottom, 20)
                
                Button(action: {
                    DataHandler.shared.openFriendChat(id: model.currentUserPage, name: model.dat["fullname"] as! String)
                }, label: {
                    Text("message")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.pink)
                        .cornerRadius(8)
                })
                .padding(.top,6)
                .padding(.bottom,15)
                .padding(.horizontal)
                .disabled(DataHandler.shared.uid == model.currentUserPage)
                .opacity((DataHandler.shared.uid == model.currentUserPage) ? 0.6 : 1)
            
                
            ScrollView {
                    LazyVGrid(columns: gridLayout, alignment: .center, spacing: 10) {

                        ForEach(model.posts, id: \.self) { post in
                            if (post["img"] != "") {
                                WebImage(url: URL(string: post["img"] ?? ""))
                                    .resizable()
                                    .scaledToFill()
//                                    .aspectRatio(1/1, contentMode: .fill)
                                    .frame(minWidth: 0, maxWidth: .infinity)
//                                    .frame(height: 100)
//                                    .frame(height: 200)
//                                    .cornerRadius(10)
                                    .shadow(color: Color.primary.opacity(0.3), radius: 1)
                                    .onTapGesture {
                                        withAnimation {
                                            imgUrl = post["img"] ?? ""
                                            showImg = true
                                        }
                                    }
                            }

                        }
                    }
//                    .padding(.all, 10)
                }
            }
    }
        .onAppear {
            DataHandler.shared.userPageUpdate = model.update
            model.update()
        }
            if (showImg) {
                VStack {
                    if (model.dat.keys.count > 0) {
                        WebImage(url: URL(string: imgUrl))
                            .resizable()
                            .scaledToFill()
                            .offset(y: CGFloat(eventScroll))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .gesture(DragGesture()
                                .onChanged {
                                    if ($0.location.y < 0) {
                                        return
                                    }
                                    if (dragging == false) {
                                        dragging = true
                                        startScroll = $0.location.y
                                    }
                                    eventScroll = ($0.location.y - startScroll)
                                }
                                .onEnded {
                                    print($0.translation.height)
                                    withAnimation(.easeInOut) {
                                        dragging = false
                                        if (eventScroll > 250) {
                                            eventScroll = 350
                                            withAnimation {
                                                showImg = false
                                            }
                                        } else {
                                            eventScroll = 0
                                        }
                                    }
                                })
                            .onAppear {
                                eventScroll = 0
                                startScroll = 0
                            }
                    }
                }
                .transition(.move(edge: .bottom))
                
            }
    }
    }
}

struct UserPage_Previews: PreviewProvider {
    static var previews: some View {
        UserPage()
    }
}
