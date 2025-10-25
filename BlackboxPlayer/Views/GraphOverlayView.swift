/// @file GraphOverlayView.swift
/// @brief Graph overlay showing acceleration data
/// @author BlackboxPlayer Development Team
/// @details An overlay View that displays acceleration sensor data as a real-time graph.

import SwiftUI

/// # GraphOverlayView
///
/// An overlay View that displays acceleration sensor data as a real-time graph.
///
/// ## Screen Layout
/// ```
/// ┌─────────────────────────────────────────────────┐
/// │                                                  │
/// │                                                  │
/// │  ┌────────────────────────────────────────┐     │
/// │  │ 📊 G-Force         2.3G    X Y Z       │     │
/// │  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│     │
/// │  │        ╱╲              ⚠                │     │
/// │  │ ━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│     │
/// │  │       ╲ ╱                               │     │
/// │  │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│     │
/// │  └────────────────────────────────────────┘     │
/// │  ^X(red), Y(green), Z(blue) axes + impact markers^     │
/// └─────────────────────────────────────────────────┘
/// ```
///
/// ## Key Features
/// - **3-axis Graph**: X, Y, Z axis data displayed as red, green, and blue lines respectively
/// - **Time Window**: Shows only the most recent 10 seconds of data (sliding window)
/// - **Impact Events**: Background highlight + dashed marker at 4G+ impact points
/// - **Current Time**: Yellow dashed line showing current playback position
/// - **Grid**: Background grid for improved readability
///
/// ## Core SwiftUI Concepts
///
/// ### 1. Drawing Dynamic Graphs with GeometryReader
/// ```swift
/// GeometryReader { geometry in
///     Path { path in
///         let x = geometry.size.width * ratio
///         let y = geometry.size.height * (1 - ratio)
///         path.addLine(to: CGPoint(x: x, y: y))
///     }
/// }
/// ```
///
/// **What is GeometryReader?**
/// - Provides the size and position information of the parent View
/// - Enables child Views to dynamically calculate their size
/// - Essential for UI that changes based on screen size, like graphs
///
/// **Why is it needed?**
/// - Graphs don't have a fixed size
/// - Point positions must be calculated based on screen size
/// - Use geometry.size to calculate pixel coordinates
///
/// ### 2. Drawing Line Graphs with Path
/// ```swift
/// Path { path in
///     path.move(to: CGPoint(x: x1, y: y1))  // Starting point
///     path.addLine(to: CGPoint(x: x2, y: y2))  // Next point
///     path.addLine(to: CGPoint(x: x3, y: y3))  // Next point
/// }
/// .stroke(Color.red, lineWidth: 2)
/// ```
///
/// **What is Path?**
/// - A way to draw custom shapes in SwiftUI
/// - move(to:): Move the pen (without drawing)
/// - addLine(to:): Draw a line while moving
///
/// **Graph drawing process:**
/// 1. Move to the first data point
/// 2. Use addLine for the remaining points
/// 3. Draw the line with stroke
///
/// ### 3. Dynamic Property Access with KeyPath
/// ```swift
/// func linePath(for keyPath: KeyPath<AccelerationData, Double>, ...) {
///     let value = data[keyPath: keyPath]  // \.x, \.y, \.z
/// }
///
/// // Usage example:
/// linePath(for: \.x, color: .red)    // X-axis graph
/// linePath(for: \.y, color: .green)  // Y-axis graph
/// linePath(for: \.z, color: .blue)   // Z-axis graph
/// ```
///
/// **What is KeyPath?**
/// - A way to reference properties of a type
/// - `\.x` points to the x property of AccelerationData
/// - Enables dynamic property access
///
/// **Why use it?**
/// - Eliminates code duplication
/// - Handles X, Y, Z axis graphs with a single function
/// - Applies the same logic to different properties
///
/// ### 4. Time Window Pattern (Sliding Window)
/// ```swift
/// private let timeWindow: TimeInterval = 10.0
///
/// var visibleAccelerationData: [AccelerationData] {
///     let startTime = max(0, currentTime - timeWindow)
///     let endTime = currentTime
///     return gsensorService.getData(from: startTime, to: endTime)
/// }
/// ```
///
/// **What is Time Window?**
/// - Displays only data within a specific time range
/// - 10-second window: Most recent 10 seconds based on current time
/// - Sliding: Window moves as currentTime increases
///
/// **Visual representation:**
/// ```
/// Full data: [0s──────30s──────60s──────90s]
///
/// currentTime = 30s, timeWindow = 10s
/// visibleData: [20s──────30s]
///                ^startTime ^endTime
///
/// currentTime = 40s (1 second later)
/// visibleData:    [30s──────40s]
///                   ^window moves to the right
/// ```
///
/// ### 5. Coordinate Transformation (Data → Pixels)
/// ```swift
/// func xPosition(for time: TimeInterval, startTime: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
///     let relativeTime = time - startTime
///     let ratio = relativeTime / timeWindow
///     return CGFloat(ratio) * geometry.size.width
/// }
///
/// func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
///     let maxValue: Double = 3.0
///     let ratio = (value + maxValue) / (maxValue * 2)
///     return geometry.size.height * (1.0 - CGFloat(ratio))
/// }
/// ```
///
/// **X Coordinate Transformation (Time → Pixels):**
/// ```
/// timeWindow = 10s
/// geometry.size.width = 400px
///
/// time = 25s, startTime = 20s
/// relativeTime = 25 - 20 = 5s
/// ratio = 5 / 10 = 0.5 (50% position)
/// x = 0.5 * 400 = 200px (center)
/// ```
///
/// **Y Coordinate Transformation (Value → Pixels):**
/// ```
/// maxValue = 3.0 (±3G range)
/// geometry.size.height = 120px
///
/// value = 1.5G
/// ratio = (1.5 + 3) / 6 = 0.75
/// y = 120 * (1 - 0.75) = 30px (top)
///
/// value = 0G
/// ratio = (0 + 3) / 6 = 0.5
/// y = 120 * (1 - 0.5) = 60px (center)
///
/// value = -3G
/// ratio = (-3 + 3) / 6 = 0
/// y = 120 * (1 - 0) = 120px (bottom)
/// ```
///
/// ### 6. Drawing Dynamic Elements with ForEach
/// ```swift
/// ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
///     let y = yPosition(for: Double(value), in: geometry)
///     Path { path in
///         path.move(to: CGPoint(x: 0, y: y))
///         path.addLine(to: CGPoint(x: geometry.size.width, y: y))
///     }
///     .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
/// }
/// ```
///
/// **Using ForEach:**
/// - Creates a View for each element in the array
/// - Dynamically generates 5 grid lines (-2G, -1G, 0G, 1G, 2G)
/// - Uses the value itself as identifier with id: \.self
///
/// ## Usage Examples
///
/// ### Example 1: Usage in VideoPlayerView
/// ```swift
/// struct VideoPlayerView: View {
///     @StateObject private var gsensorService = GSensorService()
///     @State private var currentTime: TimeInterval = 0.0
///
///     var body: some View {
///         ZStack {
///             VideoFrameView(frame: currentFrame)
///
///             GraphOverlayView(
///                 gsensorService: gsensorService,
///                 currentTime: currentTime
///             )
///         }
///     }
/// }
/// ```
///
/// ### Example 2: Toggleable Graph
/// ```swift
/// @State private var showGraph = true
///
/// ZStack {
///     VideoFrameView(frame: currentFrame)
///
///     if showGraph {
///         GraphOverlayView(
///             gsensorService: gsensorService,
///             currentTime: currentTime
///         )
///         .transition(.move(edge: .bottom))
///     }
/// }
/// .toolbar {
///     Button("Toggle Graph") {
///         withAnimation {
///             showGraph.toggle()
///         }
///     }
/// }
/// ```
///
/// ## Practical Applications
///
/// ### Time Window Adjustment Feature
/// ```swift
/// @State private var timeWindow: TimeInterval = 10.0
///
/// VStack {
///     GraphOverlayView(
///         gsensorService: gsensorService,
///         currentTime: currentTime,
///         timeWindow: timeWindow
///     )
///
///     Picker("Time Window", selection: $timeWindow) {
///         Text("5s").tag(5.0)
///         Text("10s").tag(10.0)
///         Text("20s").tag(20.0)
///     }
/// }
/// ```
///
/// ### Axis Selection Feature (Individual X, Y, Z Display)
/// ```swift
/// @State private var showX = true
/// @State private var showY = true
/// @State private var showZ = true
///
/// if showX {
///     linePath(for: \.x, in: geometry, color: .red)
/// }
/// if showY {
///     linePath(for: \.y, in: geometry, color: .green)
/// }
/// if showZ {
///     linePath(for: \.z, in: geometry, color: .blue)
/// }
/// ```
///
/// ### Zoom Feature (Y-axis Range Adjustment)
/// ```swift
/// @State private var yAxisRange: Double = 3.0
///
/// func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
///     let ratio = (value + yAxisRange) / (yAxisRange * 2)
///     return geometry.size.height * (1.0 - CGFloat(ratio))
/// }
/// ```
///
/// ## Performance Optimization
///
/// ### 1. Data Sampling (Prevent Too Many Points)
/// ```swift
/// var visibleAccelerationData: [AccelerationData] {
///     let allData = gsensorService.getData(from: startTime, to: endTime)
///     // Limit to maximum 100 points
///     let stride = max(1, allData.count / 100)
///     return Array(allData.enumerated().filter { $0.offset % stride == 0 }.map { $0.element })
/// }
/// ```
///
/// ### 2. Metal Rendering with DrawingGroup
/// ```swift
/// ZStack {
///     // Graph elements
/// }
/// .drawingGroup()  // ✅ Render with Metal (performance boost)
/// ```
///
/// ### 3. Caching Unchanging Elements
/// ```swift
/// // Draw grid only once since it doesn't change
/// @State private var gridView: some View = gridLines()
///
/// ZStack {
///     gridView  // ✅ Cached grid
///     // Dynamic graphs
/// }
/// ```
///
/// @struct GraphOverlayView
/// @brief View that displays acceleration sensor data as a graph
struct GraphOverlayView: View {
    // MARK: - Properties

