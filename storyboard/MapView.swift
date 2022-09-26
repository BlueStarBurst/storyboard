//
//  MapView.swift
//  storyboard
//
//  Created by Bryant Hargreaves on 7/14/22.
//

import SwiftUI
import MapKit
import CoreLocation
import Contacts
import Firebase
import FirebaseFirestore

extension Date {
    
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
}

extension TimeInterval {
    var milliseconds: Int {
        return Int((truncatingRemainder(dividingBy: 1)) * 1000)
    }
    
    var seconds: Int {
        return Int(self) % 60
    }
    
    var minutes: Int {
        return (Int(self) / 60 ) % 60
    }
    
    var hours: Int {
        return Int(self) / 3600
    }
    
    var stringTime: String {
        if hours != 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes != 0 {
            return "\(minutes)m \(seconds)s"
        } else if milliseconds != 0 {
            return "\(seconds)s \(milliseconds)ms"
        } else {
            return "\(seconds)s"
        }
    }
}

class MapPin: NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let image: UIImage?
    let action: (() -> Void)?
    let id: String?
    
    init(coordinate: CLLocationCoordinate2D,
         title: String? = nil,
         subtitle: String? = nil,
         action: (() -> Void)? = nil,
         image: UIImage? = nil,
         id: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.image = image
        self.id = id
    }
    
}

class CreateEventModel: ObservableObject {
    
    @Published var mapView = MKMapView(frame: .zero)
    
    @Published var name: String = ""
    
    @Published var address: String = ""
    
    @Published var date = Date()
    
    @Published var newPin = MapPin(coordinate: CLLocationCoordinate2D(latitude: 0,
                                                                      longitude: 0), title: "tempPin")
    
    @Published var friends: [[String: String]] = []
    @Published var searchText: String = ""
    
    @Published var events: [[String:Any]] = []
    @Published var eventsString: [[String:String]] = []
    @Published var incomingEvents: [[String:Any]] = []
    @Published var incomingEventsString: [[String:String]] = []
    
    @Published var invitedFriends: [String] = []
    
    @Published var pins: [String:MapPin] = [:]
    
    @Published var selectedPin: MapPin? = nil
    @Published var selectedEventID: String? = ""
    
    var searchResults: [[String:String]] {
        if self.searchText.isEmpty {
            return self.friends
        } else {
            
            return Array(
                Set(
                    self.friends.filter { $0["fullname"]!.lowercased().contains(self.searchText.lowercased()) }
                    + self.friends.filter { $0["username"]!.lowercased().contains(self.searchText.lowercased()) }
                )
            )
        }
    }
    
    func stringFriends() -> String {
        var str = ""
        for friend in self.invitedFriends {
            str += friend + " "
        }
        return str
    }
    
    func sendData() {
        let user = Auth.auth().currentUser
        guard let uid = user?.uid else {
            return
        }
        
//        self.date = Date()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y, MM, dd, HH::mm::ss, Z"
        
        
        dateFormatter.timeZone = TimeZone.current
        
        let formatted = dateFormatter.string(from: date)
        //        let formatted = date.formatted()
        
        print(formatted)
        
        DataHandler.shared.createEvent(data: ["name": self.name, "address": self.address, "attending": [DataHandler.shared.uid], "invited": self.invitedFriends, "date": Timestamp(date: date), "coords": encodeLocation(loc: newPin.coordinate)], completionHandler: {
            print("WORKS")
        })
    }
    
    func encodeLocation(loc: CLLocationCoordinate2D) -> String {
        return String(loc.longitude) + " " + String(loc.latitude)
    }
    
    func decodeLocation(str: String) -> CLLocationCoordinate2D {
        let comp = str.components(separatedBy: " ")
        return CLLocationCoordinate2D(latitude: Double(comp[1]) ?? 0.0, longitude: Double(comp[0]) ?? 0.0)
    }
    
