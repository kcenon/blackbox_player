/// @file VideoFileLoader.swift
/// @brief Service for loading video file information and creating VideoFile models
/// @author BlackboxPlayer Development Team
/// @details
/// This file VideoFileGroup (file ) VideoFile (  )to Convert defines
/// Each channel      VideoFile Create.

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                   VideoFileLoader - video file toMore                      ║
 ║                                                                              ║
 ║  :                                                                        ║
 ║    VideoFileGroup (file ) VideoFile (  )to Convert.        ║
 ║    Each channel      VideoFile Create.  ║
 ║                                                                              ║
 ║   :                                                                   ║
 ║    • VideoFileGroup → VideoFile Convert                                         ║
 ║    • Each channel (camera) video                                          ║
 ║    • GPS/speed  Loading                                              ║
 ║    • file                                                             ║
 ║    •  Process (Multiple file Simultaneous Loading)                                           ║
 ║                                                                              ║
 ║   :                                                                 ║
 ║    ```                                                                       ║
 ║    FileScanner ( )                                                ║
 ║        ↓                                                                     ║
 ║    VideoFileGroup[] ( file)                                          ║
 ║        ↓                                                                     ║
 ║    VideoFileLoader ( ) ← MetadataExtractor (GPS/)                 ║
 ║        ↓                                                                     ║
 ║    VideoFile[] (  )                                              ║
 ║        ↓                                                                     ║
 ║    UI (file  )                                                        ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ║   file :                                                           ║
 ║    ```                                                                       ║
 ║    /normal/                                                                  ║
 ║      2025_01_10_09_00_00_F.mp4  (front)                                       ║
 ║      2025_01_10_09_00_00_R.mp4  (rear)                                       ║
 ║      2025_01_10_09_00_00_L.mp4  (left)                                       ║
 ║      2025_01_10_09_00_00_Ri.mp4 (right)                                       ║
 ║      2025_01_10_09_00_00_I.mp4  ()                                       ║
 ║      2025_01_10_09_00_00.gps    (GPS )                                 ║
 ║      2025_01_10_09_00_00.gsensor (speed )                              ║
 ║                                                                              ║
 ║    FileScanner   VideoFileGroupto                           ║
 ║    → VideoFileLoader VideoFileto Convert                                       ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ║  Usage example:                                                                     ║
 ║    ```swift                                                                  ║
 ║    let scanner = FileScanner()                                               ║
 ║    let loader = VideoFileLoader()                                            ║
 ║                                                                              ║
 ║    // 1.                                                          ║
 ║    let groups = try scanner.scanDirectory(folderURL)                         ║
 ║                                                                              ║
 ║    // 2. VideoFileto Convert                                                    ║
 ║    let videoFiles = loader.loadVideoFiles(from: groups)                      ║
 ║                                                                              ║
 ║    // 3. UI                                                              ║
 ║    self.videoFiles = videoFiles                                              ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ VideoFileGroup vs VideoFile                                                  │
 └──────────────────────────────────────────────────────────────────────────────┘

 ┌───────────────────────────────────────────────────────────────────────────┐
 │                                                                        │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ VideoFileGroup ( )                                                 │
 │   • FileScanner Create                                                     │
 │   • file timestampto                                          │
 │   • video   (, frame )                               │
 │   •   (GPS, speed)                                         │
 │   •                                                                │
 │                                                                           │
 │ VideoFile ( )                                                       │
 │   • VideoFileLoader Create                                                 │
 │   • Each channel                                                   │
 │   • video   (, , )                              │
 │   •   (GPS path, G- )                                │
 │   •                                                                │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘

 Convert  Example:

 VideoFileGroup:
 ```
 timestamp: 2025-01-10 09:00:00
 eventType: .normal
 basePath: "/Volumes/SD/normal/"
 files: [
 VideoFileInfo(url: "...F.mp4", position: .front, size: 100MB),
 VideoFileInfo(url: "...R.mp4", position: .rear, size: 100MB)
 ]
 ```

 →  VideoFileLoader Process  →

 VideoFile:
 ```
 id: UUID()
 timestamp: 2025-01-10 09:00:00
 eventType: .normal
 duration: 60.0 seconds
 channels: [
 ChannelInfo(position: .front, width: 1920, height: 1080, ...),
 ChannelInfo(position: .rear, width: 1920, height: 1080, ...)
 ]
 metadata: VideoMetadata(
 gpsPoints: [GPSPoint(), ...],
 accelerationData: [AccelerationData(), ...]
 )
 isCorrupted: false
 ```
 */

import Foundation

// MARK: - VideoFileLoader 

/// @class VideoFileLoader
/// @brief video file   VideoFile  Create 
///
/// @details
///   Next  :
/// 1. VideoFileGroup Each channel(camera)  
/// 2. MetadataExtractorto GPS/G-  Loading
/// 3. All    VideoFile Create
/// 4. file  
///
/// ##  Status:
///  FFmpeg video   Statusis (TODO).
/// to 1920x1080, 30fps, H.264  Use.
///  VideoDecoder Use  video   is.
///
/// ##  :
/// - file count   Loading    
/// -  thread Call :
///   ```swift
///   DispatchQueue.global(qos: .userInitiated).async {
///       let files = loader.loadVideoFiles(from: groups)
///       DispatchQueue.main.async {
///           self.videoFiles = files  // UI Update
///       }
///   }
///   ```
class VideoFileLoader {

