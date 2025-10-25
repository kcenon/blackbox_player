/// @file CameraPosition.swift
/// @brief Blackbox camera position/channel identification enum
/// @author BlackboxPlayer Development Team
///
/// Enum for camera position/channel identification

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                    CameraPosition Enum Overview                          │
 │                                                                          │
 │  Identifies camera position/channel in multi-camera blackbox system.    │
 │                                                                          │
 │  【Camera Positions】                                                    │
 │                                                                          │
 │  1. front (Front Camera)                                                 │
 │     - Code: F                                                            │
 │     - Index: 0                                                           │
 │     - Priority: 1 (Highest display priority)                             │
 │                                                                          │
 │  2. rear (Rear Camera)                                                   │
 │     - Code: R                                                            │
 │     - Index: 1                                                           │
 │     - Priority: 2                                                        │
 │                                                                          │
 │  3. left (Left Camera)                                                   │
 │     - Code: L                                                            │
 │     - Index: 2                                                           │
 │     - Priority: 3                                                        │
 │                                                                          │
 │  4. right (Right Camera)                                                 │
 │     - Code: Ri                                                           │
 │     - Index: 3                                                           │
 │     - Priority: 4                                                        │
 │                                                                          │
 │  5. interior (Interior Camera)                                           │
 │     - Code: I                                                            │
 │     - Index: 4                                                           │
 │     - Priority: 5                                                        │
 │                                                                          │
 │  6. unknown (Unknown)                                                    │
 │     - Code: U                                                            │
 │     - Index: -1 (Invalid)                                                │
 │     - Priority: 99 (Lowest)                                              │
 │                                                                          │
 │  【Multi-Camera System Layout】                                          │
 │                                                                          │
 │                    L (Left)                                              │
 │                      │                                                   │
 │             ┌────────┼────────┐                                          │
 │             │                 │                                          │
 │             │    F (Front)    │                                          │
 │             │        ▲        │                                          │
 │             │        │        │                                          │
 │             │  I (Interior)   │                                          │
 │             │        │        │                                          │
 │             │        ▼        │                                          │
 │             │    R (Rear)     │                                          │
 │             │                 │                                          │
 │             └────────┼────────┘                                          │
 │                      │                                                   │
 │                 Ri (Right)                                               │
 │                                                                          │
 │  【Filename Patterns】                                                   │
 │                                                                          │
 │  Automatically detects camera position from blackbox filename.           │
 │                                                                          │
 │  Format: YYYY_MM_DD_HH_MM_SS_[Position].mp4                              │
 │                                                                          │
 │  Examples:                                                               │
 │  - 2025_01_10_09_00_00_F.mp4  → .front                                  │
 │  - 2025_01_10_09_00_00_R.mp4  → .rear                                   │
 │  - 2025_01_10_09_00_00_L.mp4  → .left                                   │
 │  - 2025_01_10_09_00_00_Ri.mp4 → .right                                  │
 │  - 2025_01_10_09_00_00_I.mp4  → .interior                               │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【What is a Multi-Camera Blackbox?】

 A blackbox system that uses multiple cameras simultaneously.

 Common configurations:
 - 2-channel: Front + Rear
 - 3-channel: Front + Rear + Interior
 - 4-channel: Front + Rear + Left + Right
 - 5-channel: Front + Rear + Left + Right + Interior

 Role of each camera:
 - Front: Main camera, records front accidents
 - Rear: Records rear-end collisions
 - Left/Right: Records side contact accidents
 - Interior: Driver view, for taxi/rideshare

 File synchronization:
 - All cameras record simultaneously
 - Files created with same timestamp
 - Example:
 2025_01_10_09_00_00_F.mp4  (Front)
 2025_01_10_09_00_00_R.mp4  (Rear)
 → Front/rear footage from same time

 【Raw Value Codes】

 Each camera position is represented with a short code.

 Code selection rationale:
 - F (Front): First letter of Front
 - R (Rear): First letter of Rear
 - L (Left): First letter of Left
 - Ri (Right): Uses 'Ri' because 'R' conflicts with Rear
 - I (Interior): First letter of Interior
 - U (Unknown): Unknown

 Usage in filenames:
 - Concise filenames with short codes
 - 2025_01_10_09_00_00_F.mp4 (Short)
 - vs 2025_01_10_09_00_00_Front.mp4 (Long)

 【What is Channel Index?】

 Manages each camera with an array index.

 Array structure:
 ```swift
 channels: [ChannelInfo]
 // [0]: Front
 // [1]: Rear
 // [2]: Left
 // [3]: Right
 // [4]: Interior
 ```

 Usage example:
 ```swift
 let frontChannel = channels[0]  // Front camera
 let rearChannel = channels[1]   // Rear camera

 // Or
 let frontIndex = CameraPosition.front.channelIndex  // 0
 let frontChannel = channels[frontIndex]
 ```

 Why is array index needed?
 - Manages multiple channels as array
 - Fast access (O(1))
 - Easy iteration
 */

