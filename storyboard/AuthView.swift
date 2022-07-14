//
//  AuthView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/9/22.
//

import SwiftUI
import Firebase
import JWTKit

class MyFilesManager {
    enum Error: Swift.Error {
        case fileAlreadyExists
        case invalidDirectory
        case writingFailed
        case fileNotFound
        case readingFailed
    }
    
    let fileManager: FileManager
    init (fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    func save(fileNamed: String, data: Data) throws {
        guard let url = makeURL(forFileNamed: fileNamed) else {
            throw Error.invalidDirectory
        }
        if fileManager.fileExists(atPath: url.absoluteString) {
            print("exists")
            throw Error.fileAlreadyExists
        }
        do {
            try data.write(to: url)
        } catch {
            debugPrint(error)
            throw Error.writingFailed
        }
    }
    private func makeURL(forFileNamed fileName: String) -> URL? {
        guard let url = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return url.appendingPathComponent(fileName)
    }
    
    func read(fileNamed: String) throws -> Data {
        guard let url = makeURL(forFileNamed: fileNamed) else {
            print("inv dir")
            throw Error.invalidDirectory
        }
        guard fileManager.fileExists(atPath: url.absoluteString) else {
            print("file not found")
            throw Error.fileNotFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            debugPrint(error)
            throw Error.readingFailed
        }
    }
}

class LoginViewModel: ObservableObject {
    @Published var countryCode = ""
    @Published var phNumber = ""
    
    @Published var showAlert = false
    @Published var errorMsg = ""
    
    @Published var ID = ""
    @Published var verificationCode = ""
    
    @Published var isLoading = false
    @Published var isLoggedIn = false //false
    @Published var shouldSkipCreateAcc = "c" //c b is createprofile
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
            
            self.token()
            
            self.isLoggedIn = true
            self.verifyScreen = false
            
        })
    }
    
    func reportError() {
        self.errorMsg = "Please try again later !!!"
    }
    
    func token() {
        
        HTTPHandler().POST(url: "/checkAccount", data: [self.phNumber], completion: self.setShouldSkip)
        
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
        
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            self.initializing = false
            return
        }
        user?.getIDToken(completion: {(res,err) in
            if err != nil {
                print("error :(")
            } else {
                Task {
                    print("tokens!")
                    
                    let url = URL(string: "https://storyboard-server.herokuapp.com/checkID")!
                    var request = URLRequest(url: url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(res, forHTTPHeaderField: "AuthToken")
                    request.httpMethod = "POST"
                    
                    guard let encoded = try? JSONEncoder().encode([uid]) else {
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
                            self.alreadyAuth(decoded: decoded["exists"] ?? false)
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
