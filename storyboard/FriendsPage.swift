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
    
    @Published var friends: [[String: String]] = [[:]]
    @Published var incomingFriends: [[String: String]] = [[:]]
    @Published var outgoingFriends: [[String: String]] = [[:]]
    @Published var searchResults: [[String: String]] = [[:]]
    
    func checkUser() {
        
        if searchUser == "" {
            self.searchResults = [[:]]
            self.error = false
            return
        }
        
        //        if (searchUser.count < 5) {
        //            return
        //        }
        
        HTTPHandler().POST(url: "/getUsers", data: ["search": self.searchUser]) { data in
            guard let decoded = try? JSONDecoder().decode([[String: String]].self, from: data) else {
                print("Could not decode the data")
                return
            }
            
            if (decoded.count < 1) {
                self.error = true
                self.errorMsg = "This place seems a little empty... Make sure everything is spelled correctly and try again!"
            } else {
                self.searchResults = decoded
                self.error = false
            }
        }
    }
    
    func requestFriend(username: String) {
        
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        HTTPHandler().POST(url: "/addFriend", data: ["username": username, "id": uid]) { data in
            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                print("Could not decode the data")
                return
            }
            
            if (decoded["success"]!) {
                print("SUCCESS")
                self.searchResults = [[:]]
                self.searchUser = ""
                self.isSearching = false
                self.getIncoming()
                self.getOutgoing()
                
            } else {
                print("FAIL")
                self.searchResults = [[:]]
                self.searchUser = ""
                self.isSearching = false
                
                
            }
            
        }
    }
    
    func getFriends() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        try HTTPHandler().POST(url: "/getSelf", data: ["id": uid], completion: { data in
            guard let decoded = try? JSONDecoder().decode([String: [String:String]].self, from: data) else {
                print("Could not decode the data")
                return
            }
            let user = decoded["user"]!
            
            CurrentUser.user = user["username"]!
            CurrentUser.name = user["fullname"]!
            CurrentUser.pfp = user["pfp"]!
            
            print(decoded)
        })
        
        
        HTTPHandler().POST(url: "/getFriends", data: ["id": uid], completion: { data in
            guard let decoded = try? JSONDecoder().decode([String: [[String:String]]].self, from: data) else {
                print("Could not decode the data")
                return
            }
            self.friends = decoded["friends"]!
            print(decoded)
        })
    }
    
    func getIncoming() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        HTTPHandler().POST(url: "/getIncomingFriends", data: ["id": uid], completion: { data in
            guard let decoded = try? JSONDecoder().decode([String: [[String:String]]].self, from: data) else {
                print("Could not decode the data")
                return
            }
            self.incomingFriends = decoded["friends"]!
            print(decoded)
        })
    }
    
    func getOutgoing() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        HTTPHandler().POST(url: "/getOutgoingFriends", data: ["id": uid], completion: { data in
            guard let decoded = try? JSONDecoder().decode([String: [[String:String]]].self, from: data) else {
                print("Could not decode the data")
                return
            }
            self.outgoingFriends = decoded["friends"]!
            print(decoded)
        })
    }
    
    func update() {
        getOutgoing()
        getIncoming()
        getFriends()
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
    var add = false
    var remove = false
    var incout = false
    var selectable = false
    @State var selected = false
    var update: () -> Void = {}
    
    let disabled: Bool = false
    
    var onSelect: () -> Void = {}
    var onUnselect: () -> Void = {}
    
    let image: String?
    
    var body: some View {
        HStack {
            WebImage(url: URL(string:image ?? ""))
                .resizable()
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
                        
                        HTTPHandler().POST(url: "/addFriend", data: ["username": self.username, "id": uid]) { data in
                            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                                print("Could not decode the data")
                                return
                            }
                            
                            if (decoded["success"]!) {
                                print("SUCCESS")
                                update()
                            } else {
                                print("FAIL")
                            }
                            
                        }
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
                        let user = Auth.auth().currentUser
                        guard let uid = user?.uid else {
                            return
                        }
                        
                        HTTPHandler().POST(url: (incout) ? "/removeIncOutFriend" : "/removeFriend", data: ["username": self.username, "id": uid]) { data in
                            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                                print("Could not decode the data")
                                return
                            }
                            
                            if (decoded["success"]!) {
                                print("SUCCESS")
                                update()
                            } else {
                                print("FAIL")
                            }
                            
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
    
    @StateObject var model = FriendsPageViewModel()
    
    @ObservedObject var keyboardResponder = KeyboardResponder()
    
    @State private var requestPage = false
    
    @State private var friendSearch: String = ""
    var body: some View {
        ZStack{
            VStack {
                //            Button(action: {try! Auth.auth().signOut()}, label: {
                //                Text("next")
                //                    .fontWeight(.bold)
                //                    .foregroundColor(.white)
                //                    .padding(.vertical)
                //                    .frame(maxWidth: .infinity)
                //                    .background(Color.pink)
                //                    .cornerRadius(8)
                //            })
                //            .padding(.top,10)
                //            .padding(.bottom,55)
                //            .padding(.horizontal)
                
                if CurrentUser.name != "" {
                    
                    HStack {
                        WebImage(url: URL(string:CurrentUser.pfp ))
                            .resizable()
                            .frame(maxWidth: 75, maxHeight: 75)
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                            .background(Color.pink)
                            .clipShape(Circle())
                            .padding(.trailing, 5)
                        VStack {
                            HStack {
                                Text(CurrentUser.name)
                                    .frame(alignment: .leading)
                                    .font(.system(size: 22))
                                Spacer()
                            }
                            HStack {
                                Text("@" + CurrentUser.user)
                                    .font(.system(size: 17))
                                    .frame(alignment: .leading)
                                    .foregroundColor(Color.gray)
                                Spacer()
                            }
                        }
                        Spacer()
                        Image(systemName: "square.and.pencil")
                            .imageScale(.large)
                            .font(.system(size: 20))
                    }
                    .padding([.leading,.trailing],20)
                    .padding([.top],6)
                    .onAppear {
                        withAnimation {loaded = true}
                    }
                }
                
                
                
                
                if loaded {
                    
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
                        List(model.friends, id: \.self) { friend in
                            FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", remove: true, update: model.update, image: friend["pfp"])
                                .padding(.horizontal, 5)
                                .padding(.vertical, 5)
                                .listRowBackground(Color.black)
                                .listRowSeparator(.hidden)
                        }
                        .listStyle(PlainListStyle())
                        .animation(.easeInOut)
                        .transition(loaded == true ? .inOutLeading : .opacity)
                        //                Spacer()
                    } else {
                        ScrollView {
                            if (model.incomingFriends.count > 0) {
                                Text("Incoming Requests")
                                    .foregroundColor(Color.gray)
                                ForEach(model.incomingFriends, id: \.self) { friend in
                                    FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", add: true, remove: true, incout: true, update: model.update, image: friend["pfp"])
                                        .padding(.vertical,5)
                                        .padding(.horizontal,25)
                                        .listRowBackground(Color.black)
                                        .listRowSeparator(.hidden)
                                }
                                .listStyle(PlainListStyle())
                            }
                            if (model.outgoingFriends.count > 0) {
                                Text("Outgoing Requests")
                                    .foregroundColor(Color.gray)
                                ForEach(model.outgoingFriends, id: \.self) { friend in
                                    FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", remove: true, incout: true, update: model.update, image: friend["pfp"])
                                        .padding(.vertical,5)
                                        .padding(.horizontal,25)
                                        .listRowBackground(Color.black)
                                        .listRowSeparator(.hidden)
                                }
                                .listStyle(PlainListStyle())
                            }
                            Spacer()
                        }
                        .padding(.top, 15)
                        .animation(.easeInOut)
                        .transition(loaded ? .move(edge: .trailing) : .opacity)
                    }
                }
                Spacer()
            }
            .onAppear {
                model.getFriends()
                model.getIncoming()
                model.getOutgoing()
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
                                FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", selectable: true, onSelect: {
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
