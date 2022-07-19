//
//  MapView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/14/22.
//

import SwiftUI
import MapKit
import CoreLocation

class KeyboardResponder: ObservableObject {
    
    //2. Keeping track off the keyboard's current height
    @Published var currentHeight: CGFloat = 0
    
    //3. We use the NotificationCenter to listen to system notifications
    var _center: NotificationCenter
    
    init(center: NotificationCenter = .default) {
        _center = center
        //4. Tell the notification center to listen to the system keyboardWillShow and keyboardWillHide notification
        _center.addObserver(self, selector: #selector(keyBoardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        _center.addObserver(self, selector: #selector(keyBoardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    //5.1. Update the currentHeight variable when the keyboards gets toggled
    @objc func keyBoardWillShow(notification: Notification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            withAnimation {
                currentHeight = keyboardSize.height
            }
        }
    }
    
    //5.2 Update the currentHeight variable when the keyboards collapses
    @objc func keyBoardWillHide(notification: Notification) {
        withAnimation {
            currentHeight = 0
        }
    }
}

class MapPin: NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let action: (() -> Void)?
    
    init(coordinate: CLLocationCoordinate2D,
         title: String? = nil,
         subtitle: String? = nil,
         action: (() -> Void)? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
}

struct Map : UIViewRepresentable {
    
    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        
        @Binding var selectedPin: MapPin?
        
        var parent: Map
        var gRecognizer = UILongPressGestureRecognizer()
        
        init(_ parent: Map, selectedPin: Binding<MapPin?>) {
            self.parent = parent
            
            _selectedPin = selectedPin
            super.init()
            self.gRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(tapHandler))
            self.gRecognizer.delegate = self
            self.parent.mapView.addGestureRecognizer(gRecognizer)
        }
        
        @objc func tapHandler(_ gesture: UILongPressGestureRecognizer) {
            if parent.interact { return }
            
            let location = gRecognizer.location(in: self.parent.mapView)
            
            let coordinate = self.parent.mapView.convert(location, toCoordinateFrom: self.parent.mapView)
            
            //            print(coordinate)
            self.parent.tapEmptySpot(coordinate: coordinate)
        }
        
        
        
        func mapView(_ mapView: MKMapView,
                     didSelect view: MKAnnotationView) {
            guard let pin = view.annotation as? MapPin else {
                return
            }
            pin.action?()
            selectedPin = pin
        }
        
        func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
            guard (view.annotation as? MapPin) != nil else {
                return
            }
            selectedPin = nil
        }
    }
    
    func coordsToLoc(coords: CLLocationCoordinate2D) -> CLLocation {
        return CLLocation(latitude: coords.latitude, longitude: coords.longitude)
    }
    
    @Binding var pins: [MapPin]
    @Binding var selectedPin: MapPin?
    
    @Binding var interact: Bool
    @Binding var name: String
    @Binding var add: String
    
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Binding var isCreatingPin: Bool
    @Binding var newPin: MapPin
    
    let mapView = MKMapView(frame: .zero)
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self, selectedPin: $selectedPin)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        
        mapView.showsUserLocation = true
        guard let coordinate = mapView.userLocation.location?.coordinate else { return mapView }
        let region = mapView.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: 200, longitudinalMeters: 200))
        mapView.setRegion(region, animated: true)
        
        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        
        guard var coordinate = manager.location?.coordinate else { return }
        if (isCreatingPin) {
            coordinate = newPin.coordinate
        }
        
        let region = uiView.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: 2400, longitudinalMeters: 2400))
        uiView.setRegion(region, animated: true)
        uiView.removeAnnotations(uiView.annotations)
        uiView.addAnnotations(pins)
        if (isCreatingPin) {
            let ann: [MapPin] = [newPin]
            uiView.addAnnotations(ann)
        }
        if let selectedPin = selectedPin {
            uiView.selectAnnotation(selectedPin, animated: false)
        }
        
        
    }
    
    func tapEmptySpot(coordinate: CLLocationCoordinate2D) {
        let coords = coordsToLoc(coords: coordinate)
        geocoder.reverseGeocodeLocation(coords, completionHandler: { (places, error) in
            if error == nil {
                let firstLocation = places?[0]
                print(firstLocation?.name)
                name = firstLocation?.name ?? "Some Random Place"
                print((firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? ""))
                add = (firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? "")
                
                if add == name {
                    name = "Some Random Place"
                }
                
                isCreatingPin = true
                newPin = MapPin(coordinate: coordinate,
                                title: "New Event",
                                subtitle: "",
                                action: { print("Hey mate!") } )
                
                
                withAnimation {interact = true}
                
            } else {
                print("OH DEAR")
            }
        })
    }
    
}

