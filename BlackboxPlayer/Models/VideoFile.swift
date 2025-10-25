/// @file VideoFile.swift
/// @brief Blackbox video file model (multi-channel support)
/// @author BlackboxPlayer Development Team
///
/// Model for dashcam video file (potentially multi-channel)

import Foundation

/*
 ═══════════════════════════════════════════════════════════════════════════════
 VideoFile - Blackbox Video File Model
 ═══════════════════════════════════════════════════════════════════════════════

 【Overview】
 VideoFile blackbox recording File complete information represent top-level model.
 multiple camera channel, GPS/G-Sensor metadata, Event Type, useer settings etc all information
 one struct integration management.

 【VideoFileWhat is】

 A collection of all channel video files and metadata recorded at a single recording time.

 structure example (2channel blackbox, 2025-01-10 09:00:00 recording):

 VideoFile (2025_01_10_09_00_00)
 ├─ 📹 channel 1: Front Camera
 │   └─ File: 2025_01_10_09_00_00_F.mp4 (Full HD, 100 MB)
 │
 ├─ 📹 channel 2: Rear Camera
 │   └─ File: 2025_01_10_09_00_00_R.mp4 (HD, 50 MB)
 │
 ├─ 📍 GPS metadata
 │   └─ 3,600 GPS points (every 1 second)
 │
 ├─ 📊 G-Sensor metadata
 │   └─ 36,000 acceleration data points (every 0.1 second)
 │
 └─ 📝 Additional Information
 ├─ Event Type: Normal recording
 ├─ recording time: 2025-01-10 09:00:00
 ├─ Duration: 1 minute
 ├─ Favorite: false
 ├─ Notes: nil
 └─ Corrupted status: false

 【Model Integration】

 VideoFile combines all other models:

 VideoFile
 ├─ EventType enum         (Event Type)
 ├─ [channelInfo]          (channel array)
 │   └─ CameraPosition enum (camera abovetion)
 │
 └─ VideoMetadata          (metadata)
 ├─ [GPSPoint]         (GPS array)
 └─ [AccelerationData] (acceleration array)

 【Immutable Struct】

 VideoFile struct declared as an immutable data structure.

 immutable advantages:
 1. thread safe (Thread-safe)
 - multiple threadfrom simultaneously read safe
 - synchronization(lock) not required

 2. prediction possibility (Predictability)
 - create  value change not
 - side effect(side effect) none

 3. value copy (Value semantics)
 - assignment  copy create
 - original affect none

 Immutable update pattern:
 ```swift
 // original file
 let originalFile = VideoFile(...)

 // new instance create (original file change not ed)
 let updatedFile = originalFile.withFavorite(true)

 // originalFile: isFavorite = false (change not ed)
 // updatedFile: isFavorite = true   (new instance)
 ```

  pattern SwiftUI with use when particularly useful:
 - @State, @Bindingand naturally operation
 - view update automatic trigger
 - Undo/Redo implementation easy

 【Multi-channel System】

 one VideoFile 1~5 channel contains number :

 1channel (Basic):
 ┌─────────────┐
 │   Front (F)   │
 └─────────────┘

 2channel (Common):
 ┌─────────────┬─────────────┐
 │   Front (F)   │   Rear (R)   │
 └─────────────┴─────────────┘

 4channel (Advanced):
 ┌──────┬──────┬──────┬──────┐
 │ Front  │ Rear  │ Left  │ Right  │
 │  (F) │  (R) │  (L) │ (Ri) │
 └──────┴──────┴──────┴──────┘

 5channel (Advanced):
 ┌──────┬──────┬──────┬──────┬──────┐
 │ Front  │ Rear  │ Left  │ Right  │ Interior  │
 │  (F) │  (R) │  (L) │ (Ri) │  (I) │
 └──────┴──────┴──────┴──────┴──────┘

 all channel sameone timestamp recordingonly independentin File.

 【File System Structure】

 blackbox SD card  structure:

 /media/sd/
 ├─ normal/                    (Normal recording)
 │   ├─ 2025_01_10_09_00_00_F.mp4
 │   ├─ 2025_01_10_09_00_00_R.mp4
 │   ├─ 2025_01_10_09_01_00_F.mp4
 │   └─ 2025_01_10_09_01_00_R.mp4
 │
 ├─ event/                     (Impact events)
 │   ├─ 2025_01_10_10_30_15_F.mp4
 │   └─ 2025_01_10_10_30_15_R.mp4
 │
 ├─ parking/                   (Parking mode)
 │   └─ 2025_01_10_18_00_00_F.mp4
 │
 └─ manual/                    (Manual recording)
 ├─ 2025_01_10_15_00_00_F.mp4
 └─ 2025_01_10_15_00_00_R.mp4

 basePath:
 - "normal/2025_01_10_09_00_00" (channel suffix exclude)
 - all channel commoned path portion

 【Usage Example】

 ```swift
 // 2channel blackbox file create
 let videoFile = VideoFile(
 timestamp: Date(),
 eventType: .normal,
 duration: 60.0,
 channels: [frontchannel, rearchannel],
 metadata: metadata,
 basePath: "normal/2025_01_10_09_00_00"
 )

 // channel access
 if let frontchannel = videoFile.frontchannel {
 print("Front Camera: \(frontchannel.resolutionName)")
 }

 // metadata check
 if videoFile.hasImpactEvents {
 print("⚠️ Impact events \(videoFile.impactEventCount)times")
 }

 // File information
 print("total size: \(videoFile.totalFileSizeString)")
 print("Duration: \(videoFile.durationString)")
 print("time: \(videoFile.timestampString)")

 // Favorite Add (Immutable update)
 let favoriteFile = videoFile.withFavorite(true)
 ```

 ═══════════════════════════════════════════════════════════════════════════════
 */

