//
//  CreateProfile.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/10/22.
//

import SwiftUI
import UIKit
import Firebase
import FirebaseStorage
import FirebaseCore
import FirebaseFirestore
import SDWebImageSwiftUI



class ChangeProfileViewModel: ObservableObject {
    @Published var fullname = ""
    @Published var username: String = ""
    @Published var finished = false
    @Published var phoneNumber = ""
    
    @Published var error = false
    @Published var errorMsg = "Error"
    
    @Published var image: UIImage?
    @Published var imgString: String = ""
    
    func update() {
        self.fullname = DataHandler.shared.currentUser?["fullname"] as! String
        self.username = DataHandler.shared.currentUser?["display"] as! String
        self.imgString = DataHandler.shared.currentUser?["pfp"] as! String
    }
    
    func checkUser() {
        
        if (self.username.contains(" ") || self.username.contains("\"") || self.username.contains("'")) {
            self.error = true
            self.errorMsg = "Your username cannot contain any spaces or funny characters (Sorry!)"
            return
        } else {
            error = false
        }
        
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        FirebaseManager.shared.db.collection("users").whereField("username", isEqualTo: self.username.lowercased()).getDocuments() { (querySnapshot, err) in
            print(err)
            if (querySnapshot?.count ?? 1 > 0) {
                for document in querySnapshot?.documents ?? [] {
                    if (document["id"] as? String != DataHandler.shared.uid) {
                        self.nameTaken(decoded: true)
                        return
                    }
                }
                self.nameTaken(decoded: false)
            } else {
                self.nameTaken(decoded: false)
                return
            }
            
        }
        
    }
    
    func nameTaken(decoded: Bool) {
        if decoded {
            self.error = true
            self.errorMsg = "The username you've picked has already been taken (Sorry about that!)"
            return
        } else {
            self.error = false
        }
    }
    
    
    func sendSubmit() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        FirebaseManager.shared.db.collection("users").whereField("username", isEqualTo: self.username).getDocuments() { (querySnapshot, err) in
            print(err)
            if (querySnapshot?.count ?? 1 > 0) {
                for document in querySnapshot?.documents ?? [] {
                    if (document["id"] as? String != DataHandler.shared.uid) {
                        self.nameTaken(decoded: true)
                        return
                    }
                }
                self.nameTaken(decoded: false)
            } else {
                self.nameTaken(decoded: false)
                return
            }
            
        }
        
        
        let newDocRef = FirebaseManager.shared.db.collection("users").document(uid)
        
        try? newDocRef.setData([
            "username":self.username.lowercased(),
            "display": self.username,
            "fullname":self.fullname,
            "pfp": "",
            "id": uid
        ]) { error in
            if error != nil {
                return
            }
            
            let privRef = FirebaseManager.shared.db.collection("users").document(uid).collection("private").document("data")
            
            //            FirebaseManager.shared.db.collection("users").document(uid).collection("friends").document("friends")
            //            FirebaseManager.shared.db.collection("users").document(uid).collection("incomingFriends").document("incomingFriends")
            //            FirebaseManager.shared.db.collection("users").document(uid).collection("outgoingFriends").document("outgoingFriends")
            
        }
        
        DataHandler.shared.load(onComplete: {
            self.persistImageToStorage()
            if (self.image == nil) {
                self.isUserCreated(success: true)
            }
            
        })
        
        
        
        
        
    }
    
    func isUserCreated(success: Bool) {
        self.finished = success
    }
    
    func submit() {
        checkUser()
    }
    
    private func persistImageToStorage() {
        print("PERSIST")
        guard let uid = Auth.auth().currentUser?.uid else { self.isUserCreated(success: true)
            return }
        let ref = Storage.storage().reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else { self.isUserCreated(success: true)
            return }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                print("Failed to push image to Storage: \(err)")
                self.isUserCreated(success: true)
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    print("Failed to retrieve downloadURL: \(err)")
                    self.isUserCreated(success: true)
                    return
                }
                
                
                FirebaseManager.shared.db.collection("users").document(uid).setData([
                    "pfp": url?.absoluteString
                ],merge: true)
                
                
                //                    self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                DataHandler.shared.load(onComplete: {
                    self.isUserCreated(success: true)
                })
                
                print(url?.absoluteString)
            }
        }
    }
}

struct ChangeProfile: View {
    
    enum Field: Hashable {
        case myField
    }
    
    @StateObject var model = ChangeProfileViewModel()
    @State var image: UIImage?
    @State var shouldShowImagePicker = false
    
    @ObservedObject var keyboardResponder = KeyboardResponder()
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack {
            VStack {
                ZStack {
                    Button {
                        focusedField = nil
                        shouldShowImagePicker.toggle()
                    } label: {
                        VStack {
                            if let image = model.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .cornerRadius(75)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 75))
                                    .padding()
                                    .foregroundColor(Color(.label))
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 75)
                            .stroke(Color.black, lineWidth: 3)
                        )
                    }
                    
                }.padding(.bottom,25)
                Text("Your Real Name (What your friends see)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                TextField("Real Name", text:$model.fullname)
                    .focused($focusedField, equals: .myField)
                    .padding(.vertical,20)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(model.fullname == "" ? Color.gray :
                                        Color.pink,lineWidth: 1.5
                                   )
                    )
                Text("Username (How your friends add you)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                TextField("User Name", text:$model.username)
                    .focused($focusedField, equals: .myField)
                    .onChange(of: model.username) {
                        let chhange = $0
                        model.checkUser()
                    }
                    .padding(.vertical,20)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(model.username == "" ? Color.gray :
                                        Color.pink,lineWidth: 1.5
                                   )
                    )
                
                if model.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(model.errorMsg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 20)
                    
                }
                
                Button(action: {
                    model.sendSubmit()
                    focusedField = nil
                }, label: {
                    Text("create account")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.pink)
                        .cornerRadius(8)
                })
                .disabled(model.fullname == "" || model.username == "" || model.error)
                .opacity(model.fullname == "" || model.username == "" || model.error ? 0.6 : 1)
                .padding(.top, 10)
            }
            .padding(.horizontal, 30)
            .offset(y: -keyboardResponder.currentHeight*0.9)
            .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
                ImagePicker(image: $model.image)
                    .ignoresSafeArea()
            }
            .onTapGesture {
                focusedField = nil
            }
        }
        .padding(.bottom, -keyboardResponder.currentHeight*0.9)
    }
    
}

struct ChangeProfile_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfile()
    }
}