class CreateEventModel: ObservableObject {
    @Published var name: String = ""
}




struct MapView: View {
    enum Field: Hashable {
        case myField
    }
    
    @FocusState private var focusedField: Field?
    
    @StateObject var model = CreateEventModel()
    
    @StateObject var manager = LocationManager()
    @State var tracking: MapUserTrackingMode = .none
    
    @State private var events = ["a", "b", "c"]
    
    @State var eventScroll = 350.0
    
    @State var pins: [MapPin] = [
        MapPin(coordinate: CLLocationCoordinate2D(latitude: 51.509865,
                                                  longitude: -0.118092),
               title: "London",
               subtitle: "Big Smoke",
               action: { print("Hey mate!") } )
    ]
    @State var selectedPin: MapPin?
    
    @State var isCreatingPin = false
    @State var newPin = MapPin(coordinate: CLLocationCoordinate2D(latitude: 51.509865,
                                                                  longitude: -0.118092),
                               title: "London",
                               subtitle: "Big Smoke",
                               action: { print("Hey mate!") } )
    
    @State var interact: Bool = false
    @State var name: String = ""
    @State var add: String = ""
    
    @State private var searchText = ""
    let names: [[String:String]] = [["fullname": "Bryant Hargreaves", "username": "inkobako"]]
    
    var searchResults: [[String:String]] {
        if searchText.isEmpty {
            return names
        } else {
            
            return Array(
                Set(
                    names.filter { $0["fullname"]!.contains(searchText.lowercased()) }
                    + names.filter { $0["username"]!.contains(searchText.lowercased()) }
                )
            )
        }
    }
    
    @State private var date = Date()
    
    @State var page = 1
    
    @ObservedObject var keyboardResponder = KeyboardResponder()
    