/// @struct VideoFile
/// @brief blackbox video file (multi channel, metadata include)
///
/// Dashcam video file with metadata and channel information
///
/// blackbox video file complete information represent struct.
///
/// **include information:**
/// - channel information (1~5 camera)
/// - metadata (GPS, G-Sensor)
/// - Event Type (normal, impact, parking etc)
/// - useer settings (Favorite, Notes)
/// - File status (Corrupted status)
///
/// **:**
/// - Codable: JSON serialization/serialization
/// - Equatable: etc compare
/// - Identifiable: SwiftUI List/ForEachfrom Unique each
/// - Hashable: Set/Dictionary key use possible
///
/// **immutable structure:**
/// - struct declared as value type (value type)
/// - property  let (constant)
/// - change new instance create (withX method)
///
/// **use example:**
/// ```swift
/// let videoFile = VideoFile(
///     timestamp: Date(),
///     eventType: .normal,
///     duration: 60.0,
///     channels: [frontchannel, rearchannel],
///     metadata: metadata,
///     basePath: "normal/2025_01_10_09_00_00"
/// )
///
/// // channel check
/// print("channel number: \(videoFile.channelCount)")
/// print("Front Camera: \(videoFile.haschannel(.front) ? "available" : "none")")
///
/// // metadata check
/// if videoFile.hasImpactEvents {
///     print("⚠️ impact \(videoFile.impactEventCount)times")
/// }
///
/// // Favorite Add (Immutable update)
/// let favoriteFile = videoFile.withFavorite(true)
/// ```
struct VideoFile: Codable, Equatable, Identifiable, Hashable {
    /// @var id
    /// @brief File Unique eacher (UUID)
    ///
    /// Unique identifier
    ///
    /// File Unique eacher.
    ///
    /// **UUID (Universally Unique Identifier):**
    /// - 128 Unique eacher
    /// - SwiftUI List/ForEachfrom each File distinguish
    /// -  :  0 (10^-18 numberlevel)
    ///
    /// **use example:**
    /// ```swift
    /// List(videoFiles) { file in
    ///     // file.id each File distinguish
    ///     VideoFileRow(file: file)
    /// }
    /// ```
    let id: UUID

    /// @var timestamp
    /// @brief recording start time
    ///
    /// Recording start timestamp
    ///
    /// recording start time.
    ///
    /// **Date type:**
    /// - Swift level date/time type
    /// - UTC half  time (ing independent)
    /// - TimeInterval operation possible (second unit)
    ///
    /// **timestamp usage:**
    /// - File sort (timepure sort)
    /// - File search (date/time filter)
    /// - UI display (DateFormatter)
    ///
    /// **filename :**
    /// - filename include: YYYY_MM_DD_HH_MM_SS
    /// - example: 2025_01_10_09_00_00 → 2025-01-10 09:00:00
    ///
    /// **use example:**
    /// ```swift
    /// // time compare
    /// let recentFiles = videoFiles.filter { file in
    ///     file.timestamp > Date().addingTimeInterval(-3600) // 1time 
    /// }
    ///
    /// // timepure sort
    /// let sortedFiles = videoFiles.sorted { $0.timestamp < $1.timestamp }
    ///
    /// // date display
    /// print(videoFile.timestampString)  // "2025. 1. 10. AM 9:00"
    /// ```
    let timestamp: Date

    /// @var eventType
    /// @brief Event Type (normal, impact, parking etc)
    ///
    /// Event type (normal, impact, parking, etc.)
    ///
    /// Event Type.
    ///
    /// **EventType enum:**
    /// - normal: Normal recording (priority 1)
    /// - impact: Impact events (priority 4)
    /// - parking: Parking mode (priority 2)
    /// - manual: Manual recording (priority 3)
    /// - emergency:  recording (priority 5)
    /// - unknown:  number none (priority 0)
    ///
    /// **automatic minute:**
    /// - File path automatic detection
    /// - "event/" foldermore → .impact
    /// - "parking/" foldermore → .parking
    /// - "manual/" foldermore → .manual
    ///
    /// **usage:**
    /// - File minute  
    /// -   (: impact, second: normal)
    /// - priority sort
    ///
    /// **use example:**
    /// ```swift
    /// // Impact events filterring
    /// let impactFiles = videoFiles.filter { $0.eventType == .impact }
    ///
    /// // priority sort (high )
    /// let sortedFiles = videoFiles.sorted { $0.eventType > $1.eventType }
    ///
    /// //  display
    /// let badgeColor = videoFile.eventType.colorHex  // "#F44336" ()
    /// ```
    let eventType: EventType

    /// @var duration
    /// @brief video Duration (second)
    ///
    /// Video duration in seconds
    ///
    /// video Duration. (unit: second)
    ///
    /// **TimeInterval type:**
    /// - Double typealias
    /// - number include possible (example: 59.5second)
    ///
    /// **Commonin recording Duration:**
    /// - 1 minute: 60.0second ( Common)
    /// - 3minute: 180.0second
    /// - 5minute: 300.0second
    /// - Impact events: 30.0second ( include)
    /// - Parking mode: 10.0second (ing detection )
    ///
    /// **all channel same:**
    /// - all channel duration same
    /// - simultaneously recording start/
    ///
    /// **format:**
    /// - durationString: "1:00" (1 minute), "1:30" (1 minute 30second), "1:05:30" (1time 5minute 30second)
    ///
    /// **use example:**
    /// ```swift
    /// print("Duration: \(videoFile.durationString)")  // "1:00"
    ///
    /// //  video filterring
    /// let longVideos = videoFiles.filter { $0.duration > 180.0 } // 3minute or more
    ///
    /// // playback  calculate
    /// let progress = currentTime / videoFile.duration  // 0.0 ~ 1.0
    /// ```
    let duration: TimeInterval

    /// @var channels
    /// @brief all video channel array (1~5channel)
    ///
    /// All video channels (front, rear, left, right, interior)
    ///
    /// all video channel array.
    ///
    /// **channelInfo array:**
    /// - 1~5 channel include
    /// - each channel independentin video file
    /// - sameone timestamp, duration
    ///
    /// **channel number  minute:**
    /// - 1channel: Frontonly (Basic)
    /// - 2channel: Front + Rear (Common)
    /// - 3channel: Front + Rear + Interior
    /// - 4channel: Front + Rear + Left + Right
    /// - 5channel: Front + Rear + Left + Right + Interior
    ///
    /// **array purefrom:**
    /// - purefrom ha not
    /// - Commonuh displayPriority purefrom (front, rear, left, right, interior)
    ///
    /// **usage:**
    /// - multi view playback ( minutedo)
    /// - channeleach playback/ 
    /// - total File size calculate
    ///
    /// **use example:**
    /// ```swift
    /// print("channel number: \(videoFile.channels.count)")
    ///
    /// // all channel information output
    /// for channel in videoFile.channels {
    ///     print("\(channel.position.displayName): \(channel.resolutionName)")
    /// }
    ///
    /// // specific channel 
    /// if let frontchannel = videoFile.frontchannel {
    ///     print("Front: \(frontchannel.fileSizeString)")
    /// }
    /// ```
    let channels: [channelInfo]

