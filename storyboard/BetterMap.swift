import SwiftUI
import UIKit
import MapKit
import CoreLocation
import Contacts
import Firebase

extension CLPlacemark {
    var formattedAddress: String? {
        
        guard let postalAddress = postalAddress else {
            return nil
        }
        let formatter = CNPostalAddressFormatter()
        return formatter.string(from: postalAddress)
    }
}

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

class MapViewCoordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
    
    var mapViewController: CustomMap
    
    var gRecognizer = UILongPressGestureRecognizer()
    
    init(_ control: CustomMap) {
        
        self.mapViewController = control
        super.init()
        self.mapViewController.onStart = true
        self.gRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(tapHandler))
        self.gRecognizer.delegate = self
        self.mapViewController.mapView.addGestureRecognizer(gRecognizer)
    }
    
    @objc func tapHandler(_ gesture: UILongPressGestureRecognizer) {
        if self.mapViewController.interact { return }
        
        let location = gRecognizer.location(in: self.mapViewController.mapView)
        
        let coordinate = self.mapViewController.mapView.convert(location, toCoordinateFrom: self.mapViewController.mapView)
        
        //            print(coordinate)
        self.mapViewController.tapEmptySpot(coordinate: coordinate)
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let annotation = view.annotation
        view.image = UIImage(systemName: "circle.fill")
        guard let placemark = annotation as? MKPointAnnotation else { return }
    }
    
    func mapView(_ mapView: MKMapView,
                 didSelect view: MKAnnotationView) {
        
        guard let pin = view.annotation as? MapPin else {
            return
        }
        pin.action?()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is MKUserLocation {
            return MKUserLocationView(annotation: annotation, reuseIdentifier: NSStringFromClass(MKUserLocationView.self))
        }
        
        var annotationView: MKAnnotationView?
        
        guard let pin = annotation as? MapPin else {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: NSStringFromClass(MapPin.self))
            return annotationView
        }
        
        if let image = pin.image {
            annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(MapPin.self), for: pin)
            annotationView?.image = image
        } else {
            annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: NSStringFromClass(MKMarkerAnnotationView.self), for: pin)
        }
        
        
        return annotationView
        
    }
    

    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        print("hi")
    }
    
//    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
//        print(mapView)
//    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
//        print("WILL CHANGE")
    }
}



struct CustomMap: UIViewRepresentable {

   
    @Binding var annotations: [MapPin]
//    let addAnnotationListener: (MapPin) -> Void
    
    @Binding var interact: Bool
    @Binding var name: String
    @Binding var add: String

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    @Binding var isCreatingPin: Bool
    @Binding var newPin: MapPin
    
    @Binding var oldPin: MapPin?
    
    @Binding var onStart: Bool
    
    @Binding var saveCoords: CLLocationCoordinate2D
    
    let mapView = MKMapView(frame: .zero)
    
    func coordsToLoc(coords: CLLocationCoordinate2D) -> CLLocation {
        return CLLocation(latitude: coords.latitude, longitude: coords.longitude)
    }
    
    func makeUIView(context: Context) -> MKMapView {
//        let mapViews = MKMapView()
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MapPin.self))
        mapView.register(MKUserLocationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MKUserLocationView.self))
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MKMarkerAnnotationView.self))
        
        
        

        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()

        mapView.showsUserLocation = true
        if (onStart == false) {
            guard let coordinate = mapView.userLocation.location?.coordinate else { return mapView }
            let region = mapView.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: 200, longitudinalMeters: 200))
            mapView.setRegion(region, animated: true)
            onStart = true
        }

        mapView.delegate = context.coordinator
        
        return mapView
    }
    
    
    
    func updateUIView(_ view: MKMapView, context: Context) {
        view.delegate = context.coordinator
        
        view.showsUserLocation = true
        
//        print(view.centerCoordinate)
        
        guard var coordinate = manager.location?.coordinate else { return }
        if (isCreatingPin) {
            coordinate = newPin.coordinate
            let region = view.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: isCreatingPin ? 200 : 2400, longitudinalMeters: isCreatingPin ? 200 : 2400))
            view.setRegion(region, animated: true)
        }        
        
        if (onStart == false) {
            let region = view.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: isCreatingPin ? 200 : 2400, longitudinalMeters: isCreatingPin ? 200 : 2400))
            view.setRegion(region, animated: true)
        }
        
        if (interact == false && newPin != nil) {
            view.removeAnnotation(newPin)
        }
        
        if (oldPin != nil) {
            view.removeAnnotation(oldPin!)
        }
        if isCreatingPin {
            view.addAnnotation(newPin)
        }
        view.addAnnotations(annotations)