    /// @var gsensorService
    /// @brief G-Sensor service (@ObservedObject)
    ///
    /// **What is GSensorService?**
    /// - A service class that manages acceleration sensor data
    /// - Detects and manages impact events
    /// - Automatically updates View when @Published properties change
    ///
    /// **Key features:**
    /// - `hasData`: Whether acceleration data exists
    /// - `currentAcceleration`: Acceleration data at current time
    /// - `getData(from:to:)`: Get data within a specific time range
    /// - `getImpacts(from:to:minSeverity:)`: Get impact events
    @ObservedObject var gsensorService: GSensorService

    /// @var currentTime
    /// @brief Current playback time
    ///
    /// **Purpose:**
    /// - End point of time window (endTime = currentTime)
    /// - Position to display current time indicator
    /// - Calculate visible data range
    let currentTime: TimeInterval

    /// @var timeWindow
    /// @brief Time window (time range to display)
    ///
    /// **What is TimeInterval?**
    /// - A typealias for Double (in seconds)
    /// - 10.0 = 10 seconds
    ///
    /// **What is Time Window?**
    /// - The time range to display on the graph
    /// - 10 seconds: Display only the most recent 10 seconds of data
    /// - Sliding window: Moves together as currentTime increases
    ///
    /// **Example:**
    /// ```
    /// timeWindow = 10.0
    /// currentTime = 30.0
    /// → Display range: 20.0s ~ 30.0s
    ///
    /// currentTime = 35.0 (5 seconds later)
    /// → Display range: 25.0s ~ 35.0s
    /// ```
    private let timeWindow: TimeInterval = 10.0

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()