import Foundation

/*
 【CameraPosition Enumeration】

 Identifies camera position/channel in multi-camera blackbox system.

 Protocols:
 - String: Uses camera code as Raw Value (F, R, L, Ri, I, U)
 - Codable: JSON serialization/deserialization
 - CaseIterable: Provides allCases array
 - Comparable: Sorting based on display priority

 Usage examples:
 ```swift
 // 1. Auto-detect from filename
 let filename = "2025_01_10_09_00_00_F.mp4"
 let position = CameraPosition.detect(from: filename)  // .front

 // 2. UI display
 let displayName = position.displayName  // "Front"
 let shortName = position.shortName  // "F"
 let fullName = position.fullName  // "Front Camera"

 // 3. Array indexing
 let index = position.channelIndex  // 0
 let channel = channels[index]

 // 4. Sorting (display priority)
 let positions = [CameraPosition.rear, .front, .interior]
 let sorted = positions.sorted()  // [.front, .rear, .interior]
 ```
 */
/// @enum CameraPosition
/// @brief Camera position/channel in multi-camera blackbox system
///
/// Camera position/channel in a multi-camera dashcam system
enum CameraPosition: String, Codable, CaseIterable {
    /*
     【front - Front Camera】

     Main camera that records the front of the vehicle.

     Characteristics:
     - Default camera of blackbox
     - Most important footage (most accidents are frontal)
     - High resolution (Full HD or higher)
     - Wide field of view (120-140 degrees)

     Filename code: F
     - Example: 2025_01_10_09_00_00_F.mp4

     Channel index: 0
     - channels[0] = Front camera

     Display priority: 1 (Highest)
     - Displayed first in UI
     - Assigned large screen in multi-view

     Usage:
     - Front collision accidents
     - Traffic signal violations
     - Lane departure
     - Pedestrian accidents
     */
    /// @brief Front camera (main camera)
    ///
    /// Front-facing camera (main camera)
    case front = "F"

    /*
     【rear - Rear Camera】

     Camera that records the rear of the vehicle.

     Characteristics:
     - Standard configuration for 2-channel blackbox
     - Protection against rear-end collisions
     - Useful when parking
     - Lower resolution than front (HD)

     Filename code: R
     - Example: 2025_01_10_09_00_00_R.mp4

     Channel index: 1
     - channels[1] = Rear camera

     Display priority: 2
     - Second most important after front
     - Second screen in multi-view

     Usage:
     - Rear-end collision accidents
     - Parking lot contact accidents
     - Wrong-way vehicles
     - Reversing accidents
     */
    /// @brief Rear camera
    ///
    /// Rear-facing camera
    case rear = "R"

    /*
     【left - Left Camera】

     Camera that records the left side of the vehicle.

     Characteristics:
     - Included in 3-4 channel blackbox
     - Covers left blind spot
     - Protection against lane change accidents
     - Usually mounted near side mirror

     Filename code: L
     - Example: 2025_01_10_09_00_00_L.mp4

     Channel index: 2
     - channels[2] = Left camera

     Display priority: 3
     - After front and rear
     - Optional display

     Usage:
     - Left side contact accidents
     - Lane change accidents
     - Blind spot monitoring
     - Collisions with adjacent vehicles
     */
    /// @brief Left camera
    ///
    /// Left side camera
    case left = "L"

