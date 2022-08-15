//
//  storyboardApp.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/2/22.
//

import SwiftUI
import FirebaseCore
import Firebase
import FirebaseFirestore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
    }
}

class HTTPHandler {
    func POST(url: String, data: Any, completion: @escaping (Data) -> ()) {
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
                    
                    let _url = URL(string: "https://storyboard-server.herokuapp.com" + url)!
                    var request = URLRequest(url: _url)
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue(res, forHTTPHeaderField: "AuthToken")
                    request.httpMethod = "POST"
                    
                    guard let encoded = try? JSONSerialization.data(withJSONObject: data) else {
                        print("Could not encode the data for request " + url)
                        return
                    }
                    
                    do {
                        let (data,_) = try await URLSession.shared.upload(for: request, from: encoded)
                        
                        DispatchQueue.main.async {
                            completion(data)
                        }
                    }
                    catch {
                        print("Error in the POST request")
                    }
                }
            }
        })
    }
}

@main
struct storyboardApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var phase
    @StateObject var model = LoginViewModel()
    @StateObject var createProfileModel = CreateProfileViewModel()
    @State var page = 0
    
    @State var fullApp = false
    @State var isMessageView = true
    
    var body: some Scene {
        WindowGroup {
            if !createProfileModel.finished && !(model.shouldSkipCreateAcc == "a") {
                ZStack {
                    TabView(selection:$page) {
                        NavigationView {
                            ZStack {
                                AuthView()
                                    .environmentObject(model)
                                    .onAppear {
                                        print("a")
                                        model.checkAuth()
                                    }
                                if (model.isLoggedIn && model.shouldSkipCreateAcc == "b") {
                                    Text("")
                                        .onAppear {
                                            withAnimation {
                                                createProfileModel.phoneNumber = model.phNumber
                                                page = 1
                                            }
                                            
                                        }
                                }
                            }
                        }
                        .background(
                            ZStack {
                                Text("")
                                    .alert(isPresented: $model.showAlert,
                                           content: {
                                        Alert(title: Text("Message"), message: Text(model.errorMsg), dismissButton: .destructive(Text("Ok"), action:{
                                            withAnimation{
                                                model.isLoading = false
                                            }
                                        }))
                                    })
                            })
                        .tag(0)
                        if (model.isLoggedIn && model.shouldSkipCreateAcc == "b") {
                            VStack {
                                CreateProfile()
                                    .environmentObject(createProfileModel)
                            }
                            .tag(1)
                        }
                        
                    }
                    
                    if model.initializing {
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                Image("logo_ontop")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(35)
                                Spacer()
                            }
                            Spacer()
                        }
                        .background(Color.black)
                    }
                    
                    
                }
                
            } else {
                ZStack {
                    ContentView()
                        .accentColor(.white)
                        .preferredColorScheme(.dark)
                        .onAppear {
                            DataHandler.shared.updateMessage = {
                                isMessageView = DataHandler.shared.isMessageView
                            }
                        }
                    if (isMessageView == true) {
                        MessageView()
                    }
                }
            }
        }
        .onChange(of: phase) { _ in
            setupColorScheme()
        }
    }
    
    private func setupColorScheme() {
        // We do this via the window so we can access UIKit components too.
        let window = UIApplication.shared.windows.first
        window?.overrideUserInterfaceStyle = .dark
        window?.tintColor = UIColor(Color.red)
    }}