            HStack {
                // Display graph only when acceleration data is available
                //
                // gsensorService.hasData: Check if at least one acceleration data exists
                if gsensorService.hasData {
                    accelerationGraph
                        .frame(width: 400, height: 180)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                }

                Spacer()
            }
        }
    }

    // MARK: - Acceleration Graph

    /// @var accelerationGraph
    /// @brief Acceleration graph
    ///
    /// ## Structure
    /// ```
    /// ┌────────────────────────────────────────┐
    /// │ 📊 G-Force         2.3G    X Y Z       │  ← Header
    /// │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│  ← Grid
    /// │        ╱╲              ⚠                │  ← Graph
    /// │ ━━━━━━━  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│  ← 0G line
    /// │       ╲ ╱                               │  ← Graph
    /// │ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄│  ← Grid
    /// └────────────────────────────────────────┘
    /// ```
    ///
    /// ## Header Layout
    /// - **Left**: 📊 icon + "G-Force" label
    /// - **Center**: Current G-Force value + impact severity
    /// - **Right**: X, Y, Z axis legend (red, green, blue)
    ///
    /// ## EnhancedAccelerationGraphView
    /// ```swift
    /// EnhancedAccelerationGraphView(
    ///     accelerationData: visibleAccelerationData,
    ///     impactEvents: visibleImpactEvents,
    ///     currentTime: currentTime,
    ///     timeWindow: timeWindow
    /// )
    /// ```
    ///
    /// **Data passed:**
    /// - visibleAccelerationData: Acceleration data in visible range
    /// - visibleImpactEvents: Impact events in visible range
    /// - currentTime: Current playback time
    /// - timeWindow: Time window (10 seconds)
    private var accelerationGraph: some View {
        VStack(spacing: 8) {
            // Title and Current G-Force
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption)
                Text("G-Force")
                    .font(.caption)
                    .fontWeight(.medium)

                Spacer()

                // Current G-Force Display
                //
                // Display current time's G-Force magnitude and impact severity
                if let currentAccel = gsensorService.currentAcceleration {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(currentAccel.magnitudeString)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(gforceColor(for: currentAccel.magnitude))

                        // Display only during impact events
                        if currentAccel.isImpact {
                            Text(currentAccel.impactSeverity.displayName)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }

                // Legend
                //
                // Color guide for X, Y, Z axes
                HStack(spacing: 12) {
                    legendItem(color: .red, label: "X")
                    legendItem(color: .green, label: "Y")
                    legendItem(color: .blue, label: "Z")
                }
                .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal)
            .padding(.top, 8)

            // Graph
            //
            // View that actually draws the graph
            EnhancedAccelerationGraphView(
                accelerationData: visibleAccelerationData,
                impactEvents: visibleImpactEvents,
                currentTime: currentTime,
                timeWindow: timeWindow
            )
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    /// @brief Color based on G-Force magnitude
    ///
    /// ## Color Thresholds
    /// ```
    /// 0.0 ~ 1.5G  → Green (normal)
    /// 1.5 ~ 2.5G  → Yellow (warning)
    /// 2.5 ~ 4.0G  → Orange (caution)
    /// 4.0G+       → Red (danger)
    /// ```
    ///
    /// **Where it's used:**
    /// - Color for displaying current G-Force value
    ///
    /// **Same as gforceColor in MetadataOverlayView:**
    /// - Maintains consistent color scheme
    /// - Provides familiar visual feedback to users
    private func gforceColor(for magnitude: Double) -> Color {
        if magnitude > 4.0 {
            return .red
        } else if magnitude > 2.5 {
            return .orange
        } else if magnitude > 1.5 {
            return .yellow
        } else {
            return .green
        }
    }

    /// @brief Legend item
    ///
    /// ## Structure
    /// ```
    /// ● X
    /// ^  ^
    /// │  └─ Label (X, Y, Z)
    /// └──── Color circle (red, green, blue)
    /// ```
    ///
    /// **Circle().fill(color):**
    /// - Circle filled with color
    /// - .frame(width: 6, height: 6): Small dot
    ///
    /// **Usage example:**
    /// ```swift
    /// legendItem(color: .red, label: "X")   → ● X (red dot)
    /// legendItem(color: .green, label: "Y") → ● Y (green dot)
    /// legendItem(color: .blue, label: "Z")  → ● Z (blue dot)
    /// ```
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
    }

    // MARK: - Helper Methods

    /// @var visibleAccelerationData
    /// @brief Acceleration data in visible range
    ///
    /// ## Computed Property
    /// - Automatically recalculated when currentTime changes
    /// - Called every time View updates
    ///
    /// ## Time Range Calculation
    /// ```swift
    /// let startTime = max(0, currentTime - timeWindow)
    /// let endTime = currentTime
    /// ```
    ///
    /// **Why use max(0, ...)?**
    /// - Prevents negative values when currentTime is less than 10 seconds
    /// - Example: currentTime = 5s, timeWindow = 10s
    ///   → startTime = max(0, 5 - 10) = max(0, -5) = 0s
    ///
    /// **Example:**
    /// ```
    /// currentTime = 30s, timeWindow = 10s
    /// startTime = max(0, 30 - 10) = 20s
    /// endTime = 30s
    /// → Calls getData(from: 20, to: 30)
    /// → Returns data from 20s~30s
    /// ```
    ///
    /// ## getData(from:to:)
    /// - Method of GSensorService
    /// - Returns acceleration data in specific time range
    /// - Returns filtered + sorted array
    private var visibleAccelerationData: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime
        return gsensorService.getData(from: startTime, to: endTime)
    }

    /// @var visibleImpactEvents
    /// @brief Impact events in visible range
    ///
    /// ## Computed Property
    /// - Automatically recalculated when currentTime changes
    /// - Filters impact events only
    ///
    /// ## getImpacts(from:to:minSeverity:)
    /// ```swift
    /// gsensorService.getImpacts(from: startTime, to: endTime, minSeverity: .moderate)
    /// ```
    ///
    /// **What is minSeverity: .moderate?**
    /// - Filters by minimum impact severity
    /// - Shows only .moderate and above (moderate, high, severe)
    /// - Excludes .low (prevents too many markers)
    ///
    /// **ImpactSeverity levels:**
    /// ```
    /// .none     → No impact (<4G)
    /// .low      → Minor (4~6G) ← Excluded
    /// .moderate → Moderate (6~8G) ← Included
    /// .high     → High (8~10G) ← Included
    /// .severe   → Severe (10G+) ← Included
    /// ```
    ///
    /// **Why only .moderate and above?**
    /// - Prevents graph from becoming too complex
    /// - Emphasizes only important impacts
    /// - Reduces visual noise
    private var visibleImpactEvents: [AccelerationData] {
        let startTime = max(0, currentTime - timeWindow)
        let endTime = currentTime
        return gsensorService.getImpacts(from: startTime, to: endTime, minSeverity: .moderate)
    }
}