    /*
     【right - Right Camera】

     Camera that records the right side of the vehicle.

     Characteristics:
     - Included in 4-channel blackbox
     - Covers right blind spot
     - Monitors opposite side from driver's seat
     - Usually mounted near side mirror

     Filename code: Ri (R conflicts with Rear)
     - Example: 2025_01_10_09_00_00_Ri.mp4

     Channel index: 3
     - channels[3] = Right camera

     Display priority: 4
     - After left
     - Optional display

     Usage:
     - Right side contact accidents
     - Right turn accidents
     - Blind spot monitoring
     - Pedestrian accidents (right side)

     Why "Ri"?:
     - "R" is already used for Rear
     - Uses first two letters of "Right"
     - Unique code to prevent conflicts
     */
    /// @brief Right camera
    ///
    /// Right side camera
    case right = "Ri"

    /*
     【interior - Interior Camera】

     Camera that records vehicle interior (driver's seat).

     Characteristics:
     - Records driver's face
     - Night recording capability (IR LED)
     - Potential privacy issues
     - Essential for taxi/commercial vehicles

     Filename code: I
     - Example: 2025_01_10_09_00_00_I.mp4

     Channel index: 4
     - channels[4] = Interior camera

     Display priority: 5 (Lowest)
     - Optional display
     - Privacy considerations

     Usage:
     - Driver condition monitoring
     - Drowsy driving detection
     - Rideshare services
     - Taxi driver protection
     - Dispute resolution

     Privacy:
     - Optional in private vehicles
     - Consent required in some countries
     - Interior recording warning display
     */
    /// @brief Interior camera (cabin view)
    ///
    /// Interior camera (cabin view)
    case interior = "I"

    /*
     【unknown - Unknown Position】

     Used when camera position cannot be determined from filename.

     Causes:
     - Non-standard filename
     - Corrupted filename
     - Unknown blackbox model
     - User-defined filename

     Filename code: U
     - Example: 2025_01_10_09_00_00_U.mp4

     Channel index: -1 (Invalid)
     - Cannot be used for array indexing
     - Requires separate handling

     Display priority: 99 (Lowest)
     - Displayed at bottom when sorted
     - Manual classification needed

     Handling method:
     ```swift
     if position == .unknown {
     // Request camera position selection from user
     showCameraPositionSelector()
     }
     ```
     */
    /// @brief Unknown position
    ///
    /// Unknown or unrecognized position
    case unknown = "U"

    // MARK: - Display Properties

