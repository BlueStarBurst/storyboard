//
//  MapView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/14/22.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapView: View {
    @StateObject var manager = LocationManager()
    @State var tracking: MapUserTrackingMode = .none
    
    @State private var events = ["a", "b", "c"]
    
    @State var eventScroll = 350.0
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $manager.region,
                interactionModes: MapInteractionModes.all,
                showsUserLocation: true,
                userTrackingMode: $tracking)
            .onTapGesture {
                print("GEST")
            }

            VStack {
                Spacer()
                VStack {
                    HStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 30, height: 8)
                            .cornerRadius(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    
                    
                    ScrollView {
                        ForEach (events) { event in
                            Text(event)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 15)
                        }
                    }.frame(height: 500)
                }
                .padding(5)
                .background(Color.black)
                .frame(maxWidth: .infinity)
                .cornerRadius(12)
                .offset(y: CGFloat(eventScroll))
                .transition(.slide)
                .gesture(DragGesture()
                    .onChanged {
                    if ($0.location.y < 0) {
                        return
                    }
                    eventScroll = $0.location.y
                }
                .onEnded {
                    print($0.translation.height)
                    withAnimation(.easeInOut) {
                        if (eventScroll > 250) {
                            eventScroll = 350
                        } else {
                            eventScroll = 20
                        }
                    }
                })
                
            }
            
            
            
            
            .frame(maxWidth: .infinity)
            
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