// MARK: - Enhanced Acceleration Graph View

/// # EnhancedAccelerationGraphView
///
/// A View that renders acceleration data as a graph.
///
/// ## Graph Elements
/// 1. **Background Grid**: Horizontal/vertical grid lines (0.1 opacity)
/// 2. **0G Line**: Center horizontal line (0.3 opacity)
/// 3. **Impact Background**: Semi-transparent background at impact points
/// 4. **X, Y, Z Axis Lines**: Red, green, and blue respectively
/// 5. **Impact Markers**: Dashed vertical lines
/// 6. **Current Time**: Yellow dashed line (right edge)
///
/// ## Drawing Graphs with Path
/// ```swift
/// Path { path in
///     path.move(to: CGPoint(x: x1, y: y1))
///     path.addLine(to: CGPoint(x: x2, y: y2))
///     path.addLine(to: CGPoint(x: x3, y: y3))
/// }
/// .stroke(Color.red, lineWidth: 2)
/// ```
///
/// **How it works:**
/// 1. move(to:): Move to starting point (without drawing)
/// 2. addLine(to:): Draw line from current position to new position
/// 3. stroke: Specify line color and thickness
///
/// @struct EnhancedAccelerationGraphView
/// @brief View for rendering acceleration data graph
struct EnhancedAccelerationGraphView: View {
    // MARK: - Properties