    // MARK: - Properties

    /// @var metadataExtractor
    /// @brief   (GPS/G- )
    /// @details
    /// MetadataExtractor  file(.gps, .gsensor)  .
    ///
    /// file Example:
    /// ```
    /// 2025_01_10_09_00_00_F.mp4   ← video file
    /// 2025_01_10_09_00_00.gps     ← GPS  (NMEA 0183 )
    /// 2025_01_10_09_00_00.gsensor ← speed  ()
    /// ```
    ///
    /// Use:
    ///  metadataExtractor instance All file Loading Use.
    ///  newto Create  is.
    private let metadataExtractor: MetadataExtractor

    // MARK: - Initialization

    /// @brief VideoFileLoader Initialize
    ///
    /// @details
    /// MetadataExtractor to Create.
    ///
    /// Usage example:
    /// ```swift
    /// let loader = VideoFileLoader()  //  Initialize
    /// ```
    ///
    ///  :
    ///         exists:
    /// ```swift
    /// init(metadataExtractor: MetadataExtractor = MetadataExtractor()) {
    ///     self.metadataExtractor = metadataExtractor
    /// }
    /// ```
    init() {
        self.metadataExtractor = MetadataExtractor()
    }

    // MARK: - Public Methods

    /// @brief video file  VideoFile Create
    ///
    /// @param group  timestamp  video file 
    /// @return Create VideoFile or nil (Loading failure )
    ///
    /// @details
    ///  to:
    /// 1. Each channel file video   (extractChannelInfo)
    /// 2. front camera  Loading (MetadataExtractor)
    /// 3. VideoFile  Create
    /// 4.   (checkCorruption)
    ///
    /// nil Return :
    /// - group.files 
    /// - All channel   failure
    /// - file  
    ///
    ///  Use :
    /// ```
    /// VideoFileGroup {
    ///   files: [F.mp4, R.mp4]
    /// }
    ///   ↓
    /// extractChannelInfo(F.mp4) → ChannelInfo(front)
    /// extractChannelInfo(R.mp4) → ChannelInfo(rear)
    ///   ↓
    /// metadataExtractor.extract(F.mp4) → VideoMetadata
    ///   ↓
    /// VideoFile {
    ///   channels: [front, rear]
    ///   metadata: VideoMetadata
    /// }
    ///   ↓
    /// checkCorruption() → isCorrupted: false
    ///   ↓
    /// return VideoFile
    /// ```
    ///
    ///  file Process:
    /// file  nil Return .
    ///  isCorrupted=trueto  UI warning .
    func loadVideoFile(from group: VideoFileGroup) -> VideoFile? {
        // 1.   
        // - guard:  failure  early return
        // - nil Return: video file If none VideoFile Create 
        guard !group.files.isEmpty else { return nil }

        // 2. Each channel  
        // - var: array appendto 
        // - [ChannelInfo]: seconds  array
        var channels: [ChannelInfo] = []

        // 3. All file  channel  
        // - for-in: Each fileInfo Traverse
        // - if let: extractChannelInfo nil Return  (failure )
        // - success channel channels array Add
        for fileInfo in group.files {
            if let channelInfo = extractChannelInfo(from: fileInfo) {
                channels.append(channelInfo)
            }
        }

        // 4.   channel  
        // - All channel  failure  nil Return
        guard !channels.isEmpty else { return nil }

        // 5.   
        // - channels.first:   channel (Optional)
        // - ?. : Optional chaining (nil  nil)
        // - ?? 0: nil  0 Use
        //
        // Why   channel?
        // - All channel duration   (synchronization)
        // -     file
        let duration = channels.first?.duration ?? 0

        // 6.   (GPS/speed)
        //
        // :
        // 1. front camera file  (  )
        // 2. front If none   file Use
        //
        // group.files.first { ... }:
        // -      
        // - $0: to    (fileInfo)
        // - $0.position == .front: front camera Check
        let frontChannel = group.files.first { $0.position == .front } ?? group.files.first

        //   
        let metadata: VideoMetadata
        if let frontChannel = frontChannel,  // file 
           let extractedMetadata = metadataExtractor.extractMetadata(from: frontChannel.url.path) {  //  success
            // success:   Use
            metadata = extractedMetadata
        } else {
            // failure:   Use (GPS/speed )
            metadata = VideoMetadata()
        }

        // 7. VideoFile Create
        // - UUID():    Create
        // - All    VideoFile Create
        let videoFile = VideoFile(
            id: UUID(),
            timestamp: group.timestamp,           //  timestamp
            eventType: group.eventType,           //   (normal, impact )
            duration: duration,                   //   channel  
            channels: channels,                   //  All channel 
            metadata: metadata,                   // GPS/speed 
            basePath: group.basePath,             // file  path
            isFavorite: false,                    // seconds:  
            notes: nil,                           // seconds:  
            isCorrupted: false                    //    
        )

        // 8.  
        // - checkCorruption(): VideoFile extension 
        // - file , duration, fileSize  
        let isCorrupted = videoFile.checkCorruption()

        // 9.  isCorrupted=trueto newto Create
        // - Why newto Create? VideoFile struct ()to  
        // - All   isCorrupted trueto 
        if isCorrupted {
            // Return corrupted VideoFile for display with warning
            // UI "⚠️  file"  warning  
            return VideoFile(
                id: videoFile.id,
                timestamp: videoFile.timestamp,
                eventType: videoFile.eventType,
                duration: videoFile.duration,
                channels: videoFile.channels,
                metadata: videoFile.metadata,
                basePath: videoFile.basePath,
                isFavorite: false,
                notes: nil,
                isCorrupted: true  //  !
            )
        }

        // 10.  VideoFile Return
        return videoFile
    }