    /// @var metadata
    /// @brief GPS  G-Sensor metadata
    ///
    /// Associated metadata (GPS, G-Sensor)
    ///
    /// GPS  G-Sensor metadata.
    ///
    /// **VideoMetadata structure:**
    /// - gpsPoints: [GPSPoint] (GPS )
    /// - accelerationData: [AccelerationData] (Sensor )
    /// - deviceInfo: DeviceInfo? (device information)
    ///
    /// **metadata size:**
    /// - GPS: 1time approximately 3,600 points (1Hz)
    /// - G-Sensor: 1time approximately 36,000 points (10Hz)
    /// - Notes: 1time approximately 2.5 MB
    ///
    /// **empty metadata:**
    /// - GPS/Sensor not blackbox
    /// - nine model
    /// - metadata = VideoMetadata() (empty struct)
    ///
    /// **usage:**
    /// -  driving path display
    /// - speed  display
    /// - Impact events ingtimeline display
    ///
    /// **use example:**
    /// ```swift
    /// // GPS data check
    /// if videoFile.hasGPSData {
    ///     let summary = videoFile.metadata.summary
    ///     print("driving distance: \(summary.distanceString)")
    ///     print("average speed: \(summary.averageSpeedString ?? "N/A")")
    /// }
    ///
    /// // Impact events check
    /// if videoFile.hasImpactEvents {
    ///     for event in videoFile.metadata.impactEvents {
    ///         print("impact: \(event.magnitude)G at \(event.timestamp)")
    ///     }
    /// }
    /// ```
    let metadata: VideoMetadata

    /// @var basePath
    /// @brief Basic File path (channel suffix exclude)
    ///
    /// Base file path (without channel suffix)
    ///
    /// Basic File path. (channel suffix exclude)
    ///
    /// **basePath structure:**
    /// - "foldermore/YYYY_MM_DD_HH_MM_SS"
    /// - channeleach File _F, _R, _L, _Ri, _I suffix Add
    ///
    /// **example:**
    /// ```
    /// basePath: "normal/2025_01_10_09_00_00"
    ///
    ///  File:
    ///   normal/2025_01_10_09_00_00_F.mp4   (Front)
    ///   normal/2025_01_10_09_00_00_R.mp4   (Rear)
    ///   normal/2025_01_10_09_00_00_L.mp4   (Left)
    ///   normal/2025_01_10_09_00_00_Ri.mp4  (Right)
    ///   normal/2025_01_10_09_00_00_I.mp4   (Interior)
    /// ```
    ///
    /// **foldermore structure:**
    /// - "normal/": Normal recording
    /// - "event/": Impact events
    /// - "parking/": Parking mode
    /// - "manual/": Manual recording
    /// - "emergency/":  recording
    ///
    /// **usage:**
    /// - File path create
    /// - foldermoreeach minute
    /// - File  (all channel simultaneously )
    ///
    /// **use example:**
    /// ```swift
    /// // Basic filename extract
    /// print(videoFile.baseFilename)  // "2025_01_10_09_00_00"
    ///
    /// // total path create
    /// let frontPath = "\(videoFile.basePath)_F.mp4"
    /// let rearPath = "\(videoFile.basePath)_R.mp4"
    /// ```
    let basePath: String

    /// @var isFavorite
    /// @brief whether marked as favorite
    ///
    /// Whether this file is marked as favorite
    ///
    /// whether marked as favorite.
    ///
    /// **Favorite :**
    /// - useer one video display
    /// - automatic from 
    /// -  access (Favorite )
    ///
    /// **usage :**
    /// -  
    /// -  pure
    /// - accident video ()
    /// - specialone pure (, event)
    ///
    /// **Immutable update:**
    /// ```swift
    /// // Favorite Add
    /// let favoriteFile = videoFile.withFavorite(true)
    ///
    /// // Favorite 
    /// let unfavoriteFile = favoriteFile.withFavorite(false)
    /// ```
    ///
    /// **UI display:**
    /// - each  (★ vs ☆)
    /// -  
    /// - Favorite 
    ///
    /// **use example:**
    /// ```swift
    /// // Favorite filterring
    /// let favorites = videoFiles.filter { $0.isFavorite }
    ///
    /// // Favorite 
    /// let updatedFile = videoFile.withFavorite(!videoFile.isFavorite)
    ///
    /// // UI display
    /// favoriteButton.setImage(
    ///     UIImage(systemName: videoFile.isFavorite ? "star.fill" : "star"),
    ///     for: .normal
    /// )
    /// ```
    let isFavorite: Bool

    /// @var notes
    /// @brief useer Notes/ ()
    ///
    /// User-added notes/comments
    ///
    /// useer Addone Notes/.
    ///
    /// ** String:**
    /// - Notes notuh nil
    /// - empty string("")and nil 
    /// - nil: Notes  not 
    /// - "": Notes only available
    ///
    /// **usage :**
    /// - video description (" ")
    /// - abovetion information ("from ")
    /// -  record (" ")
    /// - itemsin Notes (" ")
    ///
    /// **maximum Duration:**
    /// - one none (UIfrom one possible)
    /// - Commonuh 200~500er
    ///
    /// **Immutable update:**
    /// ```swift
    /// // Notes Add
    /// let notedFile = videoFile.withNotes("Beautiful sunset drive")
    ///
    /// // Notes 
    /// let clearedFile = notedFile.withNotes(nil)
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// // Notes display
    /// if let notes = videoFile.notes, !notes.isEmpty {
    ///     notesLabel.text = notes
    ///     notesLabel.isHidden = false
    /// } else {
    ///     notesLabel.isHidden = true
    /// }
    ///
    /// // Notes search
    /// let searchResults = videoFiles.filter { file in
    ///     file.notes?.localizedCaseInsensitiveContains("sunset") ?? false
    /// }
    /// ```
    let notes: String?

    /// @var isCorrupted
    /// @brief whether file is corrupted
    ///
    /// File is corrupted or damaged
    ///
    /// File Corrupted status.
    ///
    /// **corrupted in:**
    /// - SD card  
    /// -   only (recording )
    /// - File  corrupted
    /// -  
    ///
    /// **corrupted :**
    /// - playback 
    /// - metadata  
    /// - File size 0
    /// - duration = 0
    ///
    /// **corrupted File processing:**
    /// - playback  not  ( )
    /// - UI  display
    /// - nine  also  
    ///
    /// **isPlayable vs isCorrupted:**
    /// - isPlayable = isValid && !isCorrupted
    /// -    safeone playback
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.isCorrupted {
    ///     // corrupted File display
    ///     thumbnailView.alpha = 0.5
    ///     warningLabel.text = "⚠️ corrupteded File"
    ///     warningLabel.isHidden = false
    ///     playButton.isEnabled = false
    /// } else if videoFile.isPlayable {
    ///     // normal playback possible
    ///     playButton.isEnabled = true
    /// }
    ///
    /// // corrupted File filterring
    /// let healthyFiles = videoFiles.filter { !$0.isCorrupted }
    /// ```
    let isCorrupted: Bool

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date,
        eventType: EventType,
        duration: TimeInterval,
        channels: [channelInfo],
        metadata: VideoMetadata = VideoMetadata(),
        basePath: String,
        isFavorite: Bool = false,
        notes: String? = nil,
        isCorrupted: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.duration = duration
        self.channels = channels
        self.metadata = metadata
        self.basePath = basePath
        self.isFavorite = isFavorite
        self.notes = notes
        self.isCorrupted = isCorrupted
    }