    func update() {
        self.events = []
        self.eventsString = []
        DataHandler.shared.events.keys.forEach { key in
            var event = DataHandler.shared.events[key]! as [String:Any]
            event["id"] = key
            
            event["date"] = (event["date"] as? Timestamp)?.dateValue()
            var timeString = ""
            
            var time = Int(event["date"] as! Date - Date())
            
            if (time > 0) {
                timeString = "In "
            }
            var sec = abs(time % 60)
            var minutes = abs((time / 60) % 60)
            var hours = abs((time / 60 / 60) % 60)
            var days = abs((time / 60 / 60 / 24) % 24)
            
            print(hours)
            
            if (days > 1) {
                timeString += String(days) + " days"
            } else if (days > 0) {
                timeString += String(days) + " day"
            } else if (hours > 1) {
                timeString += String(hours) + "hrs"
            } else if (hours > 0) {
                timeString += String(hours) + "hr"
            } else if (minutes > 1) {
                timeString += String(minutes) + "mins"
            } else if (minutes > 0) {
                timeString += String(minutes) + "min"
            } else if (sec > 0) {
                timeString += String(sec) + "s"
            }
            
            if (time < 0) {
                timeString += " ago"
            }
            
            self.events.append(event)
            self.eventsString.append([
                "name": event["name"] as! String,
                "id": key,
                "time": timeString,
                "coords": event["coords"] as! String,
            ])
        }
        
        self.incomingEvents = []
        self.incomingEventsString = []
        DataHandler.shared.incomingEvents.keys.forEach { key in
            print(key)
            var event = DataHandler.shared.incomingEvents[key]! as [String:Any]
            event["id"] = key
            
            event["date"] = (event["date"] as? Timestamp)?.dateValue()
            
            var timeString = ""
            
            var time = Int(event["date"] as! Date - Date())
            
            if (time > 0) {
                timeString = "In "
            }
            var sec = abs(time % 60)
            var minutes = abs((time / 60) % 60)
            var hours = abs((time / 60 / 60) % 60)
            var days = abs((time / 60 / 60 / 24) % 24)
            
            print(hours)
            
            if (days > 1) {
                timeString += String(days) + " days"
            } else if (days > 0) {
                timeString += String(days) + " day"
            } else if (hours > 1) {
                timeString += String(hours) + "hrs"
            } else if (hours > 0) {
                timeString += String(hours) + "hr"
            } else if (minutes > 1) {
                timeString += String(minutes) + "mins"
            } else if (minutes > 0) {
                timeString += String(minutes) + "min"
            } else if (sec > 0) {
                timeString += String(sec) + "s"
            }
            
            if (time < 0) {
                timeString += " ago"
            }
            
            self.incomingEvents.append(event)
            self.incomingEventsString.append([
                "name": event["name"] as! String,
                "id": key,
                "time": timeString,
                "coords": event["coords"] as! String,
            ])
        }
        
        self.translatePins()
        self.friends = DataHandler.shared.friends
        //        self.incomingEvents = DataHandler.shared.incomingEvents
    }
    
    func updateSelected(id: String) {
        print("ID: \(id)")
        self.selectedEventID = id
    }
    
    
    func translatePins() {
        for event in events {
            if (event["name"] == nil) {
                break
            }
            self.pins[event["id"] as? String ?? ""] =
                MapPin(coordinate: decodeLocation(str: event["coords"]! as! String), title: event["name"] as? String , action: {self.updateSelected(id: event["id"] as? String ?? "")}, id: event["id"] as? String)
            
            
        }
        for event in incomingEvents {
            if (event["name"] == nil) {
                break
            }
            self.pins[event["id"] as? String ?? ""] =
                MapPin(coordinate: decodeLocation(str: event["coords"]! as! String), title: event["name"] as? String , action: {self.updateSelected(id: event["id"] as? String ?? "")}, id: event["id"] as? String)
            
            
        }
        
    }
    
    
}