    /// @brief Multiple video file    Loading
    ///
    /// @param groups video file  array
    /// @return VideoFile array (failure  )
    ///
    /// @details
    /// FileScanner  All  VideoFile arrayto Convert.
    ///
    /// compactMap:
    /// compactMap map + filter(nil Remove) is:
    /// ```swift
    /// // map: All  Convert (nil )
    /// let results = groups.map { loadVideoFile(from: $0) }
    /// // results: [VideoFile?, VideoFile?, nil, VideoFile?, ...]
    ///
    /// // compactMap: nil Remove + Convert
    /// let results = groups.compactMap { loadVideoFile(from: $0) }
    /// // results: [VideoFile, VideoFile, VideoFile, ...]  (nil !)
    /// ```
    ///
    /// Usage example:
    /// ```swift
    /// let scanner = FileScanner()
    /// let loader = VideoFileLoader()
    ///
    /// // 100  
    /// let groups = try scanner.scanDirectory(folder)  // [VideoFileGroup]
    ///
    /// // 95 success, 5 failure (nil) 
    /// let videoFiles = loader.loadVideoFiles(from: groups)
    /// // videoFiles 95  (to nil Remove)
    /// ```
    ///
    /// failure Process:
    ///   Loading failure  .
    /// to     :
    /// ```swift
    /// groups.compactMap { group in
    ///     if let videoFile = loadVideoFile(from: group) {
    ///         return videoFile
    ///     } else {
    ///         print("Failed to load group: \(group.timestamp)")
    ///         return nil
    ///     }
    /// }
    /// ```
    func loadVideoFiles(from groups: [VideoFileGroup]) -> [VideoFile] {
        // compactMap { ... }:
        // 1. Each group  loadVideoFile(from:) Call
        // 2.  nil   array 
        // 3. [VideoFile?] → [VideoFile] Convert
        //
        // $0:
        // - to   ( ) 
        // -  VideoFileGroup 
        return groups.compactMap { loadVideoFile(from: $0) }
    }

