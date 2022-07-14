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
    
    var body: some View {
        Map(coordinateRegion: $manager.region,
            interactionModes: MapInteractionModes.all,
            showsUserLocation: true,
            userTrackingMode: $tracking)
        .onTapGesture {
            print("GEST")
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
