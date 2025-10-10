//
//  MapOverlayView.swift
//  BlackboxPlayer
//
//  Mini map overlay showing GPS route
//

import SwiftUI
import MapKit

/// Mini map overlay showing current GPS location and route
struct MapOverlayView: View {
    let videoFile: VideoFile
    let currentTime: TimeInterval

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if videoFile.hasGPSData {
                    miniMap
                        .frame(width: 250, height: 200)
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                }
            }
        }
    }

    // MARK: - Mini Map

    private var miniMap: some View {
        ZStack(alignment: .topTrailing) {
            // Map view
            MapView(
                region: $region,
                routePoints: videoFile.metadata.routeCoordinates,
                currentPoint: currentGPSPoint
            )

            // Map controls
            VStack(spacing: 8) {
                Button(action: centerOnCurrentLocation) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }

                Button(action: fitRouteToView) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }
            }
            .padding(8)
        }
        .onAppear {
            updateMapRegion()
        }
        .onChange(of: currentTime) { _ in
            if let point = currentGPSPoint {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    // MARK: - Helper Methods

    private var currentGPSPoint: GPSPoint? {
        return videoFile.metadata.gpsPoint(at: currentTime)
    }

    private func updateMapRegion() {
        if let point = currentGPSPoint {
            region = MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else if let firstPoint = videoFile.metadata.routeCoordinates.first {
            region = MKCoordinateRegion(
                center: firstPoint.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    private func centerOnCurrentLocation() {
        if let point = currentGPSPoint {
            withAnimation {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    private func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: region.span
        )
    }

    private func fitRouteToView() {
        let coordinates = videoFile.metadata.routeCoordinates.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }

        // Calculate bounding box
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        withAnimation {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}

// MARK: - MapKit View Wrapper

/// NSViewRepresentable wrapper for MKMapView
struct MapView: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let routePoints: [GPSPoint]
    let currentPoint: GPSPoint?

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true

        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: true)

        // Remove existing overlays and annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add route polyline
        if !routePoints.isEmpty {
            let coordinates = routePoints.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
        }

        // Add current location annotation
        if let currentPoint = currentPoint {
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentPoint.coordinate
            annotation.title = "Current Position"
            mapView.addAnnotation(annotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 3.0
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "CurrentPosition"

            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // Use custom image for current position
            let image = NSImage(systemSymbolName: "location.circle.fill", accessibilityDescription: nil)
            let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .bold)
            annotationView?.image = image?.withSymbolConfiguration(config)

            return annotationView
        }
    }
}

// MARK: - Preview

struct MapOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            MapOverlayView(
                videoFile: VideoFile.allSamples.first!,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