    /*
     【Display Name】

     Returns a simple name for display in UI.

     Return value:
     - String: English name of camera position

     Usage examples:
     ```swift
     let position = CameraPosition.front
     let name = position.displayName  // "Front"

     // UI label
     cameraLabel.stringValue = position.displayName

     // Tab title
     TabView {
     VideoView()
     .tabItem { Text(position.displayName) }
     }

     // List item
     List(positions) { position in
     Text(position.displayName)
     }
     ```

     Short format:
     - "Front", "Rear", "Left", "Right"
     - Suitable for space-constrained UI
     - Displayed with icons
     */
    /// @brief Human-readable display name
    /// @return English name of camera position
    ///
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .front:
            return "Front"  // Front
        case .rear:
            return "Rear"  // Rear
        case .left:
            return "Left"  // Left
        case .right:
            return "Right"  // Right
        case .interior:
            return "Interior"  // Interior
        case .unknown:
            return "Unknown"  // Unknown
        }
    }

    /*
     【Short Name】

     Returns the shortest format name (same as rawValue).

     Return value:
     - String: Camera code (F, R, L, Ri, I, U)

     Usage examples:
     ```swift
     let position = CameraPosition.front
     let short = position.shortName  // "F"

     // Icon overlay
     Text(position.shortName)
     .font(.caption)
     .foregroundColor(.white)
     .padding(4)
     .background(Color.blue)

     // Small badge
     Circle()
     .fill(Color.blue)
     .overlay(Text(position.shortName))
     .frame(width: 30, height: 30)

     // Filename generation
     let filename = "\(timestamp)_\(position.shortName).mp4"
     // "2025_01_10_09_00_00_F.mp4"
     ```

     When to use?:
     - When space is very limited
     - Icon labels
     - Filename generation
     - Log output
     */
    /// @brief Short name for UI display
    /// @return Camera code (F, R, L, Ri, I, U)
    ///
    /// Short name for UI display
    var shortName: String {
        return rawValue  // F, R, L, Ri, I, U
    }

    /*
     【Full Name】

     Returns the most detailed format name.

     Return value:
     - String: Full name including "Camera"

     Usage examples:
     ```swift
     let position = CameraPosition.front
     let full = position.fullName  // "Front Camera"

     // Detailed information display
     detailLabel.stringValue = position.fullName

     // Settings screen
     Picker(position.fullName, selection: $selectedPosition) {
     ForEach(CameraPosition.allCases, id: \.self) { pos in
     Text(pos.fullName).tag(pos)
     }
     }

     // Tooltip
     Button(action: {}) {
     Image(systemName: "video")
     }
     .help(position.fullName)  // Display "Front Camera" tooltip
     ```

     Comparison:
     - shortName: "F" (Shortest)
     - displayName: "Front" (Medium)
     - fullName: "Front Camera" (Longest and clearest)
     */
    /// @brief Full descriptive name
    /// @return Full name including "Camera"
    ///
    /// Full descriptive name
    var fullName: String {
        switch self {
        case .front:
            return "Front Camera"  // Front camera
        case .rear:
            return "Rear Camera"  // Rear camera
        case .left:
            return "Left Side Camera"  // Left camera
        case .right:
            return "Right Side Camera"  // Right camera
        case .interior:
            return "Interior Camera"  // Interior camera
        case .unknown:
            return "Unknown Camera"  // Unknown camera
        }
    }

    /*
     【Channel Index】

     Returns 0-based index for array indexing.

     Return value:
     - Int: 0-4 (valid), -1 (unknown)

     Channel array structure:
     ```swift
     channels: [ChannelInfo]
     // index 0: Front
     // index 1: Rear
     // index 2: Left
     // index 3: Right
     // index 4: Interior
     ```

     Usage examples:
     ```swift
     // 1. Access specific channel
     let frontIndex = CameraPosition.front.channelIndex  // 0
     let frontChannel = videoFile.channels[frontIndex]

     // 2. Safe access (check unknown)
     if position.channelIndex >= 0 && position.channelIndex < channels.count {
     let channel = channels[position.channelIndex]
     } else {
     print("⚠️ Invalid channel index")
     }

     // 3. Channel iteration
     for position in CameraPosition.allCases {
     guard position != .unknown else { continue }
     let index = position.channelIndex
     if index < channels.count {
     let channel = channels[index]
     print("\(position.displayName): \(channel.filePath)")
     }
     }

     // 4. Find Position by index
     if let position = CameraPosition.from(channelIndex: 1) {
     print(position.displayName)  // "Rear"
     }
     ```

     Why -1? (unknown):
     - Indicates invalid index
     - Prevents array access
     - Easy error checking
     */
    /// @brief Channel index (0-based) for array indexing
    /// @return 0-4 (valid), -1 (unknown)
    ///
    /// Channel index (0-based) for array indexing
    var channelIndex: Int {
        switch self {
        case .front:
            return 0  // Front camera
        case .rear:
            return 1  // Rear camera
        case .left:
            return 2  // Left camera
        case .right:
            return 3  // Right camera
        case .interior:
            return 4  // Interior camera
        case .unknown:
            return -1  // Invalid
        }
    }

    /*
     【Display Priority】

     Priority indicating the order in which cameras are displayed in UI.

     Range: 1-99
     - 1: front (Highest)
     - 2: rear
     - 3: left
     - 4: right
     - 5: interior
     - 99: unknown (Lowest)

     Usage purposes:
     1. Multi-view layout: Important cameras get larger screen
     2. Tab order: Starting from front
     3. Auto-sorting: Based on priority
     4. Default display: Only high priority ones

     Usage examples:
     ```swift
     // 1. Sort (by priority)
     let positions = [CameraPosition.interior, .front, .rear]
     let sorted = positions.sorted()  // [.front, .rear, .interior]

     // 2. Multi-view layout
     let mainCamera = positions.min()  // .front (priority 1)
     let subCameras = positions.filter { $0 != mainCamera }

     // 3. Tab order
     TabView {
     ForEach(CameraPosition.allCases.sorted(), id: \.self) { position in
     VideoView(position: position)
     .tabItem { Text(position.displayName) }
     }
     }

     // 4. Priority filtering (main cameras only)
     let mainCameras = positions.filter { $0.displayPriority <= 2 }
     // [.front, .rear]
     ```

     Why this order?:
     - Front (1): Most important, most accidents are frontal
     - Rear (2): Rear-end collision protection, second most important
     - Left/Right (3-4): Optional, blind spots
     - Interior (5): Privacy, optional
     - Unknown (99): Needs classification
     */
    /// @brief Display order priority
    /// @return 1-99 (1: Highest, 99: Lowest)
    ///
    /// Priority for display ordering
    var displayPriority: Int {
        switch self {
        case .front:
            return 1  // Highest - Front camera
        case .rear:
            return 2  // Rear camera
        case .left:
            return 3  // Left camera
        case .right:
            return 4  // Right camera
        case .interior:
            return 5  // Interior camera
        case .unknown:
            return 99  // Lowest - Unknown
        }
    }

    // MARK: - Detection

    /*
     【Detect Camera Position from Filename】

     Analyzes blackbox filename to automatically determine camera position.

     Parameters:
     - filename: Filename to analyze (e.g., "2025_01_10_09_00_00_F.mp4")

     Return value:
     - CameraPosition: Detected camera position

     Filename format:
     ```
     YYYY_MM_DD_HH_MM_SS_[Position].mp4
     └── F, R, L, Ri, I
     ```

     Detection algorithm:
     1. Split filename by "_"
     2. Extract last component
     3. Remove extension
     4. Try exact matching (F, R, L, Ri, I, U)
     5. Try partial matching (contains F, R, L, Ri, I)
     6. Return unknown if all fail

     Usage examples:
     ```swift
     // 1. Standard filename
     let filename1 = "2025_01_10_09_00_00_F.mp4"
     let position1 = CameraPosition.detect(from: filename1)  // .front

     let filename2 = "2025_01_10_09_00_00_R.mp4"
     let position2 = CameraPosition.detect(from: filename2)  // .rear

     // 2. Variant filename
     let filename3 = "video_F.mp4"
     let position3 = CameraPosition.detect(from: filename3)  // .front

     let filename4 = "dashcam_Ri_001.mp4"
     let position4 = CameraPosition.detect(from: filename4)  // .right

     // 3. Auto-classify during file scan
     let files = ["20250110_090000_F.mp4", "20250110_090000_R.mp4"]
     for filename in files {
     let position = CameraPosition.detect(from: filename)
     print("\(filename): \(position.displayName)")
     }
     // Output:
     // 20250110_090000_F.mp4: Front
     // 20250110_090000_R.mp4: Rear

     // 4. When creating ChannelInfo
     let channelInfo = ChannelInfo(
     position: CameraPosition.detect(from: filename),
     filePath: fullPath,
     // ...
     )
     ```

     Ri vs R distinction:
     - Check "Ri" first
     - "R" && !contains("Ri") condition
     - Accurately distinguishes Rear and Right

     Fallback:
     - Returns .unknown when all pattern matching fails
     - Request manual selection from user
     */
    /// @brief Auto-detect camera position from filename
    /// @param filename Filename to analyze (e.g., "2025_01_10_09_00_00_F.mp4")
    /// @return Detected camera position
    ///
    /// Detect camera position from filename
    /// - Parameter filename: Filename to analyze (e.g., "2025_01_10_09_00_00_F.mp4")
    /// - Returns: Detected camera position
    static func detect(from filename: String) -> CameraPosition {
        // Extract the camera identifier (usually before the extension)
        // Format: YYYY_MM_DD_HH_MM_SS_[Position].mp4
        let components = filename.components(separatedBy: "_")  // Split by "_"

        // Check last component before extension
        // Last component (remove extension)
        if let lastComponent = components.last {
            let withoutExtension = lastComponent.components(separatedBy: ".").first ?? ""

            // Try exact match first (case-insensitive)
            // 1. Try exact matching (case-insensitive)
            let uppercased = withoutExtension.uppercased()
            for position in CameraPosition.allCases {
                if uppercased == position.rawValue {
                    return position
                }
            }

            // Try partial match (case-insensitive)
            // 2. Try partial matching (case-insensitive)
            if uppercased.contains("F") {
                return .front  // Contains "F" → Front
            } else if uppercased.contains("R") && !uppercased.contains("RI") {
                return .rear  // Contains "R" but not "RI" → Rear
            } else if uppercased.contains("L") {
                return .left  // Contains "L" → Left
            } else if uppercased.contains("RI") {
                return .right  // Contains "RI" → Right
            } else if uppercased.contains("I") {
                return .interior  // Contains "I" → Interior
            }
        }

        // 3. All matching failed → unknown
        return .unknown
    }

    /*
     【Create Position from Channel Index】

     Finds CameraPosition from array index.

     Parameters:
     - index: Channel index (0-4)

     Return value:
     - CameraPosition?: Found Position (nil if not found)

     Usage examples:
     ```swift
     // 1. Find Position by index
     if let position = CameraPosition.from(channelIndex: 0) {
     print(position.displayName)  // "Front"
     }

     if let position = CameraPosition.from(channelIndex: 1) {
     print(position.displayName)  // "Rear"
     }

     // 2. Invalid index
     if let position = CameraPosition.from(channelIndex: 10) {
     print(position.displayName)
     } else {
     print("Invalid index")  // This is printed
     }

     // 3. Channel array iteration
     for index in 0..<channels.count {
     if let position = CameraPosition.from(channelIndex: index) {
     let channel = channels[index]
     print("\(position.displayName): \(channel.filePath)")
     }
     }

     // 4. Safe array access
     func getChannel(at index: Int) -> ChannelInfo? {
     guard let position = CameraPosition.from(channelIndex: index),
     index >= 0 && index < channels.count else {
     return nil
     }
     return channels[index]
     }
     ```

     Implementation:
     - Iterate through allCases to find matching channelIndex
     - Returns only first match using first()
     - Returns nil if not found

     Why Optional?:
     - Handles invalid indices like -1 (unknown)
     - Handles out-of-range indices (5, 6, ...)
     - Safe nil return
     */
    /// @brief Create CameraPosition from channel index
    /// @param index Channel index (0-4)
    /// @return Found Position or nil
    ///
    /// Create camera position from channel index
    /// - Parameter index: Channel index (0-4)
    /// - Returns: Camera position or nil if invalid
    static func from(channelIndex index: Int) -> CameraPosition? {
        // Iterate through allCases and return first Position with matching channelIndex
        return CameraPosition.allCases.first { $0.channelIndex == index }
    }
}

