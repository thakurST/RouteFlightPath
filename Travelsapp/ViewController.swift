//
//  ViewController.swift
//  Travelsapp
//
//  Created by SandeepThakur on 10/03/25.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    // MARK: - Outlets

    @IBOutlet private weak var appleMapView: MKMapView!
    @IBOutlet private weak var fromButton: UIButton!
    @IBOutlet private weak var toButton: UIButton!

    // MARK: - Properties

    private var sourceCoordinate: CLLocationCoordinate2D?
    private var destinationCoordinate: CLLocationCoordinate2D?
    private var flightPolyline: MKPolyline?
    private var planeAnnotation: MKPointAnnotation?

    // MARK: - ViewController Life Cycles

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
    }

    private func setupMapView() {
        appleMapView.delegate = self
        appleMapView.overrideUserInterfaceStyle = .dark
        appleMapView.showsBuildings = false
        appleMapView.showsTraffic = false
    }

    // MARK: - Button Actions
    @IBAction private func fromButtonActions(_ sender: Any) {
        selectAirportFrom()
    }

    @IBAction private func toButtonActions(_ sender: Any) {
        selectAirportTo()
    }
    
    private func selectAirportFrom() {
        sourceCoordinate = CLLocationCoordinate2D(latitude: 22.636383,
                                                  longitude: 75.810692)
        addAnnotation(at: sourceCoordinate!, title: "CityDot")
        drawFlightPathIfPossible()
    }
    
    private func selectAirportTo() {
        destinationCoordinate = CLLocationCoordinate2D(latitude: 28.556160,
                                                       longitude: 77.100281)
        addAnnotation(at: destinationCoordinate!, title: "CityDot")
        drawFlightPathIfPossible()
    }

    private func addAnnotation(at coordinate: CLLocationCoordinate2D, title: String) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        appleMapView.addAnnotation(annotation)
    }

    private func drawFlightPathIfPossible() {
        guard let source = sourceCoordinate,
              let destination = destinationCoordinate else { return }

        appleMapView.removeOverlays(appleMapView.overlays) // Clear previous paths

        let controlPoint = calculateGreatCircleControlPoint(from: source, to: destination)
        let pathPoints = generateBezierCurve(from: source, control: controlPoint, to: destination)

        let polyline = MKPolyline(coordinates: pathPoints, count: pathPoints.count)
        flightPolyline = polyline
        appleMapView.addOverlay(polyline)

        // Add plane annotation at the source (without removing existing annotations)
        addPlaneAnnotation(at: source)

        // Zoom to fit both coordinates
        zoomToFitFlightPath()

        // Start the plane animation along the curved path
        animatePlane(along: polyline, duration: 15.0)
    }

    private func addPlaneAnnotation(at coordinate: CLLocationCoordinate2D) {
        if planeAnnotation == nil {
            planeAnnotation = MKPointAnnotation()
            planeAnnotation?.title = "Plane"
            appleMapView.addAnnotation(planeAnnotation!)
        }
        planeAnnotation?.coordinate = coordinate
    }

    private func zoomToFitFlightPath() {
        guard let source = sourceCoordinate, let destination = destinationCoordinate else { return }

        let annotations = appleMapView.annotations
        if annotations.count < 2 { return } // Ensure at least two points

        let coordinates = [source, destination]
        var regionRect = MKMapRect.null

        for coordinate in coordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0.1, height: 0.1)
            regionRect = regionRect.union(pointRect)
        }

        let edgePadding = UIEdgeInsets(top: 100, left: 50, bottom: 100, right: 50)
        appleMapView.setVisibleMapRect(regionRect, edgePadding: edgePadding, animated: true)
    }

    private func generateBezierCurve(from start: CLLocationCoordinate2D,
                                     control: CLLocationCoordinate2D,
                                     to end: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        var curvePoints: [CLLocationCoordinate2D] = []
        let segments = 100  // More segments = smoother curve

        for i in 0...segments {
            let t = Double(i) / Double(segments)
            let lat = (1 - t) * (1 - t) * start.latitude + 2 * (1 - t) * t * control.latitude + t * t * end.latitude
            let lon = (1 - t) * (1 - t) * start.longitude + 2 * (1 - t) * t * control.longitude + t * t * end.longitude
            curvePoints.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        return curvePoints
    }

    private func calculateGreatCircleControlPoint(from source: CLLocationCoordinate2D,
                                                  to destination: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat1 = source.latitude * .pi / 180
        let lon1 = source.longitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let lon2 = destination.longitude * .pi / 180

        let bx = cos(lat2) * cos(lon2 - lon1)
        let by = cos(lat2) * sin(lon2 - lon1)

        let midLat = atan2(sin(lat1) + sin(lat2), sqrt((cos(lat1) + bx) * (cos(lat1) + bx) + by * by))
        let midLon = lon1 + atan2(by, cos(lat1) + bx)

        let controlLat = midLat * 180 / .pi
        let controlLon = midLon * 180 / .pi

        let curveHeight = haversineDistance(from: source, to: destination) / 5.0
        let adjustedLat = controlLat + curveHeight * 0.02

        return CLLocationCoordinate2D(latitude: adjustedLat, longitude: controlLon)
    }
    
    private func animatePlane(along polyline: MKPolyline, duration: Double) {
        guard let planeAnnotation = planeAnnotation else {
            print("Plane annotation not found!")
            return
        }

        let pathPoints = polyline.points()
        let totalSteps = polyline.pointCount
        var step = 0
        
        Timer.scheduledTimer(withTimeInterval: duration / Double(totalSteps),
                             repeats: true) { timer in
            if step >= totalSteps {
                timer.invalidate()
                return
            }
            let coordinate = pathPoints[step].coordinate
            DispatchQueue.main.async {
                planeAnnotation.coordinate = coordinate
            }
            step += 1
        }
    }
    
    private func haversineDistance(from source: CLLocationCoordinate2D,
                                   to destination: CLLocationCoordinate2D) -> Double {
        let R = 6371.0
        let lat1 = source.latitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (destination.longitude - source.longitude) * .pi / 180
        
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }

}

// MARK: - MKMapView Delegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.black
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView,
                 viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.title == "Plane" {
            let identifier = "PlaneAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.image = UIImage(named: "airplane")
                annotationView?.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }
        
        if annotation.title == "CityDot" { // Render a small dot instead of a pin
            let identifier = "CityDot"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.image = UIImage(named: "dot") // Add `dot.png` (a small circle) to assets
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            return annotationView
        }
        return nil
    }
}