    /// @brief file  video file  Check
    ///
    /// @param url  file URL
    /// @return true  video file
    ///
    /// @details
    ///  decoding  and file   .
    ///
    /// :
    ///   file  .
    /// to   Check .
    /// file  true Return  exists.
    ///
    /// Use :
    /// ```swift
    /// //    
    /// func dragged(_ files: [URL]) {
    ///     let validFiles = files.filter { loader.isValidVideoFile($0) }
    ///     if validFiles.isEmpty {
    ///         showAlert("video file ")
    ///     }
    /// }
    /// ```
    ///
    ///  :
    /// - mp4:   (H.264 + AAC)
    /// - mov: Apple QuickTime
    /// - avi:   (Windows)
    /// - mkv: Matroska ( )
    func isValidVideoFile(_ url: URL) -> Bool {
        // 1. file     Convert
        // - url.pathExtension: "video.MP4" → "MP4"
        // - .lowercased(): "MP4" → "mp4"
        let fileExtension = url.pathExtension.lowercased()

        // 2.   
        // - let:  array ( )
        // - [String]: string array
        let validExtensions = ["mp4", "mov", "avi", "mkv"]

        // 3.      
        // - &&:  AND 
        // -    true  true
        //
        // FileManager.default.fileExists(atPath:):
        // - file to  Check
        // - url.path: URL → String path Convert
        //
        // validExtensions.contains(fileExtension):
        // -    Check
        // - "mp4" in ["mp4", "mov", "avi", "mkv"] → true
        return FileManager.default.fileExists(atPath: url.path) &&
            validExtensions.contains(fileExtension)
    }

    // MARK: - Private Methods

