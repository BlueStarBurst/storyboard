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
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    let gcmMessageIDKey = "gcm.message_id"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()

        Messaging.messaging().delegate = self

        if #available(iOS 10.0, *) {
          // For iOS 10 display notification (sent via APNS)
          UNUserNotificationCenter.current().delegate = self

          let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
          UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })
        } else {
          let settings: UIUserNotificationSettings =
          UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
          application.registerUserNotificationSettings(settings)
        }

        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {

      if let messageID = userInfo[gcmMessageIDKey] {
        print("Message ID: \(messageID)")
      }

      print(userInfo)

      completionHandler(UIBackgroundFetchResult.newData)
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

      let deviceToken:[String: String] = ["token": fcmToken ?? ""]
        print("Device token: ", deviceToken) // This token can be used for testing notifications on FCM
    }
    
    func messaging(_ messaging: Messaging, didRecieveRegistrationToken fcmToken: String?) {
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
        DataHandler.shared.updateToken()
    }
}


@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {

  // Receive displayed notifications for iOS 10 devices.
  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo

    if let messageID = userInfo[gcmMessageIDKey] {
        print("Message ID: \(messageID)")
    }

    print(userInfo)

    // Change this to your preferred presentation option
    completionHandler([[.banner, .badge, .sound]])
  }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {

    }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo

    if let messageID = userInfo[gcmMessageIDKey] {
      print("Message ID from userNotificationCenter didReceive: \(messageID)")
    }

    print(userInfo)

    completionHandler()
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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var phase
    @StateObject var model = LoginViewModel()
    @StateObject var createProfileModel = CreateProfileViewModel()
    @State var page = 0
    
    @State var fullApp = false
    @State var isMessageView = false
    
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
