//
//  FriendsPage.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/13/22.
//

import SwiftUI
import Firebase
import SDWebImageSwiftUI

extension AnyTransition {
    static var inOutTrailing: AnyTransition {
        .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing))
    }
    
    static var inOutLeading: AnyTransition {
        .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading))
    }
}

class FriendsPageViewModel: ObservableObject {
    
    @Published var searchUser: String = ""
    @Published var error: Bool = false
    @Published var errorMsg: String = ""
    @Published var isSearching: Bool = false
    
    @Published var reload: Bool = false
    
    @Published var friends: [[String: String]] = DataHandler.shared.friends
    @Published var incomingFriends: [[String: String]] = DataHandler.shared.incFriendRequests
    @Published var outgoingFriends: [[String: String]] = DataHandler.shared.outFriendRequests
    @Published var searchResults: [[String: String]] = [[:]]
    
    @Published var isEditingProfile: Bool = false
    
    func checkUser() {
        
        if searchUser == "" {
            self.searchResults = [[:]]
            self.error = false
            return
        }
        
        //        if (searchUser.count < 5) {
        //            return
        //        }
        
        DataHandler.shared.getUsers(username: self.searchUser, completionHandler: { arr in
            if (arr.count > 0) {
                self.error = false
                self.searchResults = arr
            } else {
                self.error = true
                self.errorMsg = "This place seems a little empty... Make sure everything is spelled correctly and try again!"
            }
        })
        
    }
    
    func requestFriend(username: String) {
        self.searchResults = [[:]]
        self.searchUser = ""
        self.isSearching = false
        
        DataHandler.shared.addFriend(username: username, completionhandler: {
            self.reload = false
            print("ADDED FRIEND")
        })
        
//        let privRef = FirebaseManager.shared.db.collection("users").document(uid).collection("private").document("data")

            
        
    }
    
    func doneEditing() {
        withAnimation {
            self.isEditingProfile = false
        }
    }
    
    func update() {
        withAnimation {
            self.friends = DataHandler.shared.friends
            self.incomingFriends = DataHandler.shared.incFriendRequests
            self.outgoingFriends = DataHandler.shared.outFriendRequests
        }
        
    }
    
}

class User {
    var name: String = ""
    var pfp: String = ""
    var user: String = ""
    
    init(name: String, user: String, pfp: String = "") {
        self.name = name
        self.pfp = pfp
        self.user = user
    }
}

var CurrentUser: User = User(name: "", user: "")
var loaded = false

struct FriendLabel: View {
    
    
    
    let name: String
    let username: String
    let id: String
    var add = false
    var remove = false
    var incout = false
    var selectable = false
    @State var selected = false
    var update: () -> Void = {}
    var onBeforeRemove: () -> Void = {}
    
    let disabled: Bool = false
    
    var onSelect: () -> Void = {}
    var onUnselect: () -> Void = {}
    
    let image: String?
    
    var canChat = false
    
    var isFriend = false
    
    var body: some View {
        HStack {
            WebImage(url: URL(string:image ?? ""))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 60, maxHeight: 60)
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .background(Color.pink)
                .clipShape(Circle())
                .padding(.trailing, 5)
            VStack {
                HStack {
                    Text(name)
                        .frame(alignment: .leading)
                    Spacer()
                }
                HStack {
                    Text("@" + username)
                        .font(.system(size: 15))
                        .frame(alignment: .leading)
                        .foregroundColor(Color.gray)
                    Spacer()
                }
            }
            Spacer()
            if add {
                Image(systemName: "plus.circle.fill")
                    .imageScale(.large)
                    .font(.system(size: 20))
                    .opacity(disabled ? 0.2 : 0.9)
                    .onTapGesture {
                        if disabled {
                            return
                        }
                        
                        let user = Auth.auth().currentUser
                        guard let uid = user?.uid else {
                            return
                        }
                        
                        DataHandler.shared.addFriend(username: self.username, completionhandler: {
                            print("SUCCESS")
                        })
                        
                        
                    }
            }
            
            if selectable {
                if selected {
                    Image(systemName: "circle.fill")
                        .imageScale(.large)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "circle")
                        .imageScale(.large)
                        .font(.system(size: 20))
                }
            }
            
            if remove {
                Image(systemName: "x.circle.fill")
                    .imageScale(.large)
                    .font(.system(size: 20))
                    .opacity(disabled ? 0.2 : 0.9)
                    .padding(.leading, 15)
                    .onTapGesture {
                        if disabled {
                            return
                            
                        }
                        
                        onBeforeRemove()
                        
                        DataHandler.shared.removeOutFriend(username: self.username, completionHandler: {
                            print("remove Data")
                            update()
                        })
                        
                        
                    }
            }
            