    /// @brief VideoFileInfo ChannelInfo  ()
    ///
    /// @param fileInfo file   (URL, position, size)
    /// @return  ChannelInfo or nil (failure )
    ///
    /// @details
    ///  video file   .
    ///
    /// TODO - FFmpeg  :
    ///    Use:
    /// - 1920x1080 (Full HD)
    /// - 30fps
    /// - H.264 
    /// - 60seconds 
    ///
    ///  VideoDecoder Use   :
    /// ```swift
    /// let decoder = VideoDecoder(filePath: filePath)
    /// try decoder.initialize()
    /// let videoInfo = decoder.videoInfo  // width, height, fps 
    /// let duration = decoder.getDuration()
    /// ```
    ///
    /// failure :
    /// 1. file  
    /// 2.   
    /// 3. FFmpeg decoding failure ()
    private func extractChannelInfo(from fileInfo: VideoFileInfo) -> ChannelInfo? {
        // 1. file path 
        // - url.path: URL String pathto Convert
        // - Example: file:///path/to/video.mp4 → /path/to/video.mp4
        let filePath = fileInfo.url.path

        // 2. file  Check
        // - guard:  failure  early return
        // - FileManager: file   
        // - .default:  instance
        // - fileExists(atPath:): file/  
        guard FileManager.default.fileExists(atPath: filePath) else {
            // print:  warning  output
            // - 
            // - to to  Use 
            print("Warning: File does not exist: \(filePath)")
            return nil  // ChannelInfo Create 
        }

        // 3.   Check
        // - isReadableFile(atPath:):   Check
        // -  If none decoding 
        guard FileManager.default.isReadableFile(atPath: filePath) else {
            print("Warning: File is not readable: \(filePath)")
            return nil
        }

        // 4. VideoDecoder Use  video  
        // - VideoDecoder: FFmpeg  video  
        // - videoInfo: , frame,  
        // - getDuration():   
        // - error   Use (fallback)

        // video   
        let decoder = VideoDecoder(filePath: filePath)
        var width = 1920                    // : Full HD to
        var height = 1080                   // : Full HD to
        var frameRate = 30.0                // : 30 frame/seconds
        var bitrate: Int? = nil             //  ( success  Set up)
        var codec = "h264"                  // : H.264 
        var audioCodec: String? = "aac"     // : AAC audio 
        var duration: TimeInterval = 60.0   // : 1

        do {
            // VideoDecoder Initialize  file 
            try decoder.initialize()

            // video   
            if let videoInfo = decoder.videoInfo {
                width = videoInfo.width
                height = videoInfo.height
                frameRate = videoInfo.frameRate
                codec = videoInfo.codecName
                bitrate = videoInfo.bitrate > 0 ? videoInfo.bitrate : nil
            }

            //   
            if let extractedDuration = decoder.getDuration() {
                duration = extractedDuration
            }

            // audio    (optional)
            if let audio = decoder.audioInfo {
                audioCodec = audio.codecName
            }
        } catch {
            // decoding failure   Use
            // - file      
            // - warning  output  to ChannelInfo Create
            print("Warning: Failed to decode video info for \(filePath): \(error)")
            print("Using default values: 1920x1080, 30fps, H.264")
        }

        // 5. ChannelInfo Create  Return
        // - UUID(): Each channel  ID Create
        // - fileInfo  : position, fileSize
        // - VideoDecoder  : width, height, frameRate, codec, duration 
        return ChannelInfo(
            id: UUID(),
            position: fileInfo.position,      // camera  (front, rear )
            filePath: filePath,               // video file  path
            width: width,                     // video to 
            height: height,                   // video to 
            frameRate: frameRate,             // frame  (fps)
            bitrate: bitrate,                 //  (bps) - optional
            codec: codec,                     // video  
            audioCodec: audioCodec,           // audio   - optional
            isEnabled: true,                  // to 
            fileSize: fileInfo.fileSize,      // file size (bytes)
            duration: duration                //   (seconds)
        )
    }
}

// MARK: - VideoFile Extension

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Extension?                                                                │
 └──────────────────────────────────────────────────────────────────────────────┘

 Extension   newto  Add Swift  is.

 :
 1.      Add 
 2. struct, class, enum, protocol   
 3. , Calculate to, initializer Add 
 4. Save to Add  ()

 Why  Extension Use?
 - VideoFile Models  
 - checkCorruption() Loading   (Services )
 - toto    

 :
 ```swift
 // VideoFile  (Models/VideoFile.swift)
 struct VideoFile {
 let id: UUID
 let timestamp: Date
 // ...  to
 }

 // Extensionto Add (Services/VideoFileLoader.swift)
 extension VideoFile {
 func checkCorruption() -> Bool {
 // Loading  to
 }
 }
 ```
 */

extension VideoFile {