    /// @var accelerationData
    /// @brief Array of acceleration data
    ///
    /// **Data in visible range:**
    /// - Passed from visibleAccelerationData
    /// - Most recent 10 seconds (timeWindow) range
    /// - Sorted chronologically
    let accelerationData: [AccelerationData]

    /// @var impactEvents
    /// @brief Array of impact events
    ///
    /// **Filtered impacts only:**
    /// - Passed from visibleImpactEvents
    /// - Contains only .moderate and above impacts
    /// - Displayed as background highlight + dashed marker
    let impactEvents: [AccelerationData]

    /// @var currentTime
    /// @brief Current playback time
    ///
    /// **Purpose:**
    /// - Calculate current time indicator position
    /// - Reference point for X coordinate transformation
    let currentTime: TimeInterval

    /// @var timeWindow
    /// @brief Time window
    ///
    /// **Purpose:**
    /// - Used in X coordinate transformation
    /// - Calculate time → pixel ratio
    let timeWindow: TimeInterval

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                //
                // Background grid lines (horizontal/vertical)
                gridLines(in: geometry)

                // Zero line
                //
                // 0G baseline (center horizontal line)
                Path { path in
                    let y = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1)

                // Impact event background highlights
                //
                // Impact event background highlights
                impactHighlights(in: geometry)

                // X axis line (red)
                linePath(for: \.x, in: geometry, color: .red)

                // Y axis line (green)
                linePath(for: \.y, in: geometry, color: .green)

                // Z axis line (blue)
                linePath(for: \.z, in: geometry, color: .blue)

                // Impact markers
                //
                // Impact event dashed markers
                impactMarkers(in: geometry)

