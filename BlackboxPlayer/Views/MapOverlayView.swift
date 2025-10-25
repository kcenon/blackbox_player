/// @file MapOverlayView.swift
/// @brief View for displaying GPS routes as minimap overlay
/// @author BlackboxPlayer Development Team
/// @details
/// A View that displays GPS routes as a minimap overlay. Integrates MapKit's MKMapView into SwiftUI
/// using NSViewRepresentable, providing past/future route segmentation, real-time location tracking, and impact event marker features.

import SwiftUI
import MapKit

/// # MapOverlayView
///
/// A View that displays GPS routes as a minimap overlay.
///
/// ## Screen Layout
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │                                                  │
/// │                                                  │
/// │                                     ┌─────────┐ │
/// │                                     │  📍  🔍  │ │
/// │                                     │         │ │
/// │                                     │  ═══●━━ │ │
/// │                                     │ /       │ │
/// │                                     │/        │ │
/// │                                     └─────────┘ │
/// │                                     ^^minimap^^  │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## Key Features
/// - **Route Display**: Past route (blue solid line) + Future route (gray dashed line)
/// - **Current Location**: Location marker and speed display
/// - **Impact Events**: Warning markers at incident points
/// - **Control Buttons**: Center on location, fit entire route to view
///
/// ## SwiftUI Core Concepts
///
/// ### 1. AppKit Integration via NSViewRepresentable
/// ```swift
/// struct EnhancedMapView: NSViewRepresentable {
///     func makeNSView(context: Context) -> MKMapView { ... }
///     func updateNSView(_ mapView: MKMapView, context: Context) { ... }
///     func makeCoordinator() -> Coordinator { ... }
/// }
/// ```
///
/// **What is NSViewRepresentable?**
/// - A protocol that enables AppKit (macOS) NSViews to be used in SwiftUI
/// - iOS uses UIViewRepresentable (same pattern)
/// - MapKit's MKMapView is not SwiftUI native, so wrapping is required
///
/// **3 Required Methods:**
/// 1. **makeNSView**: Create NSView and initial setup (called once)
/// 2. **updateNSView**: Update NSView when SwiftUI state changes (called multiple times)
/// 3. **makeCoordinator**: Create Coordinator for Delegate handling (optional)
///
/// **Why is it needed?**
/// - MKMapView is an AppKit component (not SwiftUI)
/// - Cannot be used directly in SwiftUI
/// - Wrapping with NSViewRepresentable allows SwiftUI-like usage
///
/// ### 2. Delegate Handling via Coordinator Pattern
/// ```swift
/// class Coordinator: NSObject, MKMapViewDelegate {
///     func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer { ... }
///     func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? { ... }
/// }
/// ```
///
/// **What is a Coordinator?**
/// - An intermediary that connects NSViewRepresentable with Delegate methods
/// - Adopts MKMapViewDelegate to handle map events
/// - Acts as a communication bridge between SwiftUI and AppKit
///
/// **Why is it needed?**
/// - MKMapView uses the Delegate pattern (SwiftUI does not)
/// - An object is needed to handle Delegate methods
/// - Coordinator fulfills this role
///
/// ### 3. Two-way Binding via @Binding
/// ```swift
/// struct EnhancedMapView: NSViewRepresentable {
///     @Binding var region: MKCoordinateRegion
/// }
/// ```
///
/// **What is @Binding?**
/// - Two-way binding by referencing parent View's @State
/// - Can read and write values
/// - Parent and child share the same value
///
/// **Usage Pattern:**
/// ```swift
/// // Parent View
/// @State private var region = MKCoordinateRegion(...)
/// EnhancedMapView(region: $region)  // Use $
///
/// // Child View (EnhancedMapView)
/// @Binding var region: MKCoordinateRegion  // Declare without $
/// ```
///
/// ### 4. Route Segmentation
/// ```swift
/// let segments = gpsService.getRouteSegments(at: currentTime)
/// EnhancedMapView(
///     pastRoute: segments.past,      // Traveled route (blue)
///     futureRoute: segments.future   // Future route (gray)
/// )
/// ```
///
/// **What is Route Segmentation?**
/// - Split the entire GPS route into 2 parts based on currentTime
/// - Past route: 0s ~ currentTime (already traveled)
/// - Future route: currentTime ~ end (not yet traveled)
///
/// **Visual Representation:**
/// ```
/// currentTime = 30s
///
/// Full route: [0s] ─────── [30s] ─────── [60s]
///                  ^past^      ^future^
///
/// Map display:
/// ════════════●━━━━━━━━━━━
/// ^blue solid^ ^gray dashed^
///            ^current position
/// ```
///
/// ### 5. Polyline Rendering
/// ```swift
/// func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
///     if let polyline = overlay as? MKPolyline {
///         let renderer = MKPolylineRenderer(polyline: polyline)
///         renderer.strokeColor = NSColor.systemBlue
///         renderer.lineWidth = 4.0
///         return renderer
///     }
/// }
/// ```
///
/// **What is a Polyline?**
/// - A line connecting multiple coordinates
/// - Used to draw GPS routes on the map
/// - Created with MKPolyline(coordinates:count:)
///
/// **What is a Renderer?**
/// - Responsible for drawing Overlays on screen
/// - Specifies style such as color, width, dash pattern
/// - Created with MKPolylineRenderer(polyline:)
///
/// ### 6. Bounding Box Calculation
/// ```swift
/// let minLat = coordinates.map { $0.latitude }.min() ?? 0
/// let maxLat = coordinates.map { $0.latitude }.max() ?? 0
/// let minLon = coordinates.map { $0.longitude }.min() ?? 0
/// let maxLon = coordinates.map { $0.longitude }.max() ?? 0
///
/// let center = CLLocationCoordinate2D(
///     latitude: (minLat + maxLat) / 2,
///     longitude: (minLon + maxLon) / 2
/// )
/// ```
///
/// **What is a Bounding Box?**
/// - The minimum rectangle containing all GPS coordinates
/// - Used to fit the entire route on screen
///
/// **Calculation Process:**
/// ```
/// GPS Coordinates:
/// (37.5665, 126.9780)
/// (37.5670, 126.9785)
/// (37.5660, 126.9775)
///
/// Bounding Box:
/// minLat = 37.5660
/// maxLat = 37.5670
/// minLon = 126.9775
/// maxLon = 126.9785
///
/// center = ((37.5660 + 37.5670) / 2, (126.9775 + 126.9785) / 2)
///        = (37.5665, 126.9780)
/// ```
///
/// ## Usage Examples
///
/// ### Example 1: Using in VideoPlayerView
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var gpsService = GPSService()
///     @StateObject private var gsensorService = GSensorService()
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             // Video screen
///             VideoFrameView(frame: currentFrame)
///
///             // Minimap overlay
///             MapOverlayView(
///                 gpsService: gpsService,
///                 gsensorService: gsensorService,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### Example 2: Toggleable Minimap
/// ```swift
/// @State private var showMiniMap = true
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if showMiniMap {
///         MapOverlayView(
///             gpsService: gpsService,
///             gsensorService: gsensorService,
///             currentTime: currentTime
///         )
///         .transition(.move(edge: .trailing))
///     }
/// }
/// .toolbar {
///     Button("Toggle Map") {
///         withAnimation {
///             showMiniMap.toggle()
///         }
///     }
/// }
/// ```
///
/// ## Practical Applications
///
/// ### Resizable Minimap
/// ```swift
/// @State private var mapSize: CGSize = CGSize(width: 250, height: 200)
///
/// MapOverlayView(...)
///     .frame(width: mapSize.width, height: mapSize.height)
///     .gesture(
///         DragGesture()
///             .onChanged { value in
///                 mapSize.width = max(200, min(400, mapSize.width + value.translation.width))
///                 mapSize.height = max(150, min(300, mapSize.height + value.translation.height))
///             }
///     )
/// ```
///
/// ### Map Type Switching (Standard/Satellite/Hybrid)
/// ```swift
/// @State private var mapType: MKMapType = .standard
///
/// func makeNSView(context: Context) -> MKMapView {
///     let mapView = MKMapView()
///     mapView.mapType = mapType  // .standard, .satellite, .hybrid
///     return mapView
/// }
/// ```
///
/// ### Speed Display Animation
/// ```swift
/// Text(String(format: "%.0f km/h", currentSpeed))
///     .font(.system(size: 14, weight: .bold, design: .rounded))
///     .foregroundColor(speedColor(currentSpeed))
///     .animation(.easeInOut(duration: 0.3), value: currentSpeed)
/// ```
///
/// ## Performance Optimization
///
/// ### 1. Minimize Polyline Updates
/// ```swift
/// // Current: Regenerate entire route every time (inefficient)
/// mapView.removeOverlays(mapView.overlays)
/// mapView.addOverlay(polyline)
///
/// // Improved: Update only changed portions
/// if lastUpdateTime != currentTime {
///     updatePolyline(from: lastUpdateTime, to: currentTime)
///     lastUpdateTime = currentTime
/// }
/// ```
///
/// ### 2. Reuse Annotations
/// ```swift
/// var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
/// // ✅ Reuse: Memory efficient
/// ```
///
/// ### 3. Limit Region Change Animations
/// ```swift
/// // Prevent too frequent calls in onChange
/// .onChange(of: currentTime) { newTime in
///     // Update only once per second
///     if Int(newTime) != Int(oldTime) {
///         centerOnCurrentLocation()
///     }
/// }
/// ```
///
/// @struct MapOverlayView
/// @brief View for displaying GPS routes as minimap overlay
struct MapOverlayView: View {
    // MARK: - Properties

    /// @var gpsService
    /// @brief GPS service (@ObservedObject)
    ///
    /// **What is GPSService?**
    /// - Service class that manages GPS data
    /// - Provides route points, current location, and route segmentation
    /// - View automatically updates when @Published properties change
    ///
    /// **Key Features:**
    /// - `routePoints`: Array of all GPS route points
    /// - `currentLocation`: GPS point at current time
    /// - `getRouteSegments(at:)`: Split route into past/future
    /// - `hasData`: Whether GPS data exists
    @ObservedObject var gpsService: GPSService

    /// @var gsensorService
    /// @brief G-Sensor service (@ObservedObject)
    ///
    /// **What is GSensorService?**
    /// - Service class that manages acceleration sensor data
    /// - Detects and manages impact events
    /// - View automatically updates when @Published properties change
    ///
    /// **Key Features:**
    /// - `impactEvents`: Array of impact events (4G or more)
    /// - `accelerationData`: All acceleration data
    @ObservedObject var gsensorService: GSensorService

    /// @var currentTime
    /// @brief Current playback time
    ///
    /// **Purpose:**
    /// - Reference point for splitting GPS route into past/future
    /// - Used to calculate current position
    /// - Map updates detected via onChange
    let currentTime: TimeInterval

    /// @var region
    /// @brief Map region (@State)
    ///
    /// **What is MKCoordinateRegion?**
    /// - Defines the region to display on the map
    /// - center: Center coordinate (latitude, longitude)
    /// - span: Visible range (latitudeDelta, longitudeDelta)
    ///
    /// **Span values meaning:**
    /// ```
    /// latitudeDelta: 0.01  → approx 1.1km height
    /// longitudeDelta: 0.01 → approx 1.1km width (varies by latitude)
    ///
    /// latitudeDelta: 0.1   → approx 11km height
    /// latitudeDelta: 1.0   → approx 111km height
    /// ```
    ///
    /// **Initial value (Seoul City Hall):**
    /// - center: (37.5665, 126.9780)
    /// - span: (0.01, 0.01) → approx 1.1km × 1.1km area
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                // Show minimap only when GPS data is available
                //
                // gpsService.hasData: Check if there is at least one GPS point
                if gpsService.hasData {
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

    /// @brief Minimap
    ///
    /// ## Structure
    /// ```
    /// ┌──────────────┐
    /// │  📍  🔍      │  ← Control buttons (topTrailing)
    /// │              │
    /// │  ═══●━━━━━  │  ← Route (blue solid + gray dashed)
    /// │ /            │
    /// │/             │
    /// └──────────────┘
    /// ```
    ///
    /// ## Layer Structure (ZStack)
    /// 1. **EnhancedMapView**: MKMapView wrapper (map, route, markers)
    /// 2. **Control buttons**: Center on location, fit route to view (topTrailing)
    ///
    /// ## Route Segments
    /// ```swift
    /// let segments = gpsService.getRouteSegments(at: currentTime)
    /// ```
    ///
    /// **What is getRouteSegments?**
    /// - Split route into 2 parts based on currentTime
    /// - segments.past: 0s ~ currentTime (traveled route)
    /// - segments.future: currentTime ~ end (not yet traveled)
    ///
    /// **Example:**
    /// ```
    /// currentTime = 30s
    /// Total route: 60s duration
    ///
    /// segments.past = [GPS points from 0s ~ 30s]
    /// segments.future = [GPS points from 30s ~ 60s]
    /// ```
    ///
    /// ## onChange(of: currentTime)
    /// ```swift
    /// .onChange(of: currentTime) { _ in
    ///     if let point = gpsService.currentLocation {
    ///         centerOnCoordinate(point.coordinate)
    ///     }
    /// }
    /// ```
    ///
    /// **What is onChange?**
    /// - Execute closure whenever a specific value changes
    /// - Move map center whenever currentTime changes
    /// - Track current location in real-time
    ///
    /// **How it works:**
    /// ```
    /// currentTime: 0 → 5 → 10 → 15 → ...
    ///                  ↓   ↓    ↓
    ///              centerOnCoordinate called
    /// ```
    private var miniMap: some View {
        ZStack(alignment: .topTrailing) {
            // Enhanced map view with route segmentation
            //
            // Display route split into past/future
            let segments = gpsService.getRouteSegments(at: currentTime)
            EnhancedMapView(
                region: $region,
                pastRoute: segments.past,
                futureRoute: segments.future,
                currentPoint: gpsService.currentLocation,
                impactEvents: gsensorService.impactEvents
            )

            // Map control buttons
            //
            // topTrailing alignment: Positioned at top right
            VStack(spacing: 8) {
                /// @brief Center on current location button
                ///
                /// **Action:**
                /// - Move current location to map center
                /// - Smooth animation via withAnimation
                Button(action: centerOnCurrentLocation) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }

                /// @brief Fit entire route to view button
                ///
                /// **Action:**
                /// - Adjust map region so all routes are visible
                /// - Calculate bounding box to set optimal region
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
            /// @brief Initialize map region when View appears
            ///
            /// **Action:**
            /// - Set map center to current location or first GPS point
            /// - Called only once initially
            updateMapRegion()
        }
        .onChange(of: currentTime) { _ in
            /// @brief Move map center when currentTime changes
            ///
            /// **Action:**
            /// - Move map center to current location
            /// - Track location in real-time
            if let point = gpsService.currentLocation {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    // MARK: - Helper Methods

    /// @brief Initialize map region
    ///
    /// ## Action Sequence
    /// 1. If current location exists → Set center to current location
    /// 2. If no current location → Set center to first GPS point
    /// 3. If no GPS data → Keep default value (Seoul City Hall)
    ///
    /// ## When to Use
    /// - onAppear: When View first appears
    /// - Map initialization
    ///
    /// ## Code Flow
    /// ```swift
    /// if let point = gpsService.currentLocation {
    ///     // Set to current location
    /// } else if let firstPoint = gpsService.routePoints.first {
    ///     // Set to first point
    /// }
    /// // Keep default if both are unavailable
    /// ```
    private func updateMapRegion() {
        if let point = gpsService.currentLocation {
            region = MKCoordinateRegion(
                center: point.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else if let firstPoint = gpsService.routePoints.first {
            region = MKCoordinateRegion(
                center: firstPoint.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }

    /// @brief Move current location to map center
    ///
    /// ## withAnimation
    /// ```swift
    /// withAnimation {
    ///     centerOnCoordinate(point.coordinate)
    /// }
    /// ```
    ///
    /// **What is withAnimation?**
    /// - Animates state changes within the block
    /// - Region changes are smoothly animated
    /// - Default duration: 0.35 seconds
    ///
    /// **Animation Effect:**
    /// - Map moves smoothly (doesn't jump abruptly)
    /// - Improves user experience
    ///
    /// ## When to Use
    /// - When user clicks 📍 button
    /// - When wanting to quickly move to current location
    private func centerOnCurrentLocation() {
        if let point = gpsService.currentLocation {
            withAnimation {
                centerOnCoordinate(point.coordinate)
            }
        }
    }

    /// @brief Move specific coordinate to map center
    ///
    /// ## Action
    /// ```swift
    /// region = MKCoordinateRegion(
    ///     center: coordinate,  // New center coordinate
    ///     span: region.span    // Keep existing zoom level
    /// )
    /// ```
    ///
    /// **Why preserve span?**
    /// - Keep zoom level as is
    /// - Only move center, don't change zoom level
    ///
    /// **Example:**
    /// ```
    /// Current region:
    ///   center: (37.5665, 126.9780)
    ///   span: (0.01, 0.01)
    ///
    /// After centerOnCoordinate((37.5670, 126.9785)):
    ///   center: (37.5670, 126.9785)  ← Changed
    ///   span: (0.01, 0.01)           ← Preserved
    /// ```
    private func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D) {
        region = MKCoordinateRegion(
            center: coordinate,
            span: region.span
        )
    }

    /// @brief Fit entire route to map
    ///
    /// ## Bounding Box Calculation
    /// ```swift
    /// let minLat = coordinates.map { $0.latitude }.min() ?? 0
    /// let maxLat = coordinates.map { $0.latitude }.max() ?? 0
    /// ```
    ///
    /// **What is a Bounding Box?**
    /// - The minimum rectangle containing all GPS coordinates
    /// - Defined by min/max latitude/longitude
    ///
    /// **Calculation Example:**
    /// ```
    /// GPS Coordinates:
    /// (37.5665, 126.9780)
    /// (37.5670, 126.9785)
    /// (37.5660, 126.9775)
    ///
    /// minLat = 37.5660  (southernmost)
    /// maxLat = 37.5670  (northernmost)
    /// minLon = 126.9775 (westernmost)
    /// maxLon = 126.9785 (easternmost)
    /// ```
    ///
    /// ## Center Coordinate Calculation
    /// ```swift
    /// let center = CLLocationCoordinate2D(
    ///     latitude: (minLat + maxLat) / 2,
    ///     longitude: (minLon + maxLon) / 2
    /// )
    /// ```
    ///
    /// **Why use average?**
    /// - Exact center of the bounding box
    /// - Route appears evenly distributed
    ///
    /// **Calculation:**
    /// ```
    /// center.latitude = (37.5660 + 37.5670) / 2 = 37.5665
    /// center.longitude = (126.9775 + 126.9785) / 2 = 126.9780
    /// ```
    ///
    /// ## Span Calculation
    /// ```swift
    /// let span = MKCoordinateSpan(
    ///     latitudeDelta: (maxLat - minLat) * 1.2,
    ///     longitudeDelta: (maxLon - minLon) * 1.2
    /// )
    /// ```
    ///
    /// **Why multiply by 1.2?**
    /// - Add 20% padding
    /// - Route doesn't stick to screen edges
    /// - More visually comfortable
    ///
    /// **Example:**
    /// ```
    /// latitudeDelta = (37.5670 - 37.5660) * 1.2 = 0.001 * 1.2 = 0.0012
    /// longitudeDelta = (126.9785 - 126.9775) * 1.2 = 0.001 * 1.2 = 0.0012
    /// ```
    ///
    /// ## When to Use
    /// - When user clicks 🔍 button
    /// - When wanting to see entire route at once
    private func fitRouteToView() {
        let coordinates = gpsService.routePoints.map { $0.coordinate }
        guard !coordinates.isEmpty else { return }

        // Calculate bounding box
        let minLat = coordinates.map { $0.latitude }.min() ?? 0
        let maxLat = coordinates.map { $0.latitude }.max() ?? 0
        let minLon = coordinates.map { $0.longitude }.min() ?? 0
        let maxLon = coordinates.map { $0.longitude }.min() ?? 0

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

// MARK: - Enhanced MapKit View Wrapper

/// # EnhancedMapView
///
/// A wrapper that integrates MKMapView into SwiftUI via NSViewRepresentable.
///
/// ## What is NSViewRepresentable?
///
/// **Definition:**
/// - A protocol that enables AppKit (macOS) NSViews to be used in SwiftUI
/// - iOS uses UIViewRepresentable (same pattern)
///
/// **Why is it needed?**
/// - MKMapView is an AppKit component (not SwiftUI native)
/// - Cannot be used directly in SwiftUI
/// - Wrapping with NSViewRepresentable allows SwiftUI-like usage
///
/// ## 3 Required Methods
///
/// ### 1. makeNSView(context:)
/// ```swift
/// func makeNSView(context: Context) -> MKMapView {
///     let mapView = MKMapView()
///     mapView.delegate = context.coordinator
///     return mapView
/// }
/// ```
///
/// **When is it called?**
/// - Called once when View is first created
/// - Creates NSView instance and performs initial setup
///
/// **Main Tasks:**
/// - Create NSView
/// - Set delegate
/// - Apply initial styling
///
/// ### 2. updateNSView(_:context:)
/// ```swift
/// func updateNSView(_ mapView: MKMapView, context: Context) {
///     mapView.setRegion(region, animated: true)
///     // Update Overlays, Annotations
/// }
/// ```
///
/// **When is it called?**
/// - Called whenever @Binding, @State, etc. change
/// - Runs whenever currentTime, region, etc. change
///
/// **Main Tasks:**
/// - Update NSView state
/// - Reset Overlays
/// - Reset Annotations
///
/// ### 3. makeCoordinator()
/// ```swift
/// func makeCoordinator() -> Coordinator {
///     Coordinator(self)
/// }
/// ```
///
/// **When is it called?**
/// - Called once before makeNSView
/// - Creates Coordinator instance
///
/// **Main Tasks:**
/// - Create Delegate object
/// - Pass parent View reference
///
/// ## Coordinator Pattern
///
/// **What is a Coordinator?**
/// - An intermediary that connects NSViewRepresentable with Delegate methods
/// - Adopts MKMapViewDelegate to handle map events
/// - Acts as a communication bridge between SwiftUI and AppKit
///
/// **Why is it needed?**
/// - MKMapView uses the Delegate pattern (SwiftUI does not)
/// - An object is needed to handle Delegate methods
/// - Coordinator fulfills this role
///
/// **Call Flow:**
/// ```
/// SwiftUI → NSViewRepresentable → Coordinator → MKMapViewDelegate
///                                      ↓
///                                  mapView events
/// ```
///
/// @struct EnhancedMapView
/// @brief A wrapper that integrates MKMapView into SwiftUI via NSViewRepresentable
struct EnhancedMapView: NSViewRepresentable {
    // MARK: - Properties

    /// @var region
    /// @brief Map region (@Binding)
    ///
    /// **What is @Binding?**
    /// - Two-way binding by referencing parent View's @State
    /// - Can read and write values
    /// - Parent and child share the same value
    ///
    /// **Usage Pattern:**
    /// ```swift
    /// // Parent View (MapOverlayView)
    /// @State private var region = MKCoordinateRegion(...)
    /// EnhancedMapView(region: $region)  // Use $
    ///
    /// // Child View (EnhancedMapView)
    /// @Binding var region: MKCoordinateRegion  // Declare without $
    /// ```
    @Binding var region: MKCoordinateRegion

    /// @var pastRoute
    /// @brief Past route (traveled route)
    ///
    /// **Display Style:**
    /// - Color: Blue (NSColor.systemBlue)
    /// - Width: 4.0
    /// - Pattern: Solid line
    let pastRoute: [GPSPoint]

    /// @var futureRoute
    /// @brief Future route (not yet traveled)
    ///
    /// **Display Style:**
    /// - Color: Gray (NSColor.systemGray)
    /// - Width: 3.0
    /// - Pattern: Dashed [2, 4] (2px line, 4px gap)
    let futureRoute: [GPSPoint]

    /// @var currentPoint
    /// @brief Current location
    ///
    /// **Display Style:**
    /// - Icon: "location.circle.fill" (📍)
    /// - Size: 24pt
    /// - Callout: Speed information display
    let currentPoint: GPSPoint?

    /// @var impactEvents
    /// @brief Impact events (4G or more)
    ///
    /// **Display Style:**
    /// - Icon: "exclamationmark.triangle.fill" (⚠️)
    /// - Size: 18pt
    /// - Callout: Impact severity display
    let impactEvents: [AccelerationData]

    // MARK: - NSViewRepresentable Methods

    /// @brief Create NSView and perform initial setup
    ///
    /// ## When Called
    /// - Called once when View is first created
    /// - Executed once initially in SwiftUI lifecycle
    ///
    /// ## Initial Setup
    /// ```swift
    /// mapView.delegate = context.coordinator
    /// mapView.mapType = .standard
    /// mapView.showsCompass = true
    /// mapView.showsScale = true
    /// ```
    ///
    /// **What is context.coordinator?**
    /// - Coordinator instance created by makeCoordinator()
    /// - Performs MKMapViewDelegate role
    /// - Handles mapView events
    ///
    /// **mapType options:**
    /// - `.standard`: Standard map (default)
    /// - `.satellite`: Satellite imagery
    /// - `.hybrid`: Satellite + road names
    ///
    /// **showsCompass:**
    /// - true: Show compass (top right)
    /// - false: Hide compass
    ///
    /// **showsScale:**
    /// - true: Show scale (top left)
    /// - false: Hide scale
    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true

        return mapView
    }

    /// @brief Update NSView
    ///
    /// ## When Called
    /// - Called whenever @Binding, @State, etc. change
    /// - Runs whenever region, pastRoute, futureRoute, etc. change
    ///
    /// ## Update Sequence
    /// 1. Set region (move map area)
    /// 2. Remove existing Overlays, Annotations
    /// 3. Add new Overlays (past/future routes)
    /// 4. Add new Annotations (current location, impact events)
    ///
    /// ## Overlay vs Annotation
    ///
    /// **Overlay:**
    /// - Shapes drawn on the map (lines, polygons, etc.)
    /// - Examples: Polyline (route), Circle (area), Polygon (zone)
    /// - Rendered via rendererFor overlay Delegate method
    ///
    /// **Annotation:**
    /// - Markers/pins on the map
    /// - Examples: Current location, impact points, points of interest
    /// - Rendered via viewFor annotation Delegate method
    ///
    /// ## Why remove and re-add every time?
    /// ```swift
    /// mapView.removeOverlays(mapView.overlays)
    /// mapView.removeAnnotations(mapView.annotations)
    /// ```
    ///
    /// **Reasons:**
    /// - Completely reset previous state
    /// - Prevent duplicate displays
    /// - Simple and clear updates
    ///
    /// **Drawbacks:**
    /// - Possible performance degradation from constant regeneration
    /// - Optimization needed for large datasets
    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Update region
        //
        // Smooth movement with animated: true
        mapView.setRegion(region, animated: true)

        // Remove existing overlays and annotations
        //
        // Remove all existing Overlays and Annotations
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)

        // Add past route polyline (traveled path - blue)
        //
        // Past route: Blue solid line
        if !pastRoute.isEmpty {
            let coordinates = pastRoute.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "past"  // Identifier for Renderer differentiation
            mapView.addOverlay(polyline)
        }

        // Add future route polyline (not yet traveled - gray)
        //
        // Future route: Gray dashed line
        if !futureRoute.isEmpty {
            let coordinates = futureRoute.map { $0.coordinate }
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            polyline.title = "future"  // Identifier for Renderer differentiation
            mapView.addOverlay(polyline)
        }

        // Add impact event markers
        //
        // Impact events: ⚠️ markers
        for impact in impactEvents {
            // Find GPS point closest to impact timestamp
            // For now, we'll use a simple approach - in production, we'd query GPSService
            let annotation = MKPointAnnotation()
            // Note: We need to convert impact timestamp to coordinate
            // This would require GPSService integration - placeholder for now
            annotation.title = "Impact"
            annotation.subtitle = impact.impactSeverity.displayName
            // mapView.addAnnotation(annotation)  // Commented out until we have proper coordinate mapping
        }

        // Add current location annotation
        //
        // Current location: 📍 marker
        if let currentPoint = currentPoint {
            let annotation = MKPointAnnotation()
            annotation.coordinate = currentPoint.coordinate
            annotation.title = "Current Position"
            if let speed = currentPoint.speed {
                annotation.subtitle = String(format: "%.1f km/h", speed)
            }
            mapView.addAnnotation(annotation)
        }
    }

    /// @brief Create Coordinator
    ///
    /// ## When Called
    /// - Called once before makeNSView
    /// - Executed once initially in View lifecycle
    ///
    /// ## Coordinator(self)
    /// ```swift
    /// Coordinator(self)
    /// ```
    ///
    /// **What is self?**
    /// - EnhancedMapView instance
    /// - Stored as parent and accessible from Coordinator
    ///
    /// **Why is parent needed?**
    /// - Access EnhancedMapView properties from Coordinator
    /// - Example: parent.pastRoute, parent.futureRoute
    /// - Read SwiftUI state in Delegate methods
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    /// @class Coordinator
    /// @brief Coordinator class
    ///
    /// ## Role
    /// - Implement MKMapViewDelegate
    /// - Render Overlays (route lines)
    /// - Render Annotations (markers)
    /// - Act as intermediary between SwiftUI and AppKit
    ///
    /// ## Structure
    /// ```
    /// EnhancedMapView (SwiftUI)
    ///        ↓
    ///   Coordinator (intermediary)
    ///        ↓
    /// MKMapViewDelegate (AppKit)
    /// ```
    ///
    /// ## parent property
    /// ```swift
    /// var parent: EnhancedMapView
    /// ```
    ///
    /// **Purpose:**
    /// - Access EnhancedMapView properties
    /// - Link with SwiftUI state
    ///
    /// **Example:**
    /// ```swift
    /// // Use in Coordinator
    /// if parent.pastRoute.isEmpty { ... }
    /// ```
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EnhancedMapView

        init(_ parent: EnhancedMapView) {
            self.parent = parent
        }

        /// @brief Render Overlay
        ///
        /// ## When Called
        /// - Executed whenever mapView.addOverlay() is called
        /// - Returns Renderer to draw Overlay on screen
        ///
        /// ## Polyline Rendering
        /// ```swift
        /// if let polyline = overlay as? MKPolyline {
        ///     let renderer = MKPolylineRenderer(polyline: polyline)
        ///     renderer.strokeColor = NSColor.systemBlue
        ///     renderer.lineWidth = 4.0
        ///     return renderer
        /// }
        /// ```
        ///
        /// **What is MKPolylineRenderer?**
        /// - Object that draws Polyline on screen
        /// - Specifies style such as color, width, pattern
        ///
        /// ## Differentiate by polyline.title
        /// ```swift
        /// if polyline.title == "past" {
        ///     // Past route: Blue solid line
        /// } else if polyline.title == "future" {
        ///     // Future route: Gray dashed line
        /// }
        /// ```
        ///
        /// **title property:**
        /// - String to identify Polyline
        /// - Set in updateNSView
        /// - Used for style branching in Renderer
        ///
        /// ## lineDashPattern
        /// ```swift
        /// renderer.lineDashPattern = [2, 4]
        /// ```
        ///
        /// **Dash pattern:**
        /// - [2, 4]: 2px line → 4px gap → repeat
        /// - [5, 5]: 5px line → 5px gap → repeat
        /// - [10, 5, 2, 5]: Complex patterns possible
        ///
        /// **Visual effect:**
        /// ```
        /// [2, 4]: ══ ══ ══ ══
        /// [5, 5]: ═════ ═════ ═════
        /// ```
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)

                // Different colors for past and future routes
                if polyline.title == "past" {
                    renderer.strokeColor = NSColor.systemBlue
                    renderer.lineWidth = 4.0
                } else if polyline.title == "future" {
                    renderer.strokeColor = NSColor.systemGray
                    renderer.lineWidth = 3.0
                    renderer.lineDashPattern = [2, 4]  // Dashed line for future route
                } else {
                    renderer.strokeColor = NSColor.systemBlue
                    renderer.lineWidth = 3.0
                }

                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// @brief Render Annotation
        ///
        /// ## When Called
        /// - Executed whenever mapView.addAnnotation() is called
        /// - Returns View to draw Annotation on screen
        ///
        /// ## dequeueReusableAnnotationView
        /// ```swift
        /// var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        /// ```
        ///
        /// **What is dequeue?**
        /// - Retrieves reusable AnnotationView from queue
        /// - Same pattern as UITableView's dequeueReusableCell
        /// - Memory efficient (doesn't create new ones every time)
        ///
        /// **How it works:**
        /// ```
        /// 1. AnnotationView goes off screen → Added to queue
        /// 2. New Annotation needed → Retrieved from queue and reused
        /// 3. Queue is empty → Create new one
        /// ```
        ///
        /// ## Handle by Annotation Type
        ///
        /// ### Impact Marker
        /// ```swift
        /// if annotation.title == "Impact" {
        ///     let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", ...)
        ///     annotationView?.image = image?.withSymbolConfiguration(config)
        /// }
        /// ```
        ///
        /// **SF Symbols Configuration:**
        /// - systemSymbolName: SF Symbols name
        /// - NSImage.SymbolConfiguration: Size, weight settings
        /// - withSymbolConfiguration: Apply configuration
        ///
        /// ### Current Position
        /// ```swift
        /// else {
        ///     let image = NSImage(systemSymbolName: "location.circle.fill", ...)
        ///     annotationView?.image = image?.withSymbolConfiguration(config)
        /// }
        /// ```
        ///
        /// ## canShowCallout
        /// ```swift
        /// annotationView?.canShowCallout = true
        /// ```
        ///
        /// **What is a Callout?**
        /// - Popup that appears when marker is clicked
        /// - Displays title, subtitle
        /// - Provides additional information
        ///
        /// **Example:**
        /// ```
        /// 📍
        /// ┌─────────────────┐
        /// │ Current Position│  ← title
        /// │ 85.0 km/h       │  ← subtitle
        /// └─────────────────┘
        /// ```
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation.title == "Impact" {
                // Impact marker
                //
                // Impact event: ⚠️
                let identifier = "ImpactMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
                let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .bold)
                annotationView?.image = image?.withSymbolConfiguration(config)

                return annotationView
            } else {
                // Current position marker
                //
                // Current location: 📍
                let identifier = "CurrentPosition"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let image = NSImage(systemSymbolName: "location.circle.fill", accessibilityDescription: nil)
                let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .bold)
                annotationView?.image = image?.withSymbolConfiguration(config)

                return annotationView
            }
        }
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## Mock Data Setup
/// ```swift
/// let gpsService = GPSService()
/// let gsensorService = GSensorService()
/// let videoFile = VideoFile.allSamples.first!
///
/// gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// ```
///
/// **What is loadGPSData?**
/// - Extract GPS data from VideoMetadata
/// - Load into GPSService to create route
/// - startTime: Video start time (for timestamp calculation)
///
/// **What is loadAccelerationData?**
/// - Extract acceleration data from VideoMetadata
/// - Load into GSensorService to detect impact events
/// - startTime: Video start time (for timestamp calculation)
///
/// ## Black Background via ZStack
/// ```swift
/// ZStack {
///     Color.black
///     MapOverlayView(...)
/// }
/// ```
///
/// **Why use black background?**
/// - Simulate actual video screen
/// - Verify minimap displayed as overlay effect
/// - Test shadow effects
struct MapOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let gpsService = GPSService()
        let gsensorService = GSensorService()
        let videoFile = VideoFile.allSamples.first!

        // Load sample data
        gpsService.loadGPSData(from: videoFile.metadata, startTime: videoFile.timestamp)
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        return ZStack {
            Color.black

            MapOverlayView(
                gpsService: gpsService,
                gsensorService: gsensorService,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