            if (canChat) {
                Image(systemName: "bubble.left")
                    .onTapGesture {
                        DataHandler.shared.openFriendChat(id: id, name: name)
                    }
            }
            
            if (isFriend) {
                Menu {
                    Button(role: .destructive, action: {DataHandler.shared.removeOutFriend(username: self.username, completionHandler: {
                        print("remove Data")
                        update()
                    })}) {
                        Label("Remove Friend", systemImage: "trash.fill")
                    }
                } label: {
                    VStack {
                        Spacer()
                        Image(systemName: "ellipsis")
                        
                            .padding(3)
                        //                    .imageScale(.large)
                            .rotationEffect(Angle(degrees: 90))
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, selectable ? 15 : 0)
        .padding(.vertical, selectable ? 10 : 0)
        .background(selectable ? (selected ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color.black) : Color.black)
        .onTapGesture {
            if (selectable) {
                selected = !selected
                if (selected) {
                    onSelect()
                } else {
                    onUnselect()
                }
                update()
            }
        }
        
    }
}

struct FriendsPage: View {
    
    enum Field: Hashable {
        case myField
    }
    
    @FocusState private var focusedField: Field?
    
    @EnvironmentObject var model: FriendsPageViewModel
    
    @State var load = false
    
    @State var reload = true
    
    @ObservedObject var keyboardResponder = KeyboardResponder()
    
    @State private var requestPage = false
    @State private var change = false
    