//        if annotations.count == 1 {
//            let coords = annotations.first!.coordinate
//            let region = MKCoordinateRegion(center: coords, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
//            view.setRegion(region, animated: true)
//        }
    }
    
    
    func makeCoordinator() -> MapViewCoordinator {
        MapViewCoordinator(self)
    }
    
    func tapEmptySpot(coordinate: CLLocationCoordinate2D) {
        let coords = coordsToLoc(coords: coordinate)
        geocoder.reverseGeocodeLocation(coords, completionHandler: { (places, error) in
            if error == nil {
                let firstLocation = places?[0]
                print(firstLocation?.name!)
                name = firstLocation?.name ?? "Some Random Place"
                print((firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? ""))
                add = (firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? "")

                if add == name {
                    name = "Some Random Place"
                }

                add = (firstLocation?.formattedAddress)!
                print(add)
                saveCoords = mapView.centerCoordinate
                isCreatingPin = true
                oldPin = newPin
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

struct MapO : UIViewRepresentable {

    class Coordinator: NSObject, MKMapViewDelegate {
            
            @Binding var selectedPin: MapPin?
            
            var parent: MapO
//            var gRecognizer = UILongPressGestureRecognizer()
            
            init(_ parent: MapO, selectedPin: Binding<MapPin?>) {
                self.parent = parent
                _selectedPin = selectedPin
                super.init()
//                self.gRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(tapHandler))
//                self.gRecognizer.delegate = self
//                self.parent.mapView.addGestureRecognizer(gRecognizer)
            }
            
//            @objc func tapHandler(_ gesture: UILongPressGestureRecognizer) {
//                if parent.interact { return }
//
//                let location = gRecognizer.location(in: self.parent.mapView)
//
//                let coordinate = self.parent.mapView.convert(location, toCoordinateFrom: self.parent.mapView)
//
//                //            print(coordinate)
//                self.parent.tapEmptySpot(coordinate: coordinate)
//            }
            
            
            
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
        
//        mapView.addAnnotation(newPin)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {

        guard var coordinate = manager.location?.coordinate else { return }
        if (isCreatingPin) {
            coordinate = newPin.coordinate
        }

        let region = uiView.regionThatFits(MKCoordinateRegion(center: coordinate, latitudinalMeters: isCreatingPin ? 200 : 2400, longitudinalMeters: isCreatingPin ? 200 : 2400))
        uiView.setRegion(region, animated: true)
        uiView.removeAnnotations(uiView.annotations)
        
        uiView.addAnnotations(pins)
        if (isCreatingPin) {
            let ann: [MapPin] = [newPin]
            uiView.addAnnotations(ann)
        }
        if let selectedPin = selectedPin {
            print(selectedPin.title)
            uiView.selectAnnotation(selectedPin, animated: false)
        }


    }

    func tapEmptySpot(coordinate: CLLocationCoordinate2D) {
        let coords = coordsToLoc(coords: coordinate)
        geocoder.reverseGeocodeLocation(coords, completionHandler: { (places, error) in
            if error == nil {
                let firstLocation = places?[0]
                print(firstLocation?.name!)
                name = firstLocation?.name ?? "Some Random Place"
                print((firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? ""))
                add = (firstLocation?.subThoroughfare ?? "") + " " + (firstLocation?.thoroughfare ?? "")

                if add == name {
                    name = "Some Random Place"
                }

                add = (firstLocation?.formattedAddress)!
                print(add)

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
