//
//  FriendsPage.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/13/22.
//

import SwiftUI
import Firebase

class FriendsPageViewModel: ObservableObject {
    @Published var searchUser: String = ""
    @Published var error: Bool = false
    @Published var errorMsg: String = ""
    
    @Published var friends: [[String: String]] = [[:]]
    @Published var incomingFriends: [[String: String]] = [[:]]
    @Published var outgoingFriends: [[String: String]] = [[:]]
    
    func checkUser() {
        
        if searchUser == "" {
            return
        }
        HTTPHandler().POST(url: "/doesUserExist", data: [self.searchUser]) { data in
            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                print("Could not decode the data")
                return
            }
            
            if (!decoded["exists"]!) {
                self.error = false
                self.errorMsg = "That user doesn't exist!"
            }
        }
    }
    
    func requestFriend() {
        
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        HTTPHandler().POST(url: "/addFriend", data: ["username": self.searchUser, "id": uid]) { data in
            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                print("Could not decode the data")
                return
            }
            
            if (decoded["success"]!) {
                print("SUCCESS")
            } else {
                print("FAIL")
            }
            
        }
    }
    
    func getFriends() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
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
    
    @State private var image = UIImage()
    
    var body: some View {
        HStack {
            Image(uiImage: self.image)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: 50, maxHeight: 50)
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
        .padding(.horizontal, selectable ? 20 : 0)
        .padding(.vertical, selectable ? 5 : 0)
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
    
    @State private var requestPage = false
    
    @State private var friendSearch: String = ""
    var body: some View {
        VStack {
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
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(model.searchUser == "" ? Color.gray :
                                        Color.pink,lineWidth: 1.5
                                   )
                    )
                
                Image(systemName: "magnifyingglass")
                    .imageScale(.large)
                    .padding(.leading, 10)
                    .onTapGesture {
                        print("TAP")
                        model.requestFriend()
                    }
            }
            .padding()
            .padding(.horizontal, 15)
            if model.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(model.errorMsg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 20)
                
            }
            
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
                    FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", remove: true, update: model.update)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 5)
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                }
                .listStyle(PlainListStyle())
//                Spacer()
            } else {
                ScrollView {
                    if (model.incomingFriends.count > 0) {
                    Text("Incoming Requests")
                        .foregroundColor(Color.gray)
                    ForEach(model.incomingFriends, id: \.self) { friend in
                        FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", add: true, remove: true, incout: true, update: model.update)
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
                        FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", remove: true, incout: true, update: model.update)
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
            }
        }
        .onAppear {
            model.getFriends()
            model.getIncoming()
            model.getOutgoing()
        }
        
    }
}

struct FriendsPage_Previews: PreviewProvider {
    static var previews: some View {
        FriendsPage()
    }
}