                // Current time indicator
                //
                // Current time indicator (yellow dashed line)
                currentTimeIndicator(in: geometry)
            }
        }
        .frame(height: 120)
    }

    // MARK: - Grid Lines

    /// @brief Background grid lines
    ///
    /// ## Horizontal Grid Lines
    /// ```swift
    /// ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
    ///     let y = yPosition(for: Double(value), in: geometry)
    ///     // Draw horizontal line
    /// }
    /// ```
    ///
    /// **Lines drawn:**
    /// - -2G position (top)
    /// - -1G position
    /// - 0G position (center)
    /// - 1G position
    /// - 2G position (bottom)
    ///
    /// ## Vertical Grid Lines
    /// ```swift
    /// ForEach(0..<Int(timeWindow / 2), id: \.self) { index in
    ///     let x = CGFloat(index) * (geometry.size.width / CGFloat(timeWindow / 2))
    ///     // Draw vertical line
    /// }
    /// ```
    ///
    /// **Lines drawn:**
    /// - timeWindow = 10s
    /// - Draw line every 2 seconds
    /// - At 0s, 2s, 4s, 6s, 8s positions
    ///
    /// **Calculation:**
    /// ```
    /// timeWindow = 10s
    /// timeWindow / 2 = Divide into 5s intervals
    /// geometry.size.width = 400px
    ///
    /// index = 0: x = 0 * (400 / 5) = 0px
    /// index = 1: x = 1 * (400 / 5) = 80px
    /// index = 2: x = 2 * (400 / 5) = 160px
    /// ...
    /// ```
    ///
    /// ## opacity(0.1)
    /// - Very transparent white
    /// - Serves as background (not distracting)
    /// - Improves graph readability
    private func gridLines(in geometry: GeometryProxy) -> some View {
        let gridColor = Color.white.opacity(0.1)

        return ZStack {
            // Horizontal grid lines
            //
            // Horizontal grid lines (-2G, -1G, 0G, 1G, 2G)
            ForEach([-2, -1, 0, 1, 2], id: \.self) { value in
                let y = yPosition(for: Double(value), in: geometry)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }

            // Vertical grid lines (every 2 seconds)
            //
            // Vertical grid lines (every 2 seconds)
            ForEach(0..<Int(timeWindow / 2), id: \.self) { index in
                let x = CGFloat(index) * (geometry.size.width / CGFloat(timeWindow / 2))
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(gridColor, lineWidth: 0.5)
            }
        }
    }

    // MARK: - Line Path

    /// @brief Line graph path
    ///
    /// ## Dynamic Property Access with KeyPath
    /// ```swift
    /// func linePath(for keyPath: KeyPath<AccelerationData, Double>, ...)
    /// ```
    ///
    /// **What is KeyPath?**
    /// - A way to reference properties of a type
    /// - Specify each axis with `\.x`, `\.y`, `\.z`
    /// - Access values with data[keyPath: keyPath]
    ///
    /// **Usage example:**
    /// ```swift
    /// linePath(for: \.x, color: .red)    // X-axis graph
    /// linePath(for: \.y, color: .green)  // Y-axis graph
    /// linePath(for: \.z, color: .blue)   // Z-axis graph
    /// ```
    ///
    /// ## Graph Drawing Process
    /// ```swift
    /// for (index, data) in accelerationData.enumerated() {
    ///     let x = xPosition(for: dataTime, startTime: startTime, in: geometry)
    ///     let y = yPosition(for: data[keyPath: keyPath], in: geometry)
    ///
    ///     if index == 0 {
    ///         path.move(to: point)  // First point: move only
    ///     } else {
    ///         path.addLine(to: point)  // Subsequent: draw line
    ///     }
    /// }
    /// ```
    ///
    /// **Why use move when index == 0?**
    /// - First point is just a starting point
    /// - Can't draw a line without a previous point
    /// - Position pen with move, then start addLine
    ///
    /// ## Time Calculation
    /// ```swift
    /// let dataTime = data.timestamp.timeIntervalSince1970
    ///                - accelerationData.first!.timestamp.timeIntervalSince1970
    ///                + startTime
    /// ```
    ///
    /// **Why calculate this way?**
    /// - data.timestamp: Absolute time (since January 1, 1970)
    /// - Need to convert to relative time (based on first data)
    /// - Add startTime to calculate position within window
    ///
    /// **Example:**
    /// ```
    /// first.timestamp: 2024-01-15 14:23:20 (1705303400s)
    /// data.timestamp:  2024-01-15 14:23:25 (1705303405s)
    /// startTime: 20s
    ///
    /// Relative time = 1705303405 - 1705303400 = 5s
    /// dataTime = 5 + 20 = 25s
    /// ```
    private func linePath(for keyPath: KeyPath<AccelerationData, Double>, in geometry: GeometryProxy, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let startTime = currentTime - timeWindow

            for (index, data) in accelerationData.enumerated() {
                let dataTime = data.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
                let x = xPosition(for: dataTime, startTime: startTime, in: geometry)
                let y = yPosition(for: data[keyPath: keyPath], in: geometry)

                let point = CGPoint(x: x, y: y)

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    // MARK: - Current Time Indicator

    /// @brief Current time indicator
    ///
    /// ## Yellow Dashed Line
    /// ```swift
    /// Path { path in
    ///     let x = geometry.size.width  // Right edge
    ///     path.move(to: CGPoint(x: x, y: 0))
    ///     path.addLine(to: CGPoint(x: x, y: geometry.size.height))
    /// }
    /// .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    /// ```
    ///
    /// **Why the right edge?**
    /// - Graph flows past → present (left → right)
    /// - Current time is always at the right edge
    /// - x = geometry.size.width (maximum X coordinate)
    ///
    /// ## StrokeStyle(dash:)
    /// ```swift
    /// dash: [5, 3]
    /// ```
    ///
    /// **Dash pattern:**
    /// - [5, 3]: 5px line → 3px gap → repeat
    /// - [10, 5]: 10px line → 5px gap → repeat
    ///
    /// **Visual effect:**
    /// ```
    /// [5, 3]: ━━━━━   ━━━━━   ━━━━━
    /// ```
    private func currentTimeIndicator(in geometry: GeometryProxy) -> some View {
        Path { path in
            let x = geometry.size.width
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
        }
        .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
    }

    // MARK: - Impact Highlights

    /// @brief Impact event background highlights
    ///
    /// ## Process Each Impact Event with ForEach
    /// ```swift
    /// ForEach(impactEvents, id: \.timestamp) { impact in
    ///     // Semi-transparent background rectangle at impact position
    /// }
    /// ```
    ///
    /// **id: \.timestamp:**
    /// - Distinguish each impact by timestamp
    /// - Same timestamp = same event
    ///
    /// ## Rectangle Placement
    /// ```swift
    /// Rectangle()
    ///     .fill(impactColor(for: impact).opacity(0.2))
    ///     .frame(width: 20)
    ///     .position(x: x, y: geometry.size.height / 2)
    /// ```
    ///
    /// **.fill(color.opacity(0.2)):**
    /// - Color based on impact severity
    /// - 20% opacity (serves as background)
    ///
    /// **.frame(width: 20):**
    /// - 20px wide vertical band
    /// - Emphasizes impact point
    ///
    /// **.position(x:y:):**
    /// - x: X coordinate of impact time
    /// - y: Graph center (height / 2)
    private func impactHighlights(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Rectangle()
                .fill(impactColor(for: impact).opacity(0.2))
                .frame(width: 20)
                .position(x: x, y: geometry.size.height / 2)
        }
    }

    /// @brief Impact event markers (dashed lines)
    ///
    /// ## Process Each Impact Event with ForEach
    /// ```swift
    /// ForEach(impactEvents, id: \.timestamp) { impact in
    ///     // Dashed vertical line at impact position
    /// }
    /// ```
    ///
    /// ## Draw Vertical Line with Path
    /// ```swift
    /// Path { path in
    ///     path.move(to: CGPoint(x: x, y: 0))  // Top
    ///     path.addLine(to: CGPoint(x: x, y: geometry.size.height))  // Bottom
    /// }
    /// .stroke(impactColor(for: impact), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
    /// ```
    ///
    /// **StrokeStyle(dash: [3, 2]):**
    /// - 3px line → 2px gap → repeat
    /// - Short dashes (emphasize impact point)
    ///
    /// **impactColor(for:):**
    /// - .severe: Red
    /// - .high: Orange
    /// - .moderate: Yellow
    private func impactMarkers(in geometry: GeometryProxy) -> some View {
        ForEach(impactEvents, id: \.timestamp) { impact in
            let startTime = currentTime - timeWindow
            let impactTime = impact.timestamp.timeIntervalSince1970 - accelerationData.first!.timestamp.timeIntervalSince1970 + startTime
            let x = xPosition(for: impactTime, startTime: startTime, in: geometry)

            Path { path in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geometry.size.height))
            }
            .stroke(impactColor(for: impact), style: StrokeStyle(lineWidth: 2, dash: [3, 2]))
        }
    }

    /// @brief Color based on impact severity
    ///
    /// ## Colors by ImpactSeverity
    /// ```
    /// .severe   → Red (10G+)
    /// .high     → Orange (8~10G)
    /// .moderate → Yellow (6~8G)
    /// .low      → Cyan (4~6G)
    /// .none     → White (<4G)
    /// ```
    ///
    /// **Where it's used:**
    /// - Impact background highlight
    /// - Impact marker dashed lines
    ///
    /// **Consistency:**
    /// - Impact severity colors are the same throughout the app
    /// - Same scheme in both MetadataOverlayView and GraphOverlayView
    private func impactColor(for impact: AccelerationData) -> Color {
        switch impact.impactSeverity {
        case .severe:
            return .red
        case .high:
            return .orange
        case .moderate:
            return .yellow
        case .low:
            return .cyan
        case .none:
            return .white
        }
    }

    // MARK: - Position Calculations

    /// @brief Calculate X coordinate (time → pixels)
    ///
    /// ## Transformation Formula
    /// ```swift
    /// let relativeTime = time - startTime
    /// let ratio = relativeTime / timeWindow
    /// return CGFloat(ratio) * geometry.size.width
    /// ```
    ///
    /// **Step-by-step calculation:**
    /// 1. **Calculate relative time**: time - startTime
    ///    - Relative position based on window start
    /// 2. **Calculate ratio**: relativeTime / timeWindow
    ///    - Normalize to 0.0 ~ 1.0 range
    /// 3. **Convert to pixels**: ratio * width
    ///    - Pixel coordinates in 0 ~ width range
    ///
    /// **Calculation examples:**
    /// ```
    /// timeWindow = 10s
    /// geometry.size.width = 400px
    /// startTime = 20s
    ///
    /// time = 25s
    /// relativeTime = 25 - 20 = 5s
    /// ratio = 5 / 10 = 0.5 (50% position)
    /// x = 0.5 * 400 = 200px (center)
    ///
    /// time = 20s (start)
    /// relativeTime = 20 - 20 = 0s
    /// ratio = 0 / 10 = 0.0
    /// x = 0.0 * 400 = 0px (left edge)
    ///
    /// time = 30s (end)
    /// relativeTime = 30 - 20 = 10s
    /// ratio = 10 / 10 = 1.0
    /// x = 1.0 * 400 = 400px (right edge)
    /// ```
    private func xPosition(for time: TimeInterval, startTime: TimeInterval, in geometry: GeometryProxy) -> CGFloat {
        let relativeTime = time - startTime
        let ratio = relativeTime / timeWindow
        return CGFloat(ratio) * geometry.size.width
    }

    /// @brief Calculate Y coordinate (value → pixels)
    ///
    /// ## Transformation Formula
    /// ```swift
    /// let maxValue: Double = 3.0
    /// let ratio = (value + maxValue) / (maxValue * 2)
    /// return geometry.size.height * (1.0 - CGFloat(ratio))
    /// ```
    ///
    /// **Step-by-step calculation:**
    /// 1. **Range shift**: value + maxValue
    ///    - Shift -3 ~ 3 → 0 ~ 6
    /// 2. **Calculate ratio**: (value + maxValue) / (maxValue * 2)
    ///    - Normalize 0 ~ 6 → 0.0 ~ 1.0
    /// 3. **Convert to pixels**: height * (1 - ratio)
    ///    - Y-axis: top is 0, bottom is height
    ///    - Invert with 1 - ratio (larger values toward top)
    ///
    /// **Calculation examples:**
    /// ```
    /// maxValue = 3.0
    /// geometry.size.height = 120px
    ///
    /// value = 3G (maximum)
    /// ratio = (3 + 3) / 6 = 1.0
    /// y = 120 * (1 - 1.0) = 0px (very top)
    ///
    /// value = 0G (center)
    /// ratio = (0 + 3) / 6 = 0.5
    /// y = 120 * (1 - 0.5) = 60px (center)
    ///
    /// value = -3G (minimum)
    /// ratio = (-3 + 3) / 6 = 0.0
    /// y = 120 * (1 - 0.0) = 120px (very bottom)
    /// ```
    ///
    /// **Why use 1 - ratio?**
    /// - SwiftUI Y-axis: top is 0, bottom is positive
    /// - Acceleration values: top is positive, bottom is negative
    /// - Invert with 1 - ratio for intuitive display
    ///
    /// ## ±3G Range
    /// ```
    /// maxValue = 3.0
    /// ```
    ///
    /// **Why 3G?**
    /// - Normal driving: within ±1G
    /// - Hard acceleration/braking: ±2G
    /// - Accidents: ±3G or more
    /// - ±3G range covers most situations
    private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        // Map value range [-3, 3] to geometry height
        let maxValue: Double = 3.0
        let ratio = (value + maxValue) / (maxValue * 2)
        return geometry.size.height * (1.0 - CGFloat(ratio))
    }
}

