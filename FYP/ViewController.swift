//
//  ViewController.swift
//  FYP
//
//  Created by wireMuffin on 1/9/19.
//  Copyright © 2020 wireMuffin. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import AVFoundation

class ViewController: UIViewController, CLLocationManagerDelegate, UISearchBarDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var directionsLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var mapView: MKMapView!
    
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    
    var steps = [MKRouteStep]()
    let speechSynthesizer = AVSpeechSynthesizer()
    
    var stepCounter = 0
    
//    var timer : Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.startUpdatingLocation()
        
        mapView.userTrackingMode = .followWithHeading
    }
    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(true)
//
//        locationManager.startUpdatingLocation()
//    }
    
    func getDirections(to destination: MKMapItem) {
        let sourcePlacemark = MKPlacemark(coordinate: currentCoordinate)
        let sourceMapItem = MKMapItem(placemark: sourcePlacemark)
        
        let directionsRequest = MKDirectionsRequest()
        directionsRequest.source = sourceMapItem
        directionsRequest.destination = destination
        ///set the mode to walking, i.e pedestrian
        directionsRequest.transportType = .walking
        
        let directions = MKDirections(request: directionsRequest)
        directions.calculate { (response, _) in
            guard let response = response else { return }
            guard let selectedRoute = response.routes.first else { return }
            
            self.mapView.add(selectedRoute.polyline)
            
            self.locationManager.monitoredRegions.forEach({ self.locationManager.stopMonitoring(for: $0) })
            
            self.steps = selectedRoute.steps
            for (i, step) in selectedRoute.steps.enumerated(){
//                print(step.instructions)
//                print(step.distance)
                let region = CLCircularRegion(center: step.polyline.coordinate, radius: 20, identifier: String(i))
                self.locationManager.startMonitoring(for: region)
                let circle = MKCircle(center: region.center, radius: region.radius)
                self.mapView.add(circle)
            }
            
            let initialMessage = "In \(self.steps[0].distance) meters, \(self.steps[0].instructions) then in \(self.steps[1].distance) meters, \(self.steps[1].instructions)."
            self.directionsLabel.text = initialMessage
            let speechUtterance = AVSpeechUtterance(string: initialMessage)
            self.speechSynthesizer.speak(speechUtterance)
            self.stepCounter += 1
        }
    }
    
//    @objc func leaveRegionCheck(){
//        print("checking")
//        var isLeave = true
//        for step in steps{
//            if (step.distance) <= 100{
//                isLeave = false
//                break
//            }
//        }
//        if isLeave{
//            // replan the route if user leave the region
//            print("herere")
////            searchBarSearchButtonClicked(searchBar)
//        }
//    }
    
    //MARK: - CLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        manager.stopUpdatingLocation()
        guard let currentLocation = locations.first else { return }
        currentCoordinate = currentLocation.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("entered")
        stepCounter += 1
        if stepCounter < steps.count {
            let currentStep = steps[stepCounter]
            let message = "In \(currentStep.distance) meters, \(currentStep.instructions)"
            directionsLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
        } else {
            /// the last region, i.e. the destination
            let message = "Arrived at destination"
            directionsLabel.text = message
            let speechUtterance = AVSpeechUtterance(string: message)
            speechSynthesizer.speak(speechUtterance)
            
            /// re-initialize
            stepCounter = 0
            for monitoredRegion in locationManager.monitoredRegions{
                locationManager.stopMonitoring(for: monitoredRegion)
            }
        }
    }

    //MARK: - UISearchBarDelegate
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text
        searchRequest.region = MKCoordinateRegion(center: currentCoordinate, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        let search = MKLocalSearch(request: searchRequest)
        search.start { (response, _) in
            guard let response = response else { return }
            ///the above code is similar to, however if the following line is used, all "response" need to be unwrap before use:
            //if (response == nil) {return}
            guard let firstMapItem = response.mapItems.first else { return }
            self.getDirections(to: firstMapItem)
        }
//        self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(ViewController.leaveRegionCheck), userInfo: nil, repeats: true)

        ///start tracking section
        NotificationCenter.default.post(name: Notification.Name("selectFirstTime"), object: nil)
    }

    //MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        ///drawing the polyline and circle on map
        if overlay is MKPolyline {
            let polyline = MKPolylineRenderer(overlay: overlay)
            polyline.strokeColor = .blue
            polyline.lineWidth = 10
            return polyline
        } else if overlay is MKCircle {
            let circle = MKCircleRenderer(overlay: overlay)
            circle.strokeColor = .green
            circle.fillColor = .green
            circle.alpha = 0.5
            return circle
        }
        return MKOverlayRenderer()
    }
    
}

