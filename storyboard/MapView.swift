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

var real_pins: [Pin] = []

class MapPin: NSObject, MKAnnotation {
    
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let image: UIImage?
    let action: (() -> Void)?
    
    init(coordinate: CLLocationCoordinate2D,
         title: String? = nil,
         subtitle: String? = nil,
         action: (() -> Void)? = nil,
         image: UIImage? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.action = {print("HI")}
        self.image = image
    }
    
}

class CreateEventModel: ObservableObject {
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
    
    @Published var pins: [MapPin] = []
    
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
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "y, M, d, HH::mm::ss, Z"
        
        
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        let formatted = dateFormatter.string(from: date)
        //        let formatted = date.formatted()
        
        print(formatted)
        
        DataHandler.shared.createEvent(data: ["name": self.name, "address": self.address, "invited": self.invitedFriends, "date": formatted, "coords": encodeLocation(loc: newPin.coordinate)], completionHandler: {
            print("WORKS")
        })
        
        
        HTTPHandler().POST(url: "/createEvent", data: ["name": self.name, "address": self.address, "invited": self.invitedFriends, "date": formatted, "coords": encodeLocation(loc: newPin.coordinate), "id": uid]) { data in
            guard let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                print("Could not decode the data")
                return
            }
            
            if (decoded["success"]!) {
                print("SUCCESS")
                self.update()
            } else {
                print("FAIL")
            }
            
        }
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
        DataHandler.shared.events.values.forEach { event in
            self.events.append(event)
            self.eventsString.append([
                "name": event["name"] as! String,
                "coords": event["coords"] as! String,
            ])
        }
        
        self.incomingEvents = []
        self.incomingEventsString = []
        DataHandler.shared.incomingEvents.values.forEach { event in
            self.incomingEvents.append(event)
            self.incomingEventsString.append([
                "name": event["name"] as! String,
                "coords": event["coords"] as! String,
            ])
        }
        
        self.translatePins()
        self.friends = DataHandler.shared.friends
//        self.incomingEvents = DataHandler.shared.incomingEvents
    }
    
    
    func translatePins() {
        for event in events {
            if (event["name"] == nil) {
                break
            }
            self.pins.append(
                MapPin(coordinate: decodeLocation(str: event["coords"]! as! String), title: event["name"] as? String , action: {print("PIN")})
            )
            
            real_pins.append(Pin(name: (event["name"] as! String ) , coordinate: decodeLocation(str: event["coords"]! as! String)))
        }
        for event in incomingEvents {
            if (event["name"] == nil) {
                break
            }
            self.pins.append(
                MapPin(coordinate: decodeLocation(str: event["coords"]! as! String), title: event["name"] as? String , action: {print("PIN")})
            )
            
            real_pins.append(Pin(name: (event["name"] as! String ) , coordinate: decodeLocation(str: event["coords"]! as! String)))
        }
        
    }
    
    
}

struct EventTab: View {
    
    var event: [String:String]
    
    var body: some View {
        HStack {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .padding(.trailing, 5)
            Text(event["name"] ?? "")
                .frame(alignment: .leading)
            Spacer()
        }
        .frame(alignment: .leading)
        .padding(.horizontal, 15)
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
            
            CustomMap(annotations: $model.pins,interact: $interact, name: $model.name, add: $model.address, isCreatingPin: $isCreatingPin, newPin: $model.newPin, oldPin: $oldPin)
                .onAppear {
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
                            ForEach (model.eventsString, id: \.self) { event in
                                EventTab(event: event)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 15)
                            }
                            
                            Text("Incoming Events").padding(.bottom, 18)
                            ForEach (model.incomingEventsString, id: \.self) { event in
                                EventTab(event: event)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom, 18)
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
                                        FriendLabel(name:friend["fullname"] ?? "",username:friend["username"] ?? "", selectable: true, onSelect: {model.invitedFriends.append((friend["username"] ?? "").lowercased())}, onUnselect: {model.invitedFriends = model.invitedFriends.filter{ $0 != (friend["username"] ?? "").lowercased()}}, image: friend["pfp"])
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
            
        }
    }
}

struct MapView_Previews: PreviewProvider {
    static var previews: some View {
        MapView()
    }
}