// MARK: - Preview

/// @brief Preview Provider
///
/// ## Mock Data Setup
/// ```swift
/// let gsensorService = GSensorService()
/// let videoFile = VideoFile.allSamples.first!
///
/// gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)
/// ```
///
/// **What is loadAccelerationData?**
/// - Extracts acceleration data from VideoMetadata
/// - Loads into GSensorService to prepare graph data
/// - startTime: Video start time (for timestamp calculations)
///
/// ## Black Background with ZStack
/// ```swift
/// ZStack {
///     Color.black
///     GraphOverlayView(...)
/// }
/// ```
///
/// **Why use black background?**
/// - Simulates actual video screen
/// - Verifies overlay display effect of graph
/// - Tests graph line color contrast
///
/// ## currentTime: 10.0
/// - 10 seconds after video start
/// - Displays graph in 0~10 second range
/// - Change value to test different time periods
struct GraphOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        let gsensorService = GSensorService()
        let videoFile = VideoFile.allSamples.first!

        // Load sample data
        gsensorService.loadAccelerationData(from: videoFile.metadata, startTime: videoFile.timestamp)

        return ZStack {
            Color.black

            GraphOverlayView(
                gsensorService: gsensorService,
                currentTime: 10.0
            )
        }
        .frame(width: 800, height: 600)
    }
}
