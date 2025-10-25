/// @file EventType.swift
/// @brief Blackbox recording event type enumeration
/// @author BlackboxPlayer Development Team
/// @details Enumeration for classifying blackbox recording event types.
///          Distinguishes between normal recording, impact events, parking mode, manual recording, emergency recording, etc.,
///          and provides functionality to automatically detect event types from file paths.

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                       EventType Enum Overview                            │
 │                                                                          │
 │  Enumeration for classifying blackbox recording event types.            │
 │                                                                          │
 │  【Event Types】                                                         │
 │                                                                          │
 │  1. normal (Normal Recording)                                            │
 │     - Continuous loop recording                                          │
 │     - Priority: 1 (Lowest)                                               │
 │     - Color: Green (#4CAF50)                                             │
 │                                                                          │
 │  2. impact (Impact Event)                                                │
 │     - Impact/collision detected by G-sensor                              │
 │     - Priority: 4 (High)                                                 │
 │     - Color: Red (#F44336)                                               │
 │                                                                          │
 │  3. parking (Parking Mode)                                               │
 │     - Motion/impact detected while parked                                │
 │     - Priority: 2                                                        │
 │     - Color: Blue (#2196F3)                                              │
 │                                                                          │
 │  4. manual (Manual Recording)                                            │
 │     - User-triggered via button                                          │
 │     - Priority: 3                                                        │
 │     - Color: Orange (#FF9800)                                            │
 │                                                                          │
 │  5. emergency (Emergency Recording)                                      │
 │     - Emergency situations such as SOS button                            │
 │     - Priority: 5 (Highest)                                              │
 │     - Color: Purple (#9C27B0)                                            │
 │                                                                          │
 │  6. unknown (Unknown)                                                    │
 │     - Unrecognized type                                                  │
 │     - Priority: 0 (Default)                                              │
 │     - Color: Gray (#9E9E9E)                                              │
 │                                                                          │
 │  【Auto-detection from Directory Structure】                             │
 │                                                                          │
 │  Automatically determines event type from SD card file path.             │
 │                                                                          │
 │  /sdcard/                                                                │
 │    ├── normal/          → EventType.normal                               │
 │    │   ├── 20250115_100000_F.mp4                                         │
 │    │   └── 20250115_100000_R.mp4                                         │
 │    ├── event/           → EventType.impact                               │
 │    │   ├── 20250115_101500_F.mp4                                         │
 │    │   └── 20250115_101500_R.mp4                                         │
 │    ├── parking/         → EventType.parking                              │
 │    │   └── 20250115_200000_F.mp4                                         │
 │    └── manual/          → EventType.manual                               │
 │        └── 20250115_150000_F.mp4                                         │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【What is an Enum (Enumeration)?】

 Enum is a type that defines a group of related values.

 Advantages:
 1. Type safety: Detects invalid values at compile time
 2. Auto-completion: Xcode suggests possible cases
 3. Code readability: Uses meaningful names
 4. Pattern matching: Powerful features in switch statements

 Basic usage:
 ```swift
 enum EventType {
 case normal
 case impact
 case parking
 }

 let event: EventType = .impact  // Type inference
 ```

 Raw Values:
 ```swift
 enum EventType: String {  // String type specification
 case normal = "normal"
 case impact = "impact"
 }

 let event = EventType.normal
 print(event.rawValue)  // "normal"

 let parsed = EventType(rawValue: "impact")  // Optional<EventType>
 ```

 【Codable Protocol】

 Applying Codable to Enum enables automatic JSON serialization.

 JSON conversion:
 ```swift
 let event = EventType.impact

 // Encoding (Swift → JSON)
 let encoder = JSONEncoder()
 let json = try encoder.encode(event)
 // "impact"

 // Decoding (JSON → Swift)
 let decoder = JSONDecoder()
 let decoded = try decoder.decode(EventType.self, from: json)
 // EventType.impact
 ```

 When Raw Value exists:
 - Represented as rawValue (String) in JSON
 - Examples: "impact", "normal", "parking"

 【CaseIterable Protocol】

 Provides all enum cases as an array.

 Usage:
 ```swift
 enum EventType: String, CaseIterable {
 case normal
 case impact
 case parking
 }

 for eventType in EventType.allCases {
 print(eventType.displayName)
 }

 // Creating UI Picker/Dropdown
 Picker("Event Type", selection: $selectedEvent) {
 ForEach(EventType.allCases, id: \.self) { type in
 Text(type.displayName).tag(type)
 }
 }

 print("Total event types: \(EventType.allCases.count)")  // 6
 ```
 */

import Foundation

/*
 【EventType Enumeration】

 Classifies blackbox recording event types.

 Protocols:
 - String: Uses string as Raw Value
 - Codable: JSON serialization/deserialization
 - CaseIterable: Provides allCases array
 - Comparable: Priority-based sorting

 Usage examples:
 ```swift
 // 1. Auto-detect from file path
 let path = "/sdcard/event/20250115_100000_F.mp4"
 let type = EventType.detect(from: path)  // .impact

 // 2. UI display
 let color = type.colorHex  // "#F44336" (Red)
 let name = type.displayName  // "Impact"

 // 3. Sorting (by priority, highest first)
 let events = [EventType.normal, .impact, .emergency]
 let sorted = events.sorted(by: >)  // [.emergency, .impact, .normal]

 // 4. Filtering
 let videos = allVideos.filter { $0.eventType == .impact }
 ```
 */
/// @enum EventType
/// @brief Blackbox recording event type classification
/// @details Classifies blackbox recording events into normal, impact, parking, manual, emergency, and unknown.
///          Uses String raw values and conforms to Codable, CaseIterable, and Comparable protocols.
enum EventType: String, Codable, CaseIterable {
    /*
     【normal - Normal Recording】

     Continuous loop recording files.

     Characteristics:
     - Automatically records continuously
     - Old files are auto-deleted (to free memory space)
     - Typically 1-3 minute file segments
     - Occupies the largest proportion

     Directory: /normal/ or /Normal/

     Priority: 1 (Lowest)
     - Low priority as it's routine recording
     - Other events are displayed first

     Color: Green (#4CAF50)
     - Green indicates normal state
     - Less prominent in UI

     Example filenames:
     - 20250115_100000_F.mp4
     - 20250115_100100_R.mp4
     */
    /// Normal continuous recording
    case normal = "normal"

    /*
     【impact - Impact Event】

     Impact/collision events detected by G-sensor (accelerometer).

     Trigger conditions:
     - Sudden braking: 0.5G or higher
     - Collision: 1.0G or higher
     - Rapid acceleration/sharp turns: Depending on settings

     Characteristics:
     - Saves 30 seconds before and after impact (1 minute total)
     - 10 seconds before event, 20 seconds after
     - Protected from auto-deletion
     - Important evidence footage

     Directories:
     - /event/ or /Event/
     - /impact/ or /Impact/

     Priority: 4 (High)
     - Important as accident footage
     - Second highest priority after emergency

     Color: Red (#F44336)
     - Red indicates danger/warning
     - Requires immediate user attention

     Examples:
     - Collision accident
     - Sudden braking
     - Driving over road bumps
     - Pothole impact
     */
    /// Impact/collision event recording (triggered by G-sensor)
    case impact = "impact"

    /*
     【parking - Parking Mode】

     Recording triggered by motion or impact while parked.

     Trigger conditions:
     - Motion detection around vehicle (motion sensor)
     - Impact while parked (door dings, contact accidents)
     - Vibration detection

     Characteristics:
     - Battery-saving mode (low power)
     - Records only when detected (time-lapse)
     - Low frame rate (1-5 fps)
     - May require separate battery

     Directories:
     - /parking/ or /Parking/
     - /park/ or /Park/

     Priority: 2
     - Important but lower than impact
     - Evidence for parking lot contact accidents

     Color: Blue (#2196F3)
     - Blue indicates parking mode
     - Calm and stable feeling

     Examples:
     - Parking lot door dings
     - Contact accidents while parked
     - Theft attempts
     */
    /// Parking mode recording (motion/impact detection while parked)
    case parking = "parking"

    /*
     【manual - Manual Recording】

     Recording started manually by user button press.

     Trigger methods:
     - Manual recording button on blackbox
     - Recording button on smartphone app
     - Voice command ("Start recording")

     Characteristics:
     - Intentionally recorded by user
     - Protected from auto-deletion
     - Longer recording duration (5-10 minutes)
     - Starts recording immediately

     Directory: /manual/ or /Manual/

     Priority: 3
     - Between impact and parking
     - Footage deemed important by user

     Color: Orange (#FF9800)
     - Orange draws attention
     - Indicates manual action

     Example situations:
     - Police enforcement
     - Witnessing traffic violations
     - Scenic roads
     - Blackbox testing
     */
    /// Manual recording (user-triggered)
    case manual = "manual"

    /*
     【emergency - Emergency Recording】

     Emergency situation recording triggered by SOS button, etc.

     Trigger methods:
     - SOS/Emergency button on blackbox
     - Emergency button on smartphone app
     - Auto-detection (airbag deployment, etc.)

     Characteristics:
     - Highest priority protection (never deleted)
     - Long recording duration (10-15 minutes)
     - Automatic GPS location saving
     - Notification sent to emergency contacts (some models)

     Directories:
     - /emergency/ or /Emergency/
     - /sos/ or /SOS/

     Priority: 5 (Highest)
     - Footage directly related to life/safety
     - Highest priority among all events

     Color: Purple (#9C27B0)
     - Purple indicates special situations
     - Emphasizes emergency

     Example situations:
     - Serious traffic accidents
     - Critical medical situations
     - Witnessing crimes
     - Situations requiring help
     */
    /// Emergency recording
    case emergency = "emergency"

    /*
     【unknown - Unknown】

     Used when event type cannot be determined from file path or metadata.

     Causes:
     - Non-standard directory structure
     - Corrupted file path
     - Unknown blackbox model
     - User-defined folder

     Characteristics:
     - Default value (fallback)
     - Can be manually classified later
     - Cannot be automatically processed

     Directory: When pattern matching fails

     Priority: 0 (Default)
     - Lowest priority
     - Displayed at bottom when sorted

     Color: Gray (#9E9E9E)
     - Gray indicates unknown
     - Indicates classification needed

     Handling method:
     ```swift
     if eventType == .unknown {
     // Request manual classification from user
     showEventTypeSelector()
     }
     ```
     */
    /// Unknown or unrecognized event type
    case unknown = "unknown"

    // MARK: - Display Properties

    /*
     【Display Name】

     Returns a human-readable name to display in UI.

     Return value:
     - String: English name of event type

     Usage examples:
     ```swift
     let event = EventType.impact
     let name = event.displayName  // "Impact"

     // UI label
     eventLabel.stringValue = event.displayName

     // List item
     List(events) { event in
     Text(event.displayName)
     }

     // Filter button
     Button(event.displayName) {
     filterBy(event)
     }
     ```

     Localization:
     Currently supports English only, but for future multi-language support:
     ```swift
     var displayName: String {
     switch self {
     case .impact:
     return NSLocalizedString("impact", comment: "Impact event")
     // ...
     }
     }
     ```
     */
    /// @brief Human-readable event type name
    /// @return English display name of event type
    var displayName: String {
        switch self {
        case .normal:
            return "Normal"  // Normal recording
        case .impact:
            return "Impact"  // Impact event
        case .parking:
            return "Parking"  // Parking mode
        case .manual:
            return "Manual"  // Manual recording
        case .emergency:
            return "Emergency"  // Emergency recording
        case .unknown:
            return "Unknown"  // Unknown
        }
    }

    /*
     【Color Code (Color Hex)】

     Returns the hex color code corresponding to the event type.

     Format: "#RRGGBB"
     - RR: Red (00-FF)
     - GG: Green (00-FF)
     - BB: Blue (00-FF)

     Return values:
     - normal: #4CAF50 (Green) - RGB(76, 175, 80)
     - impact: #F44336 (Red) - RGB(244, 67, 54)
     - parking: #2196F3 (Blue) - RGB(33, 150, 243)
     - manual: #FF9800 (Orange) - RGB(255, 152, 0)
     - emergency: #9C27B0 (Purple) - RGB(156, 39, 176)
     - unknown: #9E9E9E (Gray) - RGB(158, 158, 158)

     Usage examples:
     ```swift
     let event = EventType.impact
     let colorHex = event.colorHex  // "#F44336"

     // macOS: NSColor
     func hexToNSColor(_ hex: String) -> NSColor {
     let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
     var int: UInt64 = 0
     Scanner(string: hex).scanHexInt64(&int)
     let r = CGFloat((int >> 16) & 0xFF) / 255.0
     let g = CGFloat((int >> 8) & 0xFF) / 255.0
     let b = CGFloat(int & 0xFF) / 255.0
     return NSColor(red: r, green: g, blue: b, alpha: 1.0)
     }

     let color = hexToNSColor(event.colorHex)
     eventLabel.textColor = color

     // SwiftUI: Color
     extension Color {
     init(hex: String) {
     let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
     var int: UInt64 = 0
     Scanner(string: hex).scanHexInt64(&int)
     let r = Double((int >> 16) & 0xFF) / 255.0
     let g = Double((int >> 8) & 0xFF) / 255.0
     let b = Double(int & 0xFF) / 255.0
     self.init(red: r, green: g, blue: b)
     }
     }

     Circle()
     .fill(Color(hex: event.colorHex))
     .frame(width: 20, height: 20)
     ```

     Color selection rationale:
     - Red: Danger/impact (matches traffic signals)
     - Green: Normal/safe
     - Blue: Parking/standby
     - Orange: Caution/manual
     - Purple: Special/emergency
     - Gray: Neutral/unknown
     */
    /// @brief Color code corresponding to event type
    /// @return Hex color code (#RRGGBB)
    var colorHex: String {
        switch self {
        case .normal:
            return "#4CAF50"  // Green - Normal/safe
        case .impact:
            return "#F44336"  // Red - Danger/impact
        case .parking:
            return "#2196F3"  // Blue - Parking/standby
        case .manual:
            return "#FF9800"  // Orange - Caution/manual
        case .emergency:
            return "#9C27B0"  // Purple - Special/emergency
        case .unknown:
            return "#9E9E9E"  // Gray - Neutral/unknown
        }
    }

    /*
     【Priority】

     Returns the priority indicating the importance of the event type.

     Range: 0 ~ 5
     - 5: emergency (Highest)
     - 4: impact
     - 3: manual
     - 2: parking
     - 1: normal
     - 0: unknown (Lowest)

     Usage purposes:
     1. Sorting: Display important footage first
     2. Filtering: Filter by priority
     3. Notifications: Notify only high priority
     4. Backup: Prioritize important files for backup

     Usage examples:
     ```swift
     // 1. Sort (by priority, highest first)
     let events = [EventType.normal, .impact, .emergency, .parking]
     let sorted = events.sorted { $0.priority > $1.priority }
     // [.emergency, .impact, .parking, .normal]

     // 2. Sort videos
     let sortedVideos = videos.sorted { video1, video2 in
     if video1.eventType.priority != video2.eventType.priority {
     return video1.eventType.priority > video2.eventType.priority
     }
     return video1.timestamp > video2.timestamp  // If same priority, newest first
     }

     // 3. Filter important events
     let importantVideos = videos.filter { $0.eventType.priority >= 3 }

     // 4. Auto-backup (priority 4 or higher)
     let backupCandidates = videos.filter { $0.eventType.priority >= 4 }

     // 5. UI badge display
     if event.priority >= 4 {
     showBadge(text: "Important", color: .red)
     }
     ```

     Using with Comparable protocol:
     ```swift
     let event1 = EventType.normal  // priority = 1
     let event2 = EventType.impact  // priority = 4

     if event1 < event2 {  // true (1 < 4)
     print("event2 is more important")
     }

     let events = [EventType.normal, .impact, .emergency]
     let sorted = events.sorted()  // Using Comparable protocol
     // [.normal, .impact, .emergency]  // Ascending order
     ```
     */
    /// @brief Priority of event type
    /// @return Priority value (0-5, higher is more important)
    var priority: Int {
        switch self {
        case .emergency:
            return 5  // Highest - Life/safety related
        case .impact:
            return 4  // High - Accident footage
        case .manual:
            return 3  // Medium - User deemed important
        case .parking:
            return 2  // Low - Event while parked
        case .normal:
            return 1  // Lowest - Normal recording
        case .unknown:
            return 0  // Default - Unknown
        }
    }

    // MARK: - Detection

    /*
     【Detect Event Type from File Path】

     Analyzes blackbox SD card file path to automatically determine event type.

     Parameters:
     - path: File path to analyze (e.g., "/sdcard/event/20250115_100000_F.mp4")

     Return value:
     - EventType: Detected event type

     Detection patterns:
     1. "/normal/" or "normal/" → .normal
     2. "/event/", "/impact/" → .impact
     3. "/parking/", "/park/" → .parking
     4. "/manual/" → .manual
     5. "/emergency/", "/sos/" → .emergency
     6. Match failed → .unknown

     Case-insensitive:
     - Compares after converting to lowercased()
     - Recognizes "/Event/", "/EVENT/", "/event/" all

     Path patterns:
     - contains(): Directory name included in middle
     - hasPrefix(): Directory name at start of path

     Usage examples:
     ```swift
     // 1. Auto-detect from file path
     let path1 = "/sdcard/event/20250115_100000_F.mp4"
     let type1 = EventType.detect(from: path1)  // .impact

     let path2 = "/mnt/sdcard/Normal/20250115_100500_R.mp4"
     let type2 = EventType.detect(from: path2)  // .normal

     let path3 = "emergency/20250115_120000_F.mp4"  // Relative path
     let type3 = EventType.detect(from: path3)  // .emergency

     // 2. Auto-classify during file scan
     let files = fileManager.contentsOfDirectory(atPath: sdcardPath)
     for file in files {
     let fullPath = sdcardPath + "/" + file
     let eventType = EventType.detect(from: fullPath)
     print("\(file): \(eventType.displayName)")
     }

     // 3. Auto-set when creating VideoFile
     let videoFile = VideoFile(
     path: filePath,
     eventType: EventType.detect(from: filePath),
     // ...
     )

     // 4. Handle multiple patterns
     let paths = [
     "/normal/file.mp4",        // .normal
     "event/file.mp4",          // .impact
     "/SOS/file.mp4",           // .emergency
     "/unknown_dir/file.mp4"    // .unknown
     ]
     for path in paths {
     print("\(path): \(EventType.detect(from: path))")
     }
     ```

     Differences by blackbox manufacturer:
     - Most: "/event/" (impact)
     - Some: "/impact/" (impact)
     - Some: "/emer/" (emergency)
     - This method supports all patterns

     Fallback handling:
     - Returns .unknown when all pattern matching fails
     - Manual classification needed later
     - Handles user-defined directories
     */
    /// @brief Auto-detect event type from file path
    /// @param path File path to analyze
    /// @return Detected event type
    static func detect(from path: String) -> EventType {
        // Compare case-insensitively
        let lowercasedPath = path.lowercased()

        // 1. Check Normal
        if lowercasedPath.contains("/normal/") || lowercasedPath.hasPrefix("normal/") {
            return .normal
        }
        // 2. Check Impact (event or impact directory)
        else if lowercasedPath.contains("/event/") || lowercasedPath.hasPrefix("event/") ||
                    lowercasedPath.contains("/impact/") || lowercasedPath.hasPrefix("impact/") {
            return .impact
        }
        // 3. Check Parking (parking or park directory)
        else if lowercasedPath.contains("/parking/") || lowercasedPath.hasPrefix("parking/") ||
                    lowercasedPath.contains("/park/") || lowercasedPath.hasPrefix("park/") {
            return .parking
        }
        // 4. Check Manual
        else if lowercasedPath.contains("/manual/") || lowercasedPath.hasPrefix("manual/") {
            return .manual
        }
        // 5. Check Emergency (emergency or sos directory)
        else if lowercasedPath.contains("/emergency/") || lowercasedPath.hasPrefix("emergency/") ||
                    lowercasedPath.contains("/sos/") || lowercasedPath.hasPrefix("sos/") {
            return .emergency
        }

        // 6. Return unknown on match failure
        return .unknown
    }
}

// MARK: - Comparable

/*
 【Comparable Protocol Extension】

 Enables sorting EventType by priority.

 Comparable protocol:
 - Provides <, <=, >, >= operators
 - Enables sorted() function usage
 - Automatically includes Equatable

 Implementation:
 - Compares based on priority property
 - Lower priority is considered "less than"

 Usage examples:
 ```swift
 // 1. Comparison operations
 let normal = EventType.normal  // priority = 1
 let impact = EventType.impact  // priority = 4

 if normal < impact {  // true (1 < 4)
 print("normal has lower priority")
 }

 if impact > normal {  // true (4 > 1)
 print("impact has higher priority")
 }

 // 2. Sort array (ascending)
 let events = [EventType.emergency, .normal, .impact, .parking]
 let ascending = events.sorted()
 // [.normal, .parking, .impact, .emergency]

 // 3. Sort array (descending)
 let descending = events.sorted(by: >)
 // [.emergency, .impact, .parking, .normal]

 // 4. Find min/max
 let minEvent = events.min()  // .normal
 let maxEvent = events.max()  // .emergency

 // 5. Sort videos (event priority + time)
 let sortedVideos = videos.sorted { video1, video2 in
 if video1.eventType != video2.eventType {
 return video1.eventType > video2.eventType  // Highest priority first
 }
 return video1.timestamp > video2.timestamp  // If same, newest first
 }
 ```

 Why implement only < operator?
 - Swift automatically generates remaining operators
 - Defining < automatically enables >, <=, >=
 - Requirement of Comparable protocol
 */
extension EventType: Comparable {
    /*
     【< Operator Implementation】

     Compares two EventTypes by priority.

     Parameters:
     - lhs: Left Hand Side (left operand)
     - rhs: Right Hand Side (right operand)

     Return value:
     - Bool: true if lhs has lower priority than rhs

     Examples:
     ```swift
     EventType.normal < EventType.impact  // true (1 < 4)
     EventType.emergency < EventType.normal  // false (5 < 1 is false)
     ```
     */
    /// @brief Priority-based comparison operator
    /// @param lhs Left EventType
    /// @param rhs Right EventType
    /// @return true if lhs has lower priority than rhs
    static func < (lhs: EventType, rhs: EventType) -> Bool {
        return lhs.priority < rhs.priority  // Compare by priority number
    }
}