    @State private var friendSearch: String = ""
    var body: some View {
        ZStack{
            VStack {
//
                
                if DataHandler.shared.currentUser != nil && DataHandler.shared.currentUser!["display"] as! String != "" {
                    
                    HStack {
                        WebImage(url: URL(string:DataHandler.shared.currentUser!["pfp"] as! String ))
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 75, maxHeight: 75)
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .background(Color.pink)
                            .clipShape(Circle())
                            .padding(.trailing, 5)
                        VStack {
                            HStack {
                                Text(DataHandler.shared.currentUser!["fullname"] as! String)
                                    .frame(alignment: .leading)
                                    .font(.system(size: 22))
                                Spacer()
                            }
                            HStack {
                                Text("@" + (DataHandler.shared.currentUser!["display"] as! String))
                                    .font(.system(size: 17))
                                    .frame(alignment: .leading)
                                    .foregroundColor(Color.gray)
                                Spacer()
                            }
                        }
                        Spacer()
                        Menu {
                            Button(action: {
                                withAnimation {
                                    model.isEditingProfile = true
                                }
                            }) {
                                Label("Edit Profile", systemImage: "square.and.pencil")
                            }
                            Button(role: .destructive, action: {
                                do {
                                    try Auth.auth().signOut()
                                    exit(-1)
                                } catch let signOutError as NSError {
                                  print("Error signing out: %@", signOutError)
                                }
                            }) {
                                Label("Sign Out", systemImage: "arrow.turn.down.left")
                            }
                        } label: {

                                Image(systemName: "gearshape.fill")
                                
                                    .padding(3)
                                    .imageScale(.large)


                        }
                    }
                    .padding([.leading,.trailing],20)
                    .padding([.top],6)
                    .onAppear {
                        withAnimation {
                            load = true
                            print("LOADING")
                        }
                    }
                }
                
                
                
                
                if load == true {
                    
                    HStack {
                        if !requestPage {
                            Text("Friends")
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(height:2, alignment: .bottom)
                                        .offset(y: 15)
                                )
                                .padding(.horizontal, 10)
                            Text("Requests")
                                .padding(.horizontal, 10)
                                .onTapGesture {
                                    change = true
                                    requestPage = true
                                }
                        }
                        else {
                            Text("Friends")
                                .padding(.horizontal, 10)
                                .onTapGesture {
                                    requestPage = false
                                }
                            Text("Requests")
                                .overlay(
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(height:2, alignment: .bottom)
                                        .offset(y: 15)
                                )
                                .padding(.horizontal, 10)
                        }
                    }.padding(.bottom, 20)
                    
                    
                    
                    if !requestPage {
                        if (model.friends.count > 0 && model.friends[0]["username"] != nil) {
                            List(model.friends, id: \.self) { friend in
                                FriendLabel(name:friend["fullname"] ?? "",username:friend["display"] ?? "", id:friend["id"] ?? "", update: model.update, image: friend["pfp"], canChat: true, isFriend: true)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 5)
                                    .listRowBackground(Color.black)
                                    .listRowSeparator(.hidden)
                            }
                            .listStyle(PlainListStyle())
                            .animation(.easeInOut)
                            .transition(load == true && change == true ? .inOutLeading : .opacity)
                            //                Spacer()
                        }
                        else {
                            Text("There's nothing here for now. Tap the add friend button and type in your friend's unique username!")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 25)
                                .foregroundColor(Color.gray.opacity(0.8))
                                .padding(.top, 20)
                                .listStyle(PlainListStyle())
                                .animation(.easeInOut)
                                .transition(load == true && change == true ? .inOutLeading : .opacity)
                        }
                    } else {
                        ScrollView {
                            if (model.incomingFriends.count > 0 && model.incomingFriends[0]["username"] != nil) {
                                Text("Incoming Requests")
                                    .foregroundColor(Color.gray)
                                ForEach(model.incomingFriends, id: \.self) { friend in
                                    FriendLabel(name:friend["fullname"] ?? "",username:friend["display"] ?? "", id:friend["id"] ?? "", add: true, remove: true, incout: true, update: model.update, image: friend["pfp"])
                                        .padding(.vertical,5)
                                        .padding(.horizontal,25)
                                        .listRowBackground(Color.black)
                                        .listRowSeparator(.hidden)
                                }
                                .listStyle(PlainListStyle())
                            }
                            if (model.outgoingFriends.count > 0 && model.outgoingFriends[0]["username"] != nil) {
                            
                                Text("Outgoing Requests")
                                    .foregroundColor(Color.gray)
                                ForEach(model.outgoingFriends, id: \.self) { friend in
                                    FriendLabel(name:friend["fullname"] ?? "",username:friend["display"] ?? "", id:friend["id"] ?? "", remove: true, incout: true, update: model.update, onBeforeRemove: {model.reload = true}, image: friend["pfp"])
                                        .padding(.vertical,5)
                                        .padding(.horizontal,25)
                                        .listRowBackground(Color.black)
                                        .listRowSeparator(.hidden)
                                }
                                .listStyle(PlainListStyle())
                            }
                            if (model.outgoingFriends.count == 0 && model.incomingFriends.count == 0) {
                                Text("You don't have any pending friend requests right now. Tap the add friend button and type in your friend's unique username!")
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 25)
                                    .foregroundColor(Color.gray.opacity(0.8))
                                    .padding(.top, 20)
                            }
                            Spacer()
                        }
                        .padding(.top, 15)
                        .animation(.easeInOut)
                        .transition(load ? .move(edge: .trailing) : .opacity)
                    }
                }
                Spacer()
            }
            .onAppear {
                DataHandler.shared.friendPageUpdate = model.update
                DataHandler.shared.onFinishEditing = model.doneEditing
                model.update()
            }
            
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {withAnimation {model.isSearching = true}}, label: {
                        Text("add friend")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            .background(Color.pink)
                            .cornerRadius(8)
                    })
                    .padding(.top,10)
                    .padding(.bottom,25)
                    .padding(.horizontal)
                }
            }
            
            
            if model.isSearching {
                
                VStack {
                    
                    ZStack {
                        HStack {
                            Image(systemName: "chevron.backward").onTapGesture {
                                withAnimation {
                                    model.isSearching = false
                                }
                            }
                            Spacer()
                        }
                        Text("Search for a User")
                            .font(.system(size: 20))
                        
                        
                    }.padding()
                    
                    HStack{
                        TextField("Username", text:$model.searchUser)
                            .focused($focusedField, equals: .myField)
                            .onChange(of: model.searchUser) {
                                print($0)
                                model.checkUser()
                            }
                            .padding(.vertical,15)
                            .padding(.horizontal)
                            .background(
                                Color(red: 46.0/255, green: 46.0/255, blue: 46.0/255)
                            )
                            .cornerRadius(16)
                        
                    }
                    .padding()
                    .padding(.horizontal, 15)
                    if model.error {
                        
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(model.errorMsg)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding([.bottom], 10)
                        .padding(.horizontal, 30)
                        
                    }
                    ScrollView {
                        if (model.searchResults.count > 0 && model.searchResults[0] != [:]) {
                            ForEach(model.searchResults, id: \.self) { friend in
                                FriendLabel(name:friend["fullname"] ?? "",username:friend["display"] ?? "", id:friend["id"] ?? "", selectable: true, onSelect: {
                                    withAnimation {
                                        focusedField = nil
                                        model.requestFriend(username: friend["username"] ?? "")
                                        requestPage = true
                                    }
                                }, onUnselect: {}, image: friend["pfp"])
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                
                            }
                            .listStyle(PlainListStyle())
                        }
                    }
                    Spacer()
                    
                }
                .background(Color.black)
                .cornerRadius(8)
                //                .offset(y: -keyboardResponder.currentHeight*0.9)
                .transition(.move(edge: .bottom))
                .onAppear {
                    withAnimation{
                        model.reload = true
                    }
                }
                
                
            }
            
        
            
        }.onTapGesture {
            focusedField = nil
        }
        
        
        
        
    }
}

struct FriendsPage_Previews: PreviewProvider {
    static var previews: some View {
        FriendsPage()
    }
}
