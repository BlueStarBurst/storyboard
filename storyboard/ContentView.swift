//
//  ContentView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/2/22.
//

import SwiftUI
import FirebaseCore

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

struct ContentView: View {
    
    
    @State private var page = 1
    @State private var mapView = false
    @State private var headerSize = CGSize()
    
    @State var isTakingPicture = false
    
    //.offset(y: mapView ? -100 : 0)
    //.animation(.easeInOut, value: mapView)
    
    @StateObject var model = FriendsPageViewModel()
    
    var body: some View {
        ZStack {
            TabView(selection:$page) {
                ZStack{
                    FeedView(isTakingPicture: $isTakingPicture)
                }.tag(0)
                ZStack{
                    
                    ZStack {
                        MapView()
                            .ignoresSafeArea()
                        
                        HStack {
                            Rectangle()
                                .ignoresSafeArea()
                                .frame(maxWidth: 26, maxHeight: .infinity)
                                .opacity(0.02)
                                .foregroundColor(Color.black)
                            Spacer()
                            Rectangle()
                                .ignoresSafeArea()
                                .frame(maxWidth: 26, maxHeight: .infinity)
                                .opacity(0.02)
                                .foregroundColor(Color.black)
                        }
                        
                        //                    if (!mapView) {
                        //                    Rectangle()
                        //                        .foregroundColor(Color.black.opacity(0.5))
                        //                        .onTapGesture {
                        //                            mapView = true
                        //                        }
                        //                        .ignoresSafeArea()
                        //                    }
                        
                        
                        
                    }
                    VStack{
                        HStack {
                            Spacer()
                            Text("live")
                            Spacer()
                        }
                        
                        .padding([.bottom , .trailing , .leading ], 15)
                        .background(Color.black)
                        
                        Spacer()
                    }
                }.tag(1)
                FriendsPage()
                    .environmentObject(model)
                    .tag(2)
            }.tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            if isTakingPicture == true {
                CustomCameraPhotoView(isTakingPicture: $isTakingPicture)
                    .transition(.move(edge: .bottom))
            }
            if model.isEditingProfile == true {
                ChangeProfile()
                    .transition(.move(edge: .bottom))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