struct EventTab: View {
    
    var event: [String:String]
    var incoming: Bool = false
    var id: String = ""
    
    var time: String = ""
    
    @Binding var mapView: MKMapView
    
    @Binding var modelCurrentEventID: String?
    @Binding var annotations: [String:MapPin]
    
    @Binding var eventScroll: Double
    
    var index: Int = 0
    
    
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(id == modelCurrentEventID ? Color.red : Color.white)
                .font(.system(size: 28))
                .padding(.trailing, 5)
                .onTapGesture {
                    
                    withAnimation {
                        eventScroll = 350.0
                    }
                    
                    print("INDEX \(index)")
                    
        //            let comp = event["coords"]?.components(separatedBy: " ") ?? ["0.0", "0.0"]
                    mapView.selectAnnotation(annotations[event["id"] ?? ""]!, animated: true)
        //            mapView.setCenter(CLLocationCoordinate2D(latitude: Double(comp[1]) ?? 0.0, longitude: Double(comp[0]) ?? 0.0), animated: true)
                }
            VStack {
                HStack {
                    Text(event["name"] ?? "")
                    Spacer()
                }
                .frame(alignment: .leading)
                if (time != "") {
                    HStack {
                        Text(time ?? "")
                            .foregroundColor(Color.white.opacity(0.7))
                            .font(.system(size: 13))
                        Spacer()
                    }
                }
            }.onTapGesture {
                DataHandler.shared.openEventChat(id: event["id"] ?? "")
//                if incoming == false {
//                    DataHandler.shared.openEventChat(id: event["id"] ?? "")
//                } else {
//                    DataHandler.shared.openIncomingEventChat(id: event["id"] ?? "")
//                }
            }
            .padding(.leading, 3)
            Spacer()
            Image(systemName: "bubble.left")
                .onTapGesture {
                    DataHandler.shared.openEventChat(id: event["id"] ?? "")
//                    if incoming == false {
//                        DataHandler.shared.openEventChat(id: event["id"] ?? "")
//                    } else {
//                        DataHandler.shared.openIncomingEventChat(id: event["id"] ?? "")
//                    }
                }
            
            Menu {
                if (incoming == true) {
                    Button(action: {
                        DataHandler.shared.joinEvent(id: event["id"] ?? "")
                    }) {
                        Label("Join Event", systemImage: "arrow.forward.circle")
                    }
                }
                Button(role: .destructive, action: {
                    DataHandler.shared.leaveEvent(id: event["id"] ?? "")
                    mapView.removeAnnotationAndOverlay(annotation: annotations[event["id"] ?? ""]!)
                    annotations.removeValue(forKey: event["id"] ?? "")
                }) {
                    Label("Leave Event", systemImage: "trash.fill")
                }
            } label: {
                VStack {
                    Spacer()
                    Image(systemName: "ellipsis")
                    
                        .padding(3)
                    //                    .imageScale(.large)
                        .rotationEffect(Angle(degrees: 90))
                    Spacer()
                }
            }
            
        }
        
        .frame(alignment: .leading)
        .padding(.horizontal, 15)
        .padding(.vertical, 5)
        
    }
}



struct Pin: Identifiable {
    let id = UUID()
    let name: String
    var coordinate: CLLocationCoordinate2D
}

