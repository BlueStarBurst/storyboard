//
//  AuthView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/9/22.
//

import SwiftUI
import Firebase
import JWTKit



class LoginViewModel: ObservableObject {
    @Published var countryCode = ""
    @Published var phNumber = ""
    
    @Published var showAlert = false
    @Published var errorMsg = ""
    
    @Published var ID = ""
    @Published var verificationCode = ""
    
    @Published var isLoading = false
    @Published var isLoggedIn = false //should be false
    @Published var shouldSkipCreateAcc = "c" //should be c      b is createprofile
    @Published var verifyScreen = false
    
    @Published var initializing = true
    func verifyUser() {
        
        withAnimation{isLoading = true}
        
        //undo later
        Auth.auth().settings?.isAppVerificationDisabledForTesting = true // false
        
        PhoneAuthProvider.provider().verifyPhoneNumber("+\(countryCode + phNumber)",uiDelegate: nil) {
            ID, err in
            if let error = err{
                self.errorMsg = error.localizedDescription
                self.showAlert.toggle()
                return
            }
            
            self.ID = ID!
            self.verifyScreen = true
            
        }
    }
    
    func alertWithTF() {
        let alert = UIAlertController(title: "Verification", message: "Enter OTP Code", preferredStyle: .alert)
        
        alert.addTextField { txt in
            txt.placeholder = "123456"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: nil))
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
            
            if let code = alert.textFields?[0].text{
                self.LoginUser()
            }
            else {
                self.reportError()
            }
        }))
        
        UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    func LoginUser() {
        self.initializing = true
        let credential = PhoneAuthProvider.provider().credential(withVerificationID: self.ID, verificationCode: self.verificationCode)
        
        Auth.auth().signIn(with: credential, completion: { result, err in
            if let error = err {
                self.errorMsg = error.localizedDescription
                self.showAlert.toggle()
                self.initializing = false
                return
            }
            
            print("success")
            
            DataHandler.shared.load()
            
            self.token()
            
            self.isLoggedIn = true
            self.verifyScreen = false
            
        })
    }
    
    func reportError() {
        self.errorMsg = "Please try again later !!!"
    }
    
    func token() {
        
        guard let uid = Auth.auth().currentUser?.uid else {
            return
        }
        
        DataHandler.shared.getUser(id: uid, completionHandler: { data in
            if (data?["phone"] as! String == self.phNumber) {
                self.shouldSkipCreateAcc = "a"
            } else {
                self.shouldSkipCreateAcc = "b"
            }
            self.initializing = false
        })
        
//        HTTPHandler().POST(url: "/checkAccount", data: [self.phNumber], completion: self.setShouldSkip)
        
    }
    
    func setShouldSkip(decoded: Data) {
        guard let data = try? JSONDecoder().decode([String: Bool].self, from: decoded) else {
            print("Could not decode data")
            self.initializing = false
            return
        }
        if data["exists"]! {
            self.shouldSkipCreateAcc = "a"
        } else {
            self.shouldSkipCreateAcc = "b"
        }
        self.initializing = false
    }
    
    func checkAuth() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.alreadyAuth(decoded: false)
            return
            
        }
        DataHandler.shared.getUser(id: uid, completionHandler: { data in
            self.alreadyAuth(decoded: true)
        })
        
    }
    
    func alreadyAuth(decoded: Bool) {
        if (decoded) {
            self.shouldSkipCreateAcc = "a"
            self.isLoggedIn = true
        }
        self.initializing = false
    }
}

struct PayLoad: JWTPayload,Equatable {
    
    enum CodingKeys: String,CodingKey {
        case user_id
    }
    
    var user_id: String
    func verify(using signer: JWTSigner) throws {
        
    }
}




struct AuthView: View {
    @EnvironmentObject var model : LoginViewModel
    var body: some View {
        ZStack {
            VStack {
                Spacer()
                Text("Enter your phone number to get started!")
                HStack(spacing: 15) {
                    TextField("+1", text:$model.countryCode)
                        .keyboardType(.numberPad)
                        .padding(.vertical,12)
                        .padding(.horizontal)
                        .frame(width: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(model.countryCode == "" ? Color.gray :
                                            Color.pink,lineWidth: 1.5
                                       )
                        )
                    
                    TextField("(650)-555-1234", text:$model.phNumber)
                        .keyboardType(.numberPad)
                        .padding(.vertical,12)
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(model.phNumber == "" ? Color.gray :
                                            Color.pink,lineWidth: 1.5
                                       )
                        )
                    
                }
                .padding()
                
                Button(action: model.verifyUser, label: {
                    Text("login")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity)
                        .background(Color.pink)
                        .cornerRadius(8)
                })
                .disabled(model.countryCode == "" || model.phNumber == "")
                .opacity(model.countryCode == "" || model.phNumber == "" ? 0.6 : 1)
                .padding(.top,10)
                .padding(.bottom,15)
                .padding(.horizontal)
                Text("Standard data rates may apply blah blah blah")
                    .fontWeight(.light)
                    .foregroundColor(.gray)
                Spacer()
                
            }
        }
        if model.verifyScreen {
            HStack {
                Spacer()
                VStack {
                    Spacer()
                    Text("You 'should' be recieving a six-digit verification code via text")
                        .padding(.bottom, 12)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.gray)
                    
                    Text("Enter the code below to get log in!")
                        .padding(.bottom, 12)
                    TextField("six-digit code", text:$model.verificationCode)
                        .keyboardType(.numberPad)
                        .padding(.vertical,12)
                    
                        .padding(.horizontal)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(model.verificationCode.count != 6 ? Color.gray :
                                            Color.pink,lineWidth: 1.5
                                       )
                        )
                    Button(action: model.LoginUser, label: {
                        Text("verify")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.vertical)
                            .frame(maxWidth: .infinity)
                            .background(Color.pink)
                            .cornerRadius(8)
                    })
                    .disabled(model.verificationCode.count != 6)
                    .opacity(model.verificationCode.count != 6 ? 0.6 : 1)
                    .padding(.top,10)
                    .padding(.bottom, 40)
                    Spacer()
                    
                }.padding(.horizontal, 40)
                Spacer()
            }
            .background(Color.black)
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView()
    }
}