    // MARK: - channel Access

    /// @brief specific abovetion channel search
    /// @param position camera abovetion
    /// @return channel information also nil
    ///
    /// Get channel by position
    /// - Parameter position: Camera position
    /// - Returns: channel info or nil
    ///
    /// specific abovetion channel .
    ///
    /// **search :**
    /// - first(where:) use
    /// - array iterateha  th tion  return
    /// - time : O(n), n = channels.count ( 1~5)
    ///
    /// ** return:**
    /// - channels if available channelInfo return
    /// - channels notuh nil return
    ///
    /// **use example:**
    /// ```swift
    /// // Front Camera 
    /// if let frontchannel = videoFile.channel(for: .front) {
    ///     print("Front: \(frontchannel.resolutionName)")
    /// } else {
    ///     print("Front Camera none")
    /// }
    ///
    /// // all channel check
    /// for position in CameraPosition.allCases {
    ///     if let channel = videoFile.channel(for: position) {
    ///         print("\(position.displayName): \(channel.fileSizeString)")
    ///     }
    /// }
    /// ```
    func channel(for position: CameraPosition) -> channelInfo? {
        return channels.first { $0.position == position }
    }

    /// @brief Front Camera channel
    /// @return Front channel also nil
    ///
    /// Front camera channel
    ///
    /// Front Camera channel.
    ///
    /// **convenience property:**
    /// - channel(for: .front) approximately
    /// -  er use channel (Front)
    ///
    /// **use example:**
    /// ```swift
    /// if let front = videoFile.frontchannel {
    ///     print("Front resolution: \(front.resolutionName)")
    ///     playerView.loadVideo(from: front.filePath)
    /// }
    /// ```
    var frontchannel: channelInfo? {
        return channel(for: .front)
    }

    /// @brief Rear Camera channel
    /// @return Rear channel also nil
    ///
    /// Rear camera channel
    ///
    /// Rear Camera channel.
    ///
    /// **convenience property:**
    /// - channel(for: .rear) approximately
    /// - 2channel or more blackboxfrom use
    ///
    /// **use example:**
    /// ```swift
    /// if let rear = videoFile.rearchannel {
    ///     print("Rear resolution: \(rear.resolutionName)")
    ///     rearPlayerView.loadVideo(from: rear.filePath)
    /// }
    /// ```
    var rearchannel: channelInfo? {
        return channel(for: .rear)
    }

    /// @brief specific channel  whether check
    /// @param position camera abovetion
    /// @return channels if available true
    ///
    /// Check if specific channel exists
    /// - Parameter position: Camera position
    /// - Returns: True if channel exists
    ///
    /// specific channels exists check.
    ///
    /// ** :**
    /// - channel(for:) nil  true
    /// - nil false
    ///
    /// **use example:**
    /// ```swift
    /// // channeleach UI display/
    /// rearPlayerView.isHidden = !videoFile.haschannel(.rear)
    /// leftPlayerView.isHidden = !videoFile.haschannel(.left)
    /// rightPlayerView.isHidden = !videoFile.haschannel(.right)
    ///
    /// // channel count not
    /// if videoFile.haschannel(.rear) {
    ///     print("2channel or more blackbox")
    /// } else {
    ///     print("1channel blackbox")
    /// }
    /// ```
    func haschannel(_ position: CameraPosition) -> Bool {
        return channel(for: position) != nil
    }

    /// @brief use possibleone channel count
    /// @return channel count (1~5)
    ///
    /// Number of available channels
    ///
    /// use possibleone channel count.
    ///
    /// **channel count:**
    /// - 1: Frontonly
    /// - 2: Front + Rear ( Common)
    /// - 3: Front + Rear + Interior
    /// - 4: Front + Rear + Left + Right
    /// - 5: Front + Rear + Left + Right + Interior
    ///
    /// **use example:**
    /// ```swift
    /// print("\(videoFile.channelCount)channel blackbox")
    ///
    /// // UI  
    /// switch videoFile.channelCount {
    /// case 1:
    ///     useSingleViewLayout()
    /// case 2:
    ///     useDualViewLayout()
    /// case 3...5:
    ///     useMultiViewLayout()
    /// default:
    ///     break
    /// }
    /// ```
    var channelCount: Int {
        return channels.count
    }

    /// @brief enableded channel array
    /// @return enableded channelonly include
    ///
    /// Array of enabled channels only
    ///
    /// enableded channelonly includeha array.
    ///
    /// **filterring:**
    /// - isEnabled == truein channelonly
    /// - useer specific channel   exclude
    ///
    /// **use example:**
    /// ```swift
    /// // enableded channelonly playback
    /// for channel in videoFile.enabledchannels {
    ///     createPlayerView(for: channel)
    /// }
    ///
    /// print("\(videoFile.enabledchannels.count) channel enabled")
    /// ```
    var enabledchannels: [channelInfo] {
        return channels.filter { $0.isEnabled }
    }

