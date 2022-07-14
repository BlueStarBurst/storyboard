//
//  ContentView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/2/22.
//

import SwiftUI
import MapKit
import FirebaseCore

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

struct ContentView: View {
    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12), span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2))
    
    @State private var page = 2
    @State private var mapView = false
    @State private var headerSize = CGSize()
    
    //.offset(y: mapView ? -100 : 0)
    //.animation(.easeInOut, value: mapView)
    
    @State private var blogList = ["a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r"]
    
    var body: some View {
        TabView(selection:$page) {
            ZStack{
                
                List(blogList) { post in
                    Text(post)
                        .padding(15)
                        .listRowBackground(Color.black)
                        .listRowSeparator(.hidden)
                        
                }
                .padding([.top], 25)
                .listStyle(PlainListStyle())
                
                VStack {
                    HStack {
                        Spacer()
                        Text("feed")
                        Spacer()
                    }
                    .padding([.bottom , .trailing , .leading ], 15)
                    .background(Color.black)
                    Spacer()
                }
                
            }.tag(0)
            ZStack{
                
                ZStack {
                    
                    Map(coordinateRegion: $mapRegion, showsUserLocation: true)
                        .onTapGesture {
                            mapView = true
                        }
                        .ignoresSafeArea()
                    if (!mapView) {
                    Rectangle()
                        .foregroundColor(Color.black.opacity(0.5))
                        .onTapGesture {
                            mapView = true
                        }
                        .ignoresSafeArea()
                    }
                    
                }
                VStack{
                    HStack {
                        Text("friends")
                        Spacer()
                        Text("live")
                        Spacer()
                        Text("add pin")
                    }
                    
                    .padding([.bottom , .trailing , .leading ], 15)
                    .background(Color.black)

                    Spacer()
                }
            }.tag(1)
            FriendsPage()
                .tag(2)
        }.tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

final class ContentViewModel: ObservableObject {
    var locationManager: CLLocationManager?
    
    func checkIfLocationServicesIsEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
        } else {
            print("nooooo")
        }
    }
}