    @State var center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    var body: some View {
        ZStack {
            Map(pins: $pins, selectedPin: $selectedPin, interact: $interact, name: $name, add: $add, isCreatingPin: $isCreatingPin, newPin: $newPin)
                .onTapGesture {
                    interact = false
                }
                .opacity(interact ? 0.5 : 1)
            
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
            .transition(.move(edge: .bottom))
            .frame(maxWidth: .infinity)
            
            if interact {
                
                VStack {
                    Spacer()
                    VStack {
                        ZStack {
                            if page == 1 {
                                VStack {
                                    Text("Create Event")
                                        .fontWeight(.bold)
                                        .padding(.top, 20)
                                        .padding(.bottom,5)
                                        .font(.system(size: 25))
                                    
                                    Text("Event Name")
                                        .frame(maxWidth: .infinity, alignment:.leading)
                                        .padding(.horizontal, 20)
                                    TextField("Event Name", text: $name)
                                        .focused($focusedField, equals: .myField)
                                        .onChange(of: name) {
                                            print($0)
                                        }
                                        .onAppear {
                                            name = "Meetup at " + name
                                        }
                                        .padding(.vertical,15)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(name == "" ? Color.gray :
                                                            Color.pink,lineWidth: 1.5
                                                       )
                                        )
                                        .padding(.horizontal,20)
                                    Text("Address")
                                        .frame(maxWidth: .infinity, alignment:.leading)
                                        .padding(.top, 10)
                                        .padding(.horizontal, 20)
                                    TextField("Address", text: $add)
                                        .focused($focusedField, equals: .myField)
                                        .onChange(of: add) {
                                            print($0)
                                        }
                                        .padding(.vertical,15)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(add == "" ? Color.gray :
                                                            Color.pink,lineWidth: 1.5
                                                       )
                                        )
                                        .padding(.horizontal,20)
                                    
                                    //                                    Spacer()
                                    
                                    Button(action: {withAnimation{page = 2}}, label: {
                                        Text("next")
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.vertical)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.pink)
                                            .cornerRadius(8)
                                    })
                                    .disabled(name == "" || add == "")
                                    .opacity(name == "" || add == "" ? 0.6 : 1)
                                    .padding(.top,10)
                                    .padding(.bottom,35)
                                    .padding(.horizontal)
                                    
                                }
                                .animation(.easeInOut)
                                .transition(.move(edge: .bottom))
                                
                                
                            }
                        }
                        
                        if page == 2 {
                            VStack {
                                Text("Add Friends")
                                    .fontWeight(.bold)
                                    .padding(.top, 20)
                                    .padding(.bottom,5)
                                    .font(.system(size: 25))
                                
                                
                                TextField("Friend Name", text: $searchText)
                                    .focused($focusedField, equals: .myField)
                                    .onChange(of: searchText) {
                                        print($0)
                                    }
                                
                                    .padding(.vertical,15)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(name == "" ? Color.gray :
                                                        Color.pink,lineWidth: 1.5
                                                   )
                                    )
                                    .padding(.horizontal,20)
                                

                                    List {
                                        ForEach(searchResults, id: \.self) { friend in
                                            FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", remove: true, update: {})
                                        }
                                    }
                                    .frame(height: 200)
                                    .listStyle(PlainListStyle())
                                    .searchable(text: $searchText)

                                
                                
                                
                                Button(action: {page = 2}, label: {
                                    Text("next")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.pink)
                                        .cornerRadius(8)
                                })
                                .disabled(name == "" || add == "")
                                .opacity(name == "" || add == "" ? 0.6 : 1)
                                .padding(.top,10)
                                .padding(.bottom,35)
                                .padding(.horizontal)
                                
                            }
                            .animation(.easeInOut)
                            .transition(.move(edge: .bottom))
                            
                            
                            
                        }
                        
                        //                    HStack {
                        //                        Spacer()
                        //                        DatePicker(
                        //                            "Date",
                        //                            selection: $date,
                        //                            displayedComponents: [.date])
                        //                        Spacer()
                        //                    }
                        
                        
                        
                        //                    TextField("Friends", text: $model.name)
                        //                        .focused($focusedField, equals: .myField)
                        //                        .onChange(of: model.name) {
                        //                            print($0)
                        //                        }
                        //                        .padding(.vertical,15)
                        //                        .padding(.horizontal)
                        //                        .background(
                        //                            RoundedRectangle(cornerRadius: 8)
                        //                                .stroke(model.name == "" ? Color.gray :
                        //                                            Color.pink,lineWidth: 1.5
                        //                                       )
                        //                        )
                        //                        .padding(.horizontal,20)
                        //
                        //                    NavigationView {
                        //                        List {
                        //                            ForEach(searchResults, id: \.self) { name in
                        //                                Text(name)
                        //                            }
                        //                        }
                        //                        .listStyle(PlainListStyle())
                        //                        .searchable(text: $searchText)
                        //                    }
                        //                    .frame(alignment: .top)
                        //                    .padding(.vertical, 20)
                        //                    .background(Color.pink)
                    }
                    //                    .frame(height: 400)
                    .background(Color.black)
                    .cornerRadius(8)
                    .offset(y: -keyboardResponder.currentHeight*0.9)
                    .transition(.move(edge: .bottom))
                    
                }
            }
            
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