func getDist(from: CGPoint, to: CGPoint) -> CGFloat {
    return sqrt(
        (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    )
}

struct MapView: View {
    enum Field: Hashable {
        case myField
    }
    
    @State private var animationAmount: CGFloat = 1
    @State private var animationAmount2: CGFloat = 1
    @State private var animationAmount3: CGFloat = 1
    @State private var animationAmount4: CGFloat = 1
    
    @State var tutorial = 0
    
    @FocusState private var focusedField: Field?
    
    @StateObject var model = CreateEventModel()
    
    @StateObject var manager = LocationManagerNew()
    
    @State var tracking: MapUserTrackingMode = .none
    
    @State private var events = ["a", "b", "c"]
    
    @State var eventScroll = 350.0
    
    
    @State var selectedPin: MapPin?
    @State var oldPin: MapPin?
    
    @State var isCreatingPin = false
    
    
    @State var interact: Bool = false
    @State var name: String = ""
    @State var add: String = ""
    
    @State private var searchText = ""
    
    @State var toggleLock: Bool = false
    
    
    @State var page = 1
    
    @ObservedObject var keyboardResponder = KeyboardResponder()
    
    @State var center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    @State var onStart = false
    
    @State var saveCoords = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    
    var body: some View {
        ZStack {
            
            //            Map(coordinateRegion: $manager.region, showsUserLocation: true, annotationItems: real_pins) { place in
            //                MapAnnotation(coordinate: place.coordinate) {
            //                    VStack {
            //                        VStack(spacing:0) {
            //                            Image(systemName: "mappin.circle.fill")
            //                                .font(.title)
            //                                .foregroundColor(.red)
            //                            Image(systemName: "arrowtriangle.down.fill")
            //                                .font(.caption)
            //                                .foregroundColor(.red)
            //                                .offset(x: 0, y: -5)
            //                        }
            //                        Text(place.name)
            //                            .fixedSize(horizontal: false, vertical: true)
            //                            .multilineTextAlignment(.center)
            //                            .frame(maxWidth: 150, alignment: .center)
            //                            .font(.system(size: 14))
            //                    }
            //                }
            //
            //            }
            //
            //            .onTapGesture {
            //                withAnimation {
            //                    isCreatingPin = false
            //                    interact = false
            //                    page = 1
            //                }
            //            }
            //            .opacity(interact ? 0.5 : 1)
            //            .onAppear {
            //                model.getEvents()
            //                model.getIncoming()
            //            }
            //            .edgesIgnoringSafeArea(.all)
            
            
            //            MapO(pins: $model.pins, selectedPin: $selectedPin, interact: $interact, name: $model.name, add: $model.address, isCreatingPin: $isCreatingPin, newPin: $model.newPin)
            //                .onTapGesture {
            //                    withAnimation {
            //                        isCreatingPin = false
            //                        interact = false
            //                        page = 1
            //                    }
            //                }
            //                .opacity(interact ? 0.5 : 1)
            //
            
            CustomMap(annotations: $model.pins, interact: $interact, name: $model.name, add: $model.address, isCreatingPin: $isCreatingPin, newPin: $model.newPin, oldPin: $oldPin, onStart: $onStart, saveCoords: $saveCoords, selectedPin: $model.selectedPin, mapView: $model.mapView)
                .onAppear {
                    onStart = true
                    model.update()
                    DataHandler.shared.eventPageUpdate = model.update
                }
                .onTapGesture {
                    withAnimation {
                        isCreatingPin = false
                        interact = false
                        page = 1
                    }
                }
                .opacity(interact ? 0.5 : 1)
            
            
            if model.events.count > 0 || model.incomingEvents.count > 0 {
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
                            ScrollViewReader { scrollViewProxy in
                                VStack {
                                    ForEach (model.eventsString, id: \.self) { event in
                                        EventTab(event: event, id: event["id"] ?? "", time: event["time"] ?? "", mapView: $model.mapView, modelCurrentEventID: $model.selectedEventID, annotations: $model.pins, eventScroll: $eventScroll)
                                            .frame(maxWidth: .infinity)
                                            .padding(.bottom, 15)
                                            .id(event["id"] ?? "")
                                    }
                                    if (model.incomingEventsString.count > 0) {
                                        Text("Incoming Events").padding(.bottom, 18).foregroundColor(Color.white.opacity(0.8))
                                        ForEach (model.incomingEventsString, id: \.self["id"]) { event in
                                            EventTab(event: event, incoming: true, id: event["id"] ?? "", time: event["time"] ?? "", mapView: $model.mapView, modelCurrentEventID: $model.selectedEventID, annotations: $model.pins, eventScroll: $eventScroll)
                                                .frame(maxWidth: .infinity)
                                                .padding(.bottom, 18)
                                                .id(event["id"] ?? "")
                                        }
                                    }
                                    VStack {
                                        Spacer()
                                    }
                                    .frame(height: 500)
                                }
                                .onChange(of: model.selectedEventID) { _ in
                                    print(model.selectedEventID)
                                    withAnimation(.easeOut(duration: 0.5)) {
                                        scrollViewProxy.scrollTo(model.selectedEventID,anchor: .top)
                                    }
                                }
                            }
                        }.frame(height: 500)
                            .gesture(DragGesture()
                                .onChanged {
                                    print($0)
                                    print("ALOHA")
                                }
                            )
                        
                        
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
                            if (!toggleLock) {
                                toggleLock = true
                            }
                            eventScroll = $0.location.y
                        }
                        .onEnded {
                            print($0.translation.height)
                            toggleLock = false
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
            }
            
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
                                    TextField("Event Name", text: $model.name)
                                        .focused($focusedField, equals: .myField)
                                        .onChange(of: name) {
                                            print($0)
                                        }
                                        .onAppear {
                                            model.name = "Meetup at " + model.name
                                        }
                                        .padding(.vertical,15)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(model.name == "" ? Color.gray :
                                                            Color.pink,lineWidth: 1.5
                                                       )
                                        )
                                        .padding(.horizontal,20)
                                    Text("Address")
                                        .frame(maxWidth: .infinity, alignment:.leading)
                                        .padding(.top, 10)
                                        .padding(.horizontal, 20)
                                    TextField("Address", text: $model.address)
                                        .focused($focusedField, equals: .myField)
                                        .onChange(of: model.address) {
                                            print($0)
                                        }
                                        .padding(.vertical,15)
                                        .padding(.horizontal)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(model.address == "" ? Color.gray :
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
                                    .disabled(model.name == "" || model.address == "")
                                    .opacity(model.name == "" || model.address == "" ? 0.6 : 1)
                                    .padding(.top,10)
                                    .padding(.bottom,55)
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
                                    .onAppear {
                                        model.update()
                                    }
                                
                                TextField("Friend Name", text: $model.searchText)
                                    .focused($focusedField, equals: .myField)
                                    .padding(.vertical,15)
                                    .padding(.horizontal)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(model.searchText == "" ? Color.gray :
                                                        Color.pink,lineWidth: 1.5
                                                   )
                                    )
                                    .padding(.horizontal,20)
                                
                                
                                List {
                                    ForEach(model.searchResults, id: \.self) { friend in
                                        FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", id: friend["id"] ?? "", selectable: true, onSelect: {
                                            if (!model.invitedFriends.contains(friend["id"] ?? "")) {
                                                model.invitedFriends.append(friend["id"] ?? "")
                                            }
                
                                            
                                        }, onUnselect: {model.invitedFriends = model.invitedFriends.filter{ $0 != friend["id"] ?? ""}}, image: friend["pfp"])
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                    }
                                }
                                .frame(height: 200)
                                .listStyle(PlainListStyle())
                                .searchable(text: $model.searchText)
                                
                                
                                
                                
                                Button(action: {page = 3}, label: {
                                    Text("next")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.pink)
                                        .cornerRadius(8)
                                })
                                .padding(.top,10)
                                .padding(.bottom,55)
                                .padding(.horizontal)
                                
                            }
                            .animation(.easeInOut)
                            .transition(.move(edge: .bottom))
                            
                            
                            
                        }
                        
                        if page == 3 {
                            VStack {
                                Text("Choose a Time")
                                    .fontWeight(.bold)
                                    .padding(.top, 20)
                                    .padding(.bottom,5)
                                    .font(.system(size: 25))
                                
                                DatePicker("",selection: $model.date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                    .onAppear {
                                        model.date = Date()
                                    }
                                
                                
                                
                                Button(action: {
                                    model.sendData()
                                    withAnimation {
                                        isCreatingPin = false
                                        interact = false
                                        page = 1
                                    }
                                }, label: {
                                    Text("finish")
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.vertical)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.pink)
                                        .cornerRadius(8)
                                })
                                .padding(.top,10)
                                .padding(.bottom,55)
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
            
            if (model.pins.count == 0 && DataHandler.shared.friends.count == 0 && tutorial < 4) {

                
                VStack {
                    Spacer()
                    if (tutorial == 0) {
                    Text("Welcome to Storyboard!")
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
//                            .font(.largeTitle)
                            .font(.system(size: 25))
                            .transition(.opacity)
                            
                    } else if (tutorial == 1) {
                        ZStack {
                            Text("Swipe left to see your storyline")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .font(.title)
                                .transition(.opacity)
                            
                            HStack {
                                Image(systemName: "video").font(.largeTitle)
                                    .frame(maxWidth: 1, maxHeight: .infinity)
                                    .background(Color.clear)
                                    .foregroundColor(.clear)
                                    .clipShape(Rectangle())
                                    .offset(x:-30)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white)
                                            .scaleEffect(animationAmount2)
                                            .opacity(Double(2 - animationAmount2))
                                            .offset(x:Double(animationAmount2 * 15.0))
                                            .animation(Animation.easeOut(duration: 1)
                                                .repeatForever(autoreverses: false))
                                    )
                                    .onAppear
                                {
                                    self.animationAmount2 = 2
                                }
                                Spacer()
                            }
                        }
                    } else if (tutorial == 2) {
                        
                        ZStack {
                            Text("Swipe right to see your friends list")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .font(.title)
                                .transition(.opacity)
                            
                            HStack {
                                Spacer()
                                Image(systemName: "video").font(.largeTitle)
                                    .frame(maxWidth: 1, maxHeight: .infinity)
                                    .background(Color.clear)
                                    .foregroundColor(.clear)
                                    .clipShape(Rectangle())
                                    .offset(x:30)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.white)
                                            .scaleEffect(animationAmount3)
                                            .opacity(Double(2 - animationAmount3))
                                            .offset(x:-Double(animationAmount3 * 15.0))
                                            .animation(Animation.easeOut(duration: 1)
                                                .repeatForever(autoreverses: false))
                                    )
                                    .onAppear
                                {
                                    self.animationAmount3 = 2
                                }
                                
                            }
                        }
                    }
                    else if (tutorial == 3) {
                        ZStack {
                            Text("Tap and hold on the map to make a new event!")
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                                .font(.title)
                                .transition(.opacity)
                            Image(systemName: "video").font(.largeTitle)
                                .padding(30)
                                .background(Color.clear)
                                .foregroundColor(.clear)
                                .clipShape(Circle())
                                .offset(y: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white)
                                        .scaleEffect(animationAmount4)
                                        .opacity(Double(2 - animationAmount4))
                                        .animation(Animation.easeOut(duration: 1)
                                            .repeatForever(autoreverses: false))
                                )
                                .onAppear
                            {
                                self.animationAmount4 = 2
                            }
                        }
                    }
                    Spacer()
                    Text("Tap anywhere to continue")
                        .padding(.bottom, 50)
                        .opacity((Double(2 - animationAmount)) + 0.5)
                        .animation(Animation.easeOut(duration: 1)
                            .repeatForever(autoreverses: true))
                        .onAppear {
                            self.animationAmount = 2
                        }
                }
                .padding(.top, 50)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.5))
                .onTapGesture {
                    withAnimation {
                        tutorial += 1
                    }
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
