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
import JWTKit

//class FirebaseManager: NSObject {
//
//    let auth: Auth
//    let storage: Storage
//
//    static let shared = FirebaseManager()
//
//    override init() {
//        FirebaseApp.configure()
//
//        self.auth = Auth.auth()
//        self.storage = Storage.storage()
//
//        super.init()
//    }
//
//}

struct ImagePicker: UIViewControllerRepresentable {

    @Binding var image: UIImage?

    private let controller = UIImagePickerController()

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

        let parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

    }

    func makeUIViewController(context: Context) -> some UIViewController {
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {

    }

}


class CreateProfileViewModel: ObservableObject {
    @Published var fullname = ""
    @Published var username: String = ""
    @Published var finished = false
    @Published var phoneNumber = ""
    
    @Published var error = false
    @Published var errorMsg = "Error"
    
    @Published var image: UIImage?
    
    func checkUser() {
        
        if (self.username.contains(" ") || self.username.contains("\"") || self.username.contains("'")) {
            self.error = true
            self.errorMsg = "Your username cannot contain any spaces or funny characters (Sorry!)"
            return
        } else {
            error = false
        }
        
        let user = Auth.auth().currentUser
        user?.getIDToken(completion: {(res,err) in
            if err != nil {
                print("error :(")
            } else {
                Task {
                    print("tokens!")
                    
                    let url = URL(string: "https://storyboard-server.herokuapp.com/doesUserExist")!
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(res, forHTTPHeaderField: "AuthToken")
                    request.httpMethod = "POST"
                    
                    guard let encoded = try? JSONEncoder().encode([self.username]) else {
                        print("oh no")
                        return
                    }
                    
                    do {
                        let (data,_) = try await URLSession.shared.upload(for: request, from: encoded)
                        
                        guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                            print("oh no")
                            return
                        }
                        print(decoded) // CHECK EXISTS
                        DispatchQueue.main.async {
                            self.nameTaken(decoded: decoded["exists"] ?? false)
                        }
                        
                    }
                    catch {
                        print("failure")
                    }
                    //                    task.resume()
                }
                
            }
        })
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
        user?.getIDToken(completion: {(res,err) in
            if err != nil {
                print("error :(")
            } else {
                Task {
                    print("tokens!")
                    
                    let url = URL(string: "https://storyboard-server.herokuapp.com/createUser")!
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(res, forHTTPHeaderField: "AuthToken")
                    request.httpMethod = "POST"
                    
                    guard let encoded = try? JSONEncoder().encode(["username":self.username,"phone": self.phoneNumber,"fullname":self.fullname,"pfp": "", "id": uid]) else {
                        print("oh no")
                        return
                    }
                    
                    do {
                        let (data,_) = try await URLSession.shared.upload(for: request, from: encoded)
                        
                        guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                            print("oh no")
                            return
                        }
                        print(decoded) // CHECK EXISTS
                        DispatchQueue.main.async {
                            self.isUserCreated(success: decoded["success"] ?? false)
                        }
                        
                    }
                    catch {
                        print("failure")
                    }
                    //                    task.resume()
                }
                
            }
        })
        
    }
    
    func isUserCreated(success: Bool) {
        if success == true {
            persistImageToStorage()
        }
        self.finished = success
    }
    
    func submit() {
        checkUser()
    }
    
    private func persistImageToStorage() {
        print("PERSIST")
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = Storage.storage().reference(withPath: uid)
        guard let imageData = self.image?.jpegData(compressionQuality: 0.5) else { return }
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                print("Failed to push image to Storage: \(err)")
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    print("Failed to retrieve downloadURL: \(err)")
                    return
                }
                
                let user = Auth.auth().currentUser
                guard let uid = user?.uid else {
                    return
                }
                
                
                
                HTTPHandler().POST(url: "/setPfp", data: ["id": uid, "pfp": url?.absoluteString], completion: { data in
                    guard let decoded = try? JSONDecoder().decode([String:String].self, from: data) else {
                        print("Could not decode the data")
                        return
                    }
                    print("AAAAAAAAAAA")
                    print(decoded)
                })
                
                //                    self.loginStatusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                print(url?.absoluteString)
            }
        }
    }
}

struct CreateProfile: View {
    
    enum Field: Hashable {
        case myField
    }
    
    @EnvironmentObject var model : CreateProfileViewModel
    @State var image: UIImage?
    @State var shouldShowImagePicker = false
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
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
                    print($0)
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
        .fullScreenCover(isPresented: $shouldShowImagePicker, onDismiss: nil) {
            ImagePicker(image: $model.image)
                .ignoresSafeArea()
        }
        .onTapGesture {
            focusedField = nil
        }
        
    }
}

struct CreateProfile_Previews: PreviewProvider {
    static var previews: some View {
        CreateProfile()
    }
}