// MARK: - Comparable

/*
 【Comparable Protocol Extension】

 Enables sorting CameraPosition by display priority.

 Comparable protocol:
 - Provides <, <=, >, >= operators
 - Enables sorted() function usage
 - Automatically includes Equatable

 Implementation:
 - Compares based on displayPriority property
 - Lower priority is considered "less than"

 Usage examples:
 ```swift
 // 1. Comparison operations
 let front = CameraPosition.front  // priority = 1
 let rear = CameraPosition.rear    // priority = 2

 if front < rear {  // true (1 < 2)
 print("front has higher priority")
 }

 // 2. Sort array (ascending = highest priority first)
 let positions = [CameraPosition.interior, .front, .rear, .left]
 let sorted = positions.sorted()
 // [.front, .rear, .left, .interior]

 // 3. Min/max values
 let minPosition = positions.min()  // .front (priority 1)
 let maxPosition = positions.max()  // .interior (priority 5)

 // 4. Multi-view layout
 let mainCamera = availablePositions.min()  // Highest priority
 let subCameras = availablePositions.filter { $0 != mainCamera }

 // 5. Tab order
 ForEach(CameraPosition.allCases.sorted(), id: \.self) { position in
 VideoPlayerView(position: position)
 .tabItem { Text(position.displayName) }
 }
 ```

 Why implement only < operator?:
 - Swift automatically generates remaining operators
 - Defining < automatically enables >, <=, >=
 - Requirement of Comparable protocol
 */
extension CameraPosition: Comparable {
    /*
     【< Operator Implementation】

     Compares two CameraPositions by display priority.

     Parameters:
     - lhs: Left Hand Side (left operand)
     - rhs: Right Hand Side (right operand)

     Return value:
     - Bool: true if lhs has higher display priority than rhs (lower number = higher priority)

     Examples:
     ```swift
     CameraPosition.front < CameraPosition.rear  // true (1 < 2)
     CameraPosition.rear < CameraPosition.front  // false (2 < 1 is false)
     CameraPosition.interior < CameraPosition.unknown  // true (5 < 99)
     ```

     Note:
     - Lower displayPriority means higher priority
     - front (1) < rear (2): front has priority
     */
    static func < (lhs: CameraPosition, rhs: CameraPosition) -> Bool {
        return lhs.displayPriority < rhs.displayPriority  // Compare by priority number
    }
}