    /// @brief video file  Check
    ///
    /// @return true , false 
    ///
    /// @details
    /// Next  :
    /// 1. All channel file 
    /// 2.    (> 0)
    /// 3. All channel file size 0 
    ///
    ///  :
    ///    .
    /// More   ( Check, frame decoding )
    ///     .
    ///
    ///  :
    /// 1.     → file 
    /// 2. SD   → file  
    /// 3. file   →  
    /// 4.  Delete →  channel 
    ///
    /// UI :
    /// ```swift
    /// if videoFile.isCorrupted {
    ///     Text(videoFile.name)
    ///         .foregroundColor(.red)
    ///     Image(systemName: "exclamationmark.triangle")
    ///         .foregroundColor(.orange)
    /// }
    /// ```
    func checkCorruption() -> Bool {
        // 1. All channel file  Check
        // - for-in: channels array Traverse
        // - FileManager.default.fileExists: file  Check
        // - !:  (exists false true)
        // - return true:  If none  "" Return
        for channel in channels {
            if !FileManager.default.fileExists(atPath: channel.filePath) {
                return true  // file  = 
            }
        }

        // 2.    
        // - duration <= 0: 0seconds  
        // - : file Create failure,  
        if duration <= 0 {
            return true  //  duration = 
        }

        // 3. All channel file size Check
        //
        // allSatisfy  :
        // - array All    
        // - to: { $0.fileSize == 0 }
        //   - $0: Each channel (ChannelInfo)
        //   - .fileSize: file size (bytes)
        //   - == 0: size 0
        // - :  0 true,  0  false
        //
        // Example:
        // ```swift
        // let sizes = [0, 0, 0]
        // sizes.allSatisfy { $0 == 0 }  // true ( 0)
        //
        // let sizes = [0, 100, 0]
        // sizes.allSatisfy { $0 == 0 }  // false (100 0 )
        // ```
        //
        // Why   ?
        // - All channel 0 bytes = file 
        // -  failure or file Create     
        if channels.allSatisfy({ $0.fileSize == 0 }) {
            return true  // All file  = 
        }

        // 4. All   = 
        return false
    }
}

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                            Add                                         ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 1. Optional Chaining  :
 ```swift
 //  Optional Process
 if let first = channels.first {
 if let duration = first.duration {
 print(duration)
 }
 }

 // Optional Chainingto 
 let duration = channels.first?.duration ?? 0
 //             └─────┬──────┘ └──┬──┘
 //                   │           └─ nil 0 Use
 //                   └─ first nil  nil
 ```

 2.   :
 ```swift
 let numbers = [1, 2, 3, 4, 5]

 // map: All  Convert
 numbers.map { $0 * 2 }           // [2, 4, 6, 8, 10]

 // filter:   
 numbers.filter { $0 > 2 }        // [3, 4, 5]

 // reduce:  to 
 numbers.reduce(0, +)             // 15

 // compactMap: Convert + nil Remove
 ["1", "2", "a"].compactMap { Int($0) }  // [1, 2]

 // allSatisfy: All   ?
 numbers.allSatisfy { $0 > 0 }    // true

 // contains: Specific  ?
 numbers.contains(3)              // true
 ```

 3. Guard vs If-Let:
 ```swift
 // guard: early return  ()
 guard let user = getUser() else {
 print("No user")
 return
 }
 // user Use  ( )
 print(user.name)

 // if-let:  
 if let user = getUser() {
 // user Use (if  )
 print(user.name)
 } else {
 print("No user")
 }
 // user Use  ( )
 ```

 4. FileManager  :
 ```swift
 let fm = FileManager.default

 //  Check
 fm.fileExists(atPath: path)

 //  Check
 var isDirectory: ObjCBool = false
 fm.fileExists(atPath: path, isDirectory: &isDirectory)

 // / 
 fm.isReadableFile(atPath: path)
 fm.isWritableFile(atPath: path)

 // file 
 let attrs = try fm.attributesOfItem(atPath: path)
 let fileSize = attrs[.size] as? UInt64

 // file Create/Delete
 fm.createFile(atPath: path, contents: data)
 try fm.removeItem(atPath: path)

 //  
 let contents = try fm.contentsOfDirectory(atPath: path)
 ```
 */