    /// @brief multi channel recording check
    /// @return 2channel or more true
    ///
    /// Check if this is a multi-channel recording
    ///
    /// multi channel recordingin check.
    ///
    /// **multi channel level:**
    /// - 2 or more channel
    /// - 1channel: false (only channel)
    /// - 2channel or more: true (multi channel)
    ///
    /// **usage:**
    /// - UI  
    /// - channel   display/
    /// -  minutedo mode enabled
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.isMultichannel {
    ///     // channel   display
    ///     channelSwitchButton.isHidden = false
    ///
    ///     //  minutedo  enabled
    ///     splitViewButton.isEnabled = true
    /// } else {
    ///     // only channel mode
    ///     channelSwitchButton.isHidden = true
    ///     splitViewButton.isEnabled = false
    /// }
    /// ```
    var isMultichannel: Bool {
        return channels.count > 1
    }

    // MARK: - File Properties

    /// @brief all channel File total size
    /// @return total File size (bytes)
    ///
    /// Total size of all channel files
    ///
    /// all channel File total size. (unit: bytes)
    ///
    /// ** operation:**
    /// - reduce useha all channel fileSize sum
    /// - initialvalue: 0
    /// -  operation: $0 + $1.fileSize
    ///
    /// **reduce operation :**
    /// ```swift
    /// channels.reduce(0) { $0 + $1.fileSize }
    ///
    /// // stepeach calculate (2channel example):
    /// initial: result = 0
    /// 1step: result = 0 + frontchannel.fileSize (100 MB)
    ///        result = 100 MB
    /// 2step: result = 100 MB + rearchannel.fileSize (50 MB)
    ///        result = 150 MB
    /// final: 150 MB
    /// ```
    ///
    /// **example size:**
    /// - 1channel: 60~100 MB (1 minute Full HD)
    /// - 2channel: 100~150 MB
    /// - 5channel: 200~300 MB
    ///
    /// **use example:**
    /// ```swift
    /// let totalSize = videoFile.totalFileSize
    /// print("total size: \(totalSize) bytes")
    ///
    /// // formated string
    /// print("total size: \(videoFile.totalFileSizeString)")  // "150 MB"
    ///
    /// // storage  
    /// if videoFile.totalFileSize > 500_000_000 {  // 500 MB
    ///     print("⚠️  File")
    /// }
    /// ```
    var totalFileSize: UInt64 {
        // reduce all channel fileSize sum
        return channels.reduce(0) { $0 + $1.fileSize }
    }

    /// @brief total File size string
    /// @return "XXX MB" also "X.X GB" format
    ///
    /// Total file size as human-readable string
    ///
    /// total File size   string return.
    ///
    /// **ByteCountFormatter:**
    /// - Foundation level File size format
    /// - automaticuh one unit 
    /// - 1024 half ()
    ///
    /// **format example:**
    /// ```
    /// 1,048,576 bytes     → "1 MB"
    /// 157,286,400 bytes   → "150 MB"
    /// 1,073,741,824 bytes → "1 GB"
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// fileSizeLabel.text = "size: \(videoFile.totalFileSizeString)"
    /// // output: "size: 150 MB"
    /// ```
    var totalFileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalFileSize))
    }

    /// @brief Basic filename (basePathfrom extract)
    /// @return filename (YYYY_MM_DD_HH_MM_SS)
    ///
    /// Base filename (extracted from basePath)
    ///
    /// Basic filename. (basePathfrom extract)
    ///
    /// **extract :**
    /// - lastPathComponent: path  portion
    /// - "normal/2025_01_10_09_00_00" → "2025_01_10_09_00_00"
    ///
    /// **filename format:**
    /// - YYYY_MM_DD_HH_MM_SS
    /// - example: 2025_01_10_09_00_00 (2025-01-10 09:00:00)
    ///
    /// **use example:**
    /// ```swift
    /// print(videoFile.baseFilename)  // "2025_01_10_09_00_00"
    ///
    /// // File search
    /// let searchTerm = "2025_01_10"
    /// if videoFile.baseFilename.contains(searchTerm) {
    ///     print("2025-01-10 recording File")
    /// }
    /// ```
    var baseFilename: String {
        return (basePath as NSString).lastPathComponent
    }

    /// @brief Duration string (HH:MM:SS)
    /// @return "H:MM:SS" also "M:SS" format
    ///
    /// Duration as formatted string (HH:MM:SS)
    ///
    /// Duration HH:MM:SS format string return.
    ///
    /// **format :**
    /// - 1time or more: "H:MM:SS" (example: "1:05:30")
    /// - 1time less than: "M:SS" (example: "1:30")
    ///
    /// **calculate anding:**
    /// ```swift
    /// duration = 3665second (1time 1 minute 5second)
    ///
    /// hours = 3665 / 3600 = 1
    /// minutes = (3665 % 3600) / 60 = 1065 / 60 = 17
    /// seconds = 3665 % 60 = 45
    ///
    /// and: "1:17:45"
    /// ```
    ///
    /// **format string:**
    /// - %d: ingnumber (time, minute)
    /// - %02d: 2er ingnumber,  0  (minute, second)
    /// - example: minutes=5 → "%02d" → "05"
    ///
    /// **use example:**
    /// ```swift
    /// durationLabel.text = videoFile.durationString
    /// // output: "1:00" (1 minute) also "1:05:30" (1time 5minute 30second)
    ///
    /// //  time display
    /// let remaining = duration - currentTime
    /// let remainingString = formatDuration(remaining)
    /// ```
    var durationString: String {
        // time, minute, second calculate
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        // 1time or more: "H:MM:SS"
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            // 1time less than: "M:SS"
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// @brief timestamp string (date+time)
    /// @return date time formated string
    ///
    /// Timestamp as formatted string
    ///
    /// timestamp date+time format string return.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .medium (example: "2025. 1. 10.")
    /// - timeStyle: .medium (example: "AM 9:00:00")
    ///
    /// **:**
    /// -   use
    /// - one: "2025. 1. 10. AM 9:00:00"
    /// - : "Jan 10, 2025 at 9:00:00 AM"
    ///
    /// **use example:**
    /// ```swift
    /// timestampLabel.text = videoFile.timestampString
    /// // output: "2025. 1. 10. AM 9:00:00"
    /// ```
    var timestampString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    /// @brief date string (dateonly)
    /// @return date formated string
    ///
    /// Short timestamp (date only)
    ///
    /// dateonly includeha short timestamp.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .medium (example: "2025. 1. 10.")
    /// - timeStyle: .none (time exclude)
    ///
    /// **use example:**
    /// ```swift
    /// dateLabel.text = videoFile.dateString
    /// // output: "2025. 1. 10."
    ///
    /// // dateeach 
    /// let grouped = Dictionary(grouping: videoFiles) { $0.dateString }
    /// ```
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: timestamp)
    }

    /// @brief time string (timeonly)
    /// @return time formated string
    ///
    /// Short timestamp (time only)
    ///
    /// timeonly includeha short timestamp.
    ///
    /// **DateFormatter:**
    /// - dateStyle: .none (date exclude)
    /// - timeStyle: .short (example: "AM 9:00")
    ///
    /// **use example:**
    /// ```swift
    /// timeLabel.text = videoFile.timeString
    /// // output: "AM 9:00"
    ///
    /// //  date File time display
    /// for file in todayFiles {
    ///     print("\(file.timeString): \(file.eventType.displayName)")
    /// }
    /// ```
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    // MARK: - Metadata Access

    /// @brief GPS data availability check
    /// @return GPS data if available true
    ///
    /// Check if video has GPS data
    ///
    /// GPS data exists check.
    ///
    /// **aboveing pattern:**
    /// - metadata.hasGPSData aboveing
    /// - VideoFile  implementationha  VideoMetadata aboveing
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.hasGPSData {
    ///     showMapView()
    /// }
    /// ```
    var hasGPSData: Bool {
        return metadata.hasGPSData
    }

    /// @brief G-sensor data availability check
    /// @return G-sensor data if available true
    ///
    /// Check if video has G-Sensor data
    ///
    /// G-sensor data exists check.
    ///
    /// **aboveing pattern:**
    /// - metadata.hasAccelerationData aboveing
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.hasAccelerationData {
    ///     showGForceGraph()
    /// }
    /// ```
    var hasAccelerationData: Bool {
        return metadata.hasAccelerationData
    }

    /// @brief Impact events  whether check
    /// @return Impact events if available true
    ///
    /// Check if video contains impact events
    ///
    /// Impact events exists check.
    ///
    /// **aboveing pattern:**
    /// - metadata.hasImpactEvents aboveing
    /// - 2.5G or more impact one if available true
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.hasImpactEvents {
    ///     warningBadge.isHidden = false
    ///     warningBadge.text = "⚠️"
    /// }
    /// ```
    var hasImpactEvents: Bool {
        return metadata.hasImpactEvents
    }

    /// @brief detectioned Impact events count
    /// @return Impact events count
    ///
    /// Number of impact events detected
    ///
    /// detectioned Impact events count.
    ///
    /// **aboveing pattern:**
    /// - metadata.impactEvents.count aboveing
    /// - 2.5G or more impact count
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.impactEventCount > 0 {
    ///     impactLabel.text = "impact \(videoFile.impactEventCount)times"
    /// }
    /// ```
    var impactEventCount: Int {
        return metadata.impactEvents.count
    }

    // MARK: - Validation

    /// @brief video file valid validation
    /// @return minimum 1 channels  all channels validha true
    ///
    /// Check if video file is valid (has at least one channel)
    ///
    /// video file validone check.
    ///
    /// **valid condition:**
    /// 1. channels.isEmpty == false (channels one or more)
    /// 2. channels.allSatisfy { $0.isValid } (all channels valid)
    ///
    /// **allSatisfy method:**
    /// - array all  condition onlyha true
    /// - one ha false
    /// - empty array true return (vacuous truth)
    ///
    /// ** AND (&&):**
    /// -  condition  true true
    /// - channels  + all channels valid
    ///
    /// **use example:**
    /// ```swift
    /// if videoFile.isValid {
    ///     // validone File
    ///     enablePlayButton()
    /// } else {
    ///     // ed File
    ///     showError("File validha ")
    /// }
    ///
    /// // validone Fileonly filterring
    /// let validFiles = videoFiles.filter { $0.isValid }
    /// ```
    var isValid: Bool {
        return !channels.isEmpty && channels.allSatisfy { $0.isValid }
    }

    /// @brief video playback possible whether check
    /// @return validha corrupted uh true
    ///
    /// Check if video is playable (valid and not corrupted)
    ///
    /// video playback possibleone check.
    ///
    /// **playback possible condition:**
    /// 1. isValid == true (validone File)
    /// 2. isCorrupted == false (corrupted not)
    ///
    /// ** AND (&&):**
    /// -   true playback possible
    /// - validhaonly corrupteded File: playback 
    /// - validha corrupted not ed: playback possible ✓
    ///
    /// **use example:**
    /// ```swift
    /// playButton.isEnabled = videoFile.isPlayable
    ///
    /// if !videoFile.isPlayable {
    ///     if !videoFile.isValid {
    ///         showError("File validha ")
    ///     } else if videoFile.isCorrupted {
    ///         showError("File corrupted")
    ///     }
    /// }
    ///
    /// // playback possibleone Fileonly filterring
    /// let playableFiles = videoFiles.filter { $0.isPlayable }
    /// ```
    var isPlayable: Bool {
        return isValid && !isCorrupted
    }

    // MARK: - Mutations (return new instance)

    /// @brief Favorite status change (Immutable update)
    /// @param isFavorite new Favorite status
    /// @return new VideoFile instance
    ///
    /// Create a copy with updated favorite status
    /// - Parameter isFavorite: New favorite status
    /// - Returns: New VideoFile instance
    ///
    /// Favorite status changeone new instance create.
    ///
    /// **Immutable update pattern:**
    /// - struct immutable (immutable)
    /// - existing instance numberingha  new instance create
    /// - original change not
    ///
    /// ** immutablein?**
    /// 1. thread safe (Thread safety)
    /// 2. prediction possibility (Predictability)
    /// 3. SwiftUI  (State management)
    ///
    /// **operation :**
    /// ```swift
    /// let file1 = VideoFile(..., isFavorite: false)
    /// let file2 = file1.withFavorite(true)
    ///
    /// file1.isFavorite  // false (change not ed)
    /// file2.isFavorite  // true  (new instance)
    /// ```
    ///
    /// **SwiftUI integration:**
    /// ```swift
    /// @State private var videoFile: VideoFile = ...
    ///
    /// Button("Toggle Favorite") {
    ///     // SwiftUI automaticuh view update
    ///     videoFile = videoFile.withFavorite(!videoFile.isFavorite)
    /// }
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// // Favorite Add
    /// let favoriteFile = videoFile.withFavorite(true)
    ///
    /// // Favorite 
    /// let toggled = videoFile.withFavorite(!videoFile.isFavorite)
    ///
    /// // arrayfrom update
    /// videoFiles[index] = videoFiles[index].withFavorite(true)
    /// ```
    func withFavorite(_ isFavorite: Bool) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// @brief Notes change (Immutable update)
    /// @param notes new Notes 
    /// @return new VideoFile instance
    ///
    /// Create a copy with updated notes
    /// - Parameter notes: New notes text
    /// - Returns: New VideoFile instance
    ///
    /// Notes changeone new instance create.
    ///
    /// **Immutable update pattern:**
    /// - withFavorite(_:) sameone pattern
    /// - Notesonly change,  
    ///
    /// **use example:**
    /// ```swift
    /// // Notes Add
    /// let notedFile = videoFile.withNotes("Beautiful sunset")
    ///
    /// // Notes numbering
    /// let updatedFile = videoFile.withNotes("Updated: Beautiful sunset drive")
    ///
    /// // Notes 
    /// let clearedFile = videoFile.withNotes(nil)
    ///
    /// // useer  half
    /// let newFile = videoFile.withNotes(notesTextField.text)
    /// ```
    func withNotes(_ notes: String?) -> VideoFile {
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }

    /// @brief channel enabled status change (Immutable update)
    /// @param position camera abovetion
    /// @param enabled new enabled status
    /// @return new VideoFile instance
    ///
    /// Create a copy with enabled/disabled channel
    /// - Parameters:
    ///   - position: Camera position
    ///   - enabled: New enabled status
    /// - Returns: New VideoFile instance
    ///
    /// specific channel enabled status changeone new instance create.
    ///
    /// **one update:**
    /// - ed structure update (channels array )
    /// - specific channelonly numbering,  
    ///
    /// **:**
    /// 1. channels array mapuh iterate
    /// 2. corresponding position channel 
    /// 3. corresponding channelonly new channelInfo create (isEnabled change)
    /// 4.  channel  return
    /// 5. updateed channels new VideoFile create
    ///
    /// **map operation:**
    /// ```swift
    /// channels.map { channel -> channelInfo in
    ///     if channel.position == position {
    ///         //  channelonly numbering
    ///         return channelInfo(..., isEnabled: enabled)
    ///     }
    ///     //  
    ///     return channel
    /// }
    /// ```
    ///
    /// **use example:**
    /// ```swift
    /// // Rear Camera 
    /// let hiddenRear = videoFile.withchannel(.rear, enabled: false)
    ///
    /// // Interior camera display
    /// let shownInterior = videoFile.withchannel(.interior, enabled: true)
    ///
    /// // channel 
    /// if let rear = videoFile.rearchannel {
    ///     let toggled = videoFile.withchannel(.rear, enabled: !rear.isEnabled)
    /// }
    ///
    /// // UI  
    /// @objc func toggleRearCamera() {
    ///     videoFile = videoFile.withchannel(.rear, enabled: !videoFile.rearchannel!.isEnabled)
    /// }
    /// ```
    func withchannel(_ position: CameraPosition, enabled: Bool) -> VideoFile {
        // channel array iterateha specific channelonly numbering
        let updatedchannels = channels.map { channel -> channelInfo in
            if channel.position == position {
                // corresponding channel: isEnabledonly changeone new instance create
                return channelInfo(
                    id: channel.id,
                    position: channel.position,
                    filePath: channel.filePath,
                    width: channel.width,
                    height: channel.height,
                    frameRate: channel.frameRate,
                    bitrate: channel.bitrate,
                    codec: channel.codec,
                    audioCodec: channel.audioCodec,
                    isEnabled: enabled,
                    fileSize: channel.fileSize
                )
            }
            // other channel:  return
            return channel
        }

        // updateed channels new VideoFile create
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: updatedchannels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,
            notes: notes,
            isCorrupted: isCorrupted
        )
    }
}

// MARK: - Sample Data

/*
 ───────────────────────────────────────────────────────────────────────────────
 Sample Data - Sample video file data
 ───────────────────────────────────────────────────────────────────────────────

 test, SwiftUI view,   UI check aboveone Sample data.

 【normal Sample】

 1. normal5channel: 5channel Normal recording
 - all channel include (Front, Rear, Left, Right, Interior)
 - complete metadata (GPS + G-Sensor)
 - 5channel blackbox test

 2. impact2channel: 2channel Impact events
 - Front + Rear
 - impact metadata include
 - accident video simulation

 3. parking1channel: 1channel Parking mode
 - Frontonly
 - GPSonly (Sensor none)
 - Parking mode test

 4. favoriteRecording: Favorite recording
 - isFavorite = true
 - notes include
 - useer  test

 5. corruptedFile: corrupteded File
 - isCorrupted = true
 - empty metadata
 -  processing test

 【 test File】

  video file useha test data:
 - comma2k19Test: Comma.ai erdriving data (48second)
 - test360p, test720p, test1080p: one resolution test
 - multichannel4Test: 4channel multiview test

 【Usage Example】

 SwiftUI view:
 ```swift
 struct VideoFileView_Previews: PreviewProvider {
 static var previews: some View {
 Group {
 VideoFileView(file: .normal5channel)
 .previewDisplayName("5 channels")

 VideoFileView(file: .impact2channel)
 .previewDisplayName("Impact Event")

 VideoFileView(file: .corruptedFile)
 .previewDisplayName("Corrupted")
 }
 }
 }
 ```

 unit test:
 ```swift
 func testMultichannel() {
 let file = VideoFile.normal5channel
 XCTAssertEqual(file.channelCount, 5)
 XCTAssertTrue(file.isMultichannel)
 XCTAssertTrue(file.isValid)
 }

 func testImpactDetection() {
 let file = VideoFile.impact2channel
 XCTAssertTrue(file.hasImpactEvents)
 XCTAssertGreaterThan(file.impactEventCount, 0)
 }
 ```

 ───────────────────────────────────────────────────────────────────────────────
 */

extension VideoFile {
    /// Sample normal recording (5 channels)
    ///
    /// 5channel Normal recording Sample.
    ///
    /// **include channel:**
    /// - Front (Full HD, 100 MB)
    /// - Rear (HD, 50 MB)
    /// - Left (HD, 50 MB)
    /// - Right (HD, 50 MB)
    /// - Interior (HD, 50 MB)
    /// - total size: 300 MB
    ///
    /// **metadata:**
    /// - GPS: 60 points (1 minute)
    /// - G-Sensor: 600 points (1 minute, 10Hz)
    /// - device information: BlackVue DR900X-2CH
    static let normal5channel = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 60.0,
        channels: channelInfo.allSamplechannels,
        metadata: VideoMetadata.sample,
        basePath: "normal/2025_01_10_09_00_00"
    )

    /// Sample impact recording (2 channels)
    ///
    /// 2channel Impact events Sample.
    ///
    /// **include channel:**
    /// - Front (Full HD, 100 MB)
    /// - Rear (HD, 50 MB)
    /// - total size: 150 MB
    ///
    /// **metadata:**
    /// - Impact events include (3.5G)
    /// - short Duration (30second)
    /// - impact  15second
    static let impact2channel = VideoFile(
        timestamp: Date().addingTimeInterval(-3600),
        eventType: .impact,
        duration: 30.0,
        channels: [channelInfo.frontHD, channelInfo.rearHD],
        metadata: VideoMetadata.withImpact,
        basePath: "event/2025_01_10_10_30_15"
    )

    /// Sample parking recording (1 channel)
    ///
    /// 1channel Parking mode Sample.
    ///
    /// **include channel:**
    /// - Front (Full HD, 100 MB)
    ///
    /// **metadata:**
    /// - GPSonly (Sensor none)
    /// - short Duration (10second)
    /// - ing detection  recording
    static let parking1channel = VideoFile(
        timestamp: Date().addingTimeInterval(-7200),
        eventType: .parking,
        duration: 10.0,
        channels: [channelInfo.frontHD],
        metadata: VideoMetadata.gpsOnly,
        basePath: "parking/2025_01_10_18_00_00"
    )

    /// Sample favorite recording
    ///
    /// Favorite recording Sample.
    ///
    /// **:**
    /// - isFavorite = true
    /// - notes include ("Beautiful sunset drive")
    /// - Manual recording (EventType.manual)
    /// -  Duration (2minute)
    static let favoriteRecording = VideoFile(
        timestamp: Date().addingTimeInterval(-10800),
        eventType: .manual,
        duration: 120.0,
        channels: [channelInfo.frontHD, channelInfo.rearHD],
        metadata: VideoMetadata.sample,
        basePath: "manual/2025_01_10_15_00_00",
        isFavorite: true,
        notes: "Beautiful sunset drive"
    )

    /// Sample corrupted file
    ///
    /// corrupteded File Sample.
    ///
    /// **:**
    /// - isCorrupted = true
    /// - duration = 0 (playback )
    /// - empty metadata
    /// -  processing test
    static let corruptedFile = VideoFile(
        timestamp: Date().addingTimeInterval(-14400),
        eventType: .normal,
        duration: 0.0,
        channels: [channelInfo.frontHD],
        metadata: VideoMetadata.sample,
        basePath: "normal/2025_01_10_12_00_00",
        isCorrupted: true
    )

    /// Array of all sample files
    ///
    /// all Sample File array.
    ///
    /// **include Sample:**
    /// - normal5channel: 5channel normal
    /// - impact2channel: 2channel impact
    /// - parking1channel: 1channel parking
    /// - favoriteRecording: Favorite
    /// - corruptedFile: corrupted File
    ///
    /// **use example:**
    /// ```swift
    /// List(VideoFile.allSamples) { file in
    ///     VideoFileRow(file: file)
    /// }
    /// ```
    static let allSamples: [VideoFile] = [
        normal5channel,
        impact2channel,
        parking1channel,
        favoriteRecording,
        corruptedFile
    ]

    // MARK: - Test Data with Real Files

    /// Test video: comma2k19 sample with sensor data
    ///
    /// Comma.ai comma2k19 data Sample.
    ///
    /// **File information:**
    /// - resolution: 1164×874 (approximately 1.2:1)
    /// - frame : 25 fps
    /// - Duration: 48second
    /// - size: 15.4 MB
    /// - : erdriving nine data
    static let comma2k19Test = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 48.0,
        channels: [
            channelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            )
        ],
        metadata: VideoMetadata.sample,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample"
    )

    /// Test video: 360p basic test
    ///
    /// 360p Basic test video.
    ///
    /// **File information:**
    /// - resolution: 640×360 (SD less than)
    /// - frame : 30 fps
    /// - Duration: 10second
    /// - size: 991 KB (approximately 1 MB)
    static let test360p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            channelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_360p.mp4",
                width: 640,
                height: 360,
                frameRate: 30.0,
                bitrate: 792_000,
                codec: "h264",
                fileSize: 991_232,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.sample,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_360p"
    )

    /// Test video: 720p HD test
    ///
    /// 720p HD test video.
    ///
    /// **File information:**
    /// - resolution: 1280×720 (HD)
    /// - frame : 30 fps
    /// - Duration: 10second
    /// - size: 5 MB
    static let test720p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            channelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_720p.mp4",
                width: 1280,
                height: 720,
                frameRate: 30.0,
                bitrate: 3_900_000,
                codec: "h264",
                fileSize: 5_033_984,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.sample,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/big_buck_bunny_720p"
    )

    /// Test video: 1080p high quality test
    ///
    /// 1080p Full HD  test video.
    ///
    /// **File information:**
    /// - resolution: 1920×1080 (Full HD)
    /// - frame : 60 fps (Advanced)
    /// - Duration: 10second
    /// - size: 10 MB
    static let test1080p = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 10.0,
        channels: [
            channelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/sample_1080p.mp4",
                width: 1920,
                height: 1080,
                frameRate: 60.0,
                bitrate: 8_300_000,
                codec: "h264",
                fileSize: 10_485_760,
                duration: 10.0
            )
        ],
        metadata: VideoMetadata.sample,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/sample_1080p"
    )

    /// Test video: Multi-channel simulation (4 channels using comma2k19)
    ///
    /// 4channel multiview simulation test.
    ///
    /// **File information:**
    /// - 4channel: Front, Rear, Left, Right
    /// - all channel same video (comma2k19) use
    /// - total size: approximately 60 MB (4 × 15 MB)
    /// - multi channel UI test
    static let multichannel4Test = VideoFile(
        timestamp: Date(),
        eventType: .normal,
        duration: 48.0,
        channels: [
            channelInfo(
                position: .front,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            channelInfo(
                position: .rear,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            channelInfo(
                position: .left,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            ),
            channelInfo(
                position: .right,
                filePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_sample.mp4",
                width: 1164,
                height: 874,
                frameRate: 25.0,
                bitrate: 2_570_000,
                codec: "h264",
                fileSize: 15_439_382,
                duration: 48.0
            )
        ],
        metadata: VideoMetadata.sample,
        basePath: "/Users/dongcheolshin/Downloads/blackbox_test_data/comma2k19_multichannel"
    )

    /// All real test files
    ///
    /// all  test File array.
    ///
    /// **include test:**
    /// - multichannel4Test: 4channel multiview ( , er use)
    /// - comma2k19Test: erdriving data
    /// - test1080p: Full HD 60fps
    /// - test720p: HD 30fps
    /// - test360p: resolution
    ///
    /// **use example:**
    /// ```swift
    /// //   test File 
    /// List(VideoFile.allTestFiles) { file in
    ///     Button(file.basePath) {
    ///         playVideo(file)
    ///     }
    /// }
    /// ```
    static let allTestFiles: [VideoFile] = [
        multichannel4Test,  // Multi-channel test first for easy access
        comma2k19Test,
        test1080p,
        test720p,
        test360p
    ]
}
