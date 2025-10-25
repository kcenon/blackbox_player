/// @file VideoChannel.swift
/// @brief Video channel for multi-channel synchronized playback
/// @author BlackboxPlayer Development Team
/// @details
///  channel synchronization    video channel is.
///
/// ## channel(Channel)?
/// -   Multiple  camera exists (front, rear, left, right, )
/// - Each camera  to decoding   "channel"is
/// - Example: 4channel  = front channel + rear channel + left channel + right channel
///
/// ## Key features:
/// 1. ** decoding**: Each channel  VideoDecoder 
/// 2. **frame buffer**: decoding frame buffer Save   
/// 3. **synchronization **:  channel      
/// 4. ** decoding**:  thread decoding UI  
///
/// ## buffer(Buffer)?
/// -  decoding frame Save  Save
/// -     to   
/// -  decoding speed     
///
/// ## synchronization(Synchronization)?
/// - Multiple channel     
/// - Example: 0.5seconds  front  0.5seconds  rear  Simultaneous 
/// - GPS G-     
///
/// ## Use :
/// ```swift
/// // 1. channel Create
/// let channelInfo = ChannelInfo(
///     position: .front,
///     filePath: "/path/to/front_camera.mp4",
///     displayName: "front camera"
/// )
/// let channel = VideoChannel(channelInfo: channelInfo)
///
/// // 2. Initialize
/// try channel.initialize()
///
/// // 3. decoding Start
/// channel.startDecoding()
///
/// // 4. Specific  frame 
/// if let frame = channel.getFrame(at: 5.0) {
///     print("5seconds  frame: \(frame.frameNumber)")
/// }
///
/// // 5. buffer Status Check
/// let status = channel.getBufferStatus()
/// print("buffer: \(status.current)/\(status.max) (\(status.fillPercentage * 100)%)")
///
/// // 6. 
/// channel.stop()
/// ```
///
/// ## Thread-safe(Thread Safety):
/// - Multiple thread Simultaneous   
/// - NSLock Use frame buffer 
/// -  thread decoding,  thread UI Update

import Foundation
import Combine

/// @class VideoChannel
/// @brief  channel synchronization    video channel
/// @details Each video channel to decoding buffer,  channel synchronization .
class VideoChannel {
    // MARK: - Properties ()

    /*
     MARK?
     - Xcode  to  
     - // MARK: -  to 
     - Xcode file    to find  
     */

    /// @var channelID
    /// @brief channel  (Channel Identifier)
    /// @details
    /// UUID?
    /// - Universally Unique Identifier (  )
    /// -    ID  (   0)
    /// - : "550e8400-e29b-41d4-a716-446655440000"
    ///
    /// Why ?
    /// - Multiple channel   
    /// - file path     UUID 
    let channelID: UUID

    /// @var channelInfo
    /// @brief channel  (Channel Information)
    /// @details
    /// ChannelInfo  :
    /// - position: camera  (front, rear, left, right, )
    /// - filePath: video file path (Example: "/videos/front_20250112.mp4")
    /// - displayName:    (Example: "front camera")
    ///
    /// let vs var:
    /// - let: ,   Set up  
    /// - var: ,   
    /// - channelInfo letto channel Create   
    let channelInfo: ChannelInfo

    /// @var state
    /// @brief channel Status (Channel State)
    /// @details
    /// @Published?
    /// - Combine frame to 
    /// -   to  
    /// - SwiftUI UI to Update
    ///
    /// Example:
    /// ```swift
    /// channel.$state
    ///     .sink { newState in
    ///         print("Status : \(newState)")
    ///     }
    /// ```
    ///
    /// private(set)?
    /// -  public (   )
    /// -  private (    )
    /// -  state = .idle    
    ///
    /// channel Status :
    /// - .idle: idle Status (   Status)
    /// - .ready: ready completed (More Initialize completed, decoding Start )
    /// - .decoding: decoding  ( frame decoding )
    /// - .completed: completed (file  decoding completed)
    /// - .error:  (decoding  error )
    @Published private(set) var state: ChannelState = .idle

    /// @var currentFrame
    /// @brief  frame (Current Frame)
    /// @details
    /// VideoFrame?
    /// - decoding    frame
    /// - :  , timestamp, frame , size 
    ///
    /// Optional(?)?
    /// -    (VideoFrame),   (nil)
    /// -  nil ( decoding frame )
    /// - decoding Start  VideoFrame  
    ///
    /// Usage example:
    /// ```swift
    /// if let frame = channel.currentFrame {
    ///     print(" frame: \(frame.frameNumber)")
    /// } else {
    ///     print("frame ")
    /// }
    /// ```
    @Published private(set) var currentFrame: VideoFrame?

    /// @var decoder
    /// @brief video More (Video Decoder)
    /// @details
    /// private?
    /// -     
    /// -  channel.decoderto  
    /// - (Encapsulation):      
    ///
    /// Why Optional?
    /// -  nil (Initialize )
    /// - initialize() Call  VideoDecoder Create
    /// - stop() Call   nilto Set up (memory )
    private var decoder: VideoDecoder?

    /// @var frameBuffer
    /// @brief frame buffer (Frame Buffer)
    /// @details
    /// array(Array)?
    /// - Multiple   to Save 
    /// - [VideoFrame]: VideoFrame  array
    /// - Example: [frame1, frame2, frame3, ...]
    ///
    ///  buffer(Circular Buffer)?
    /// -  size buffer new     Remove
    /// -     Use
    /// - memory   frame 
    ///
    /// buffer How it works:
    /// ```
    ///  size 3 :
    /// [Frame1]
    /// [Frame1, Frame2]
    /// [Frame1, Frame2, Frame3]
    /// [Frame2, Frame3, Frame4]  <- Frame1 Remove, Frame4 Add
    /// [Frame3, Frame4, Frame5]  <- Frame2 Remove, Frame5 Add
    /// ```
    private var frameBuffer: [VideoFrame] = []

    /// @var maxBufferSize
    /// @brief  buffer size (Maximum Buffer Size)
    /// @details
    /// 30 =  1seconds frame (30fps based on)
    ///
    /// Why 30?
    /// - If too small: decoding    
    /// - If too large: memory  Use,    slow
    /// - 30 = 1seconds: Good balance point
    ///
    /// 4channel × 30frame = 120frame Simultaneous buffer
    /// - 1frame ≈ 2MB (1920×1080 BGRA)
    /// - 120frame ≈ 240MB (Manageable)
    private let maxBufferSize = 30

    /// @var decodingQueue
    /// @brief decoding queue (Decoding Queue)
    /// @details
    /// DispatchQueue?
    /// - Swift ( ) 
    /// -   Execute   
    ///
    /// Why ?
    /// - video decoding    
    /// -  thread  UI  (,  )
    /// -  thread decoding UI  
    ///
    /// thread :
    /// ```
    ///  thread:     [UI ] [ ] [] ...
    /// decoding thread:   [frame1 decoding] [frame2 decoding] ...
    /// ```
    ///
    /// label:     
    /// qos (Quality of Service):  
    /// - userInitiated: Use Start ,  
    private let decodingQueue: DispatchQueue

    /// @var bufferLock
    /// @brief buffer  (Buffer Lock)
    /// @details
    /// NSLock?
    /// - Multiple thread Simultaneous      
    /// -       
    ///
    /// Why ?
    /// - decoding thread: frameBuffer frame Add
    /// -  thread: frameBuffer frame 
    /// - Simultaneous     (Race Condition)
    ///
    /// Race Condition( Status) Example:
    /// ```
    /// thread A: frameBuffer.append(frame1)  <- array size Increment 
    /// thread B: let frame = frameBuffer[0]  <- Simultaneous  
    /// : ! ( memory )
    /// ```
    ///
    /// Lock Use:
    /// ```swift
    /// bufferLock.lock()      //  
    /// frameBuffer.append(frame)  //  Use
    /// bufferLock.unlock()    //  
    /// ```
    ///
    /// defer :
    /// ```swift
    /// bufferLock.lock()
    /// defer { bufferLock.unlock() }  //    to unlock
    /// // ...  ...
    /// // return throw   unlock
    /// ```
    private let bufferLock = NSLock()

    /// @var isDecoding
    /// @brief decoding   (Is Decoding)
    /// @details
    /// Bool (Boolean): true or false
    ///
    /// :
    /// - decoding   
    /// - true:  decoding
    /// - false: decoding 
    ///
    /// Usage example:
    /// ```swift
    /// while isDecoding {  // isDecoding true  
    ///     // frame decoding...
    /// }
    /// ```
    ///
    /// Status(state)anddifference from:
    /// - state:   Status (UI  )
    /// - isDecoding:    (private)
    private var isDecoding = false

    /// @var targetFrameTime
    /// @brief target frame  (Target Frame Time)
    /// @details
    /// TimeInterval = Double (seconds  )
    ///
    /// :
    /// -     
    /// - seek() Call  Update
    /// -  closest to frame  
    ///
    /// Example:
    /// ```
    /// targetFrameTime = 5.0
    /// -> 5.0secondsclosest to frame buffer 
    /// -> 4.97seconds frame  
    /// ->  frame currentFrameto Set up
    /// ```
    private var targetFrameTime: TimeInterval = 0.0

    // MARK: - Initialization (Initialize)

    /// @brief channel Create
    /// @param channelID channel   (: new UUID  Create)
    /// @param channelInfo channel  (camera , file path )
    /// @details
    /// (Initializer)?
    /// -  instance Create  Call  
    /// - initto Start
    /// - All (property) Initialize 
    ///
    /// :
    /// - channelID: channel   (: new UUID  Create)
    /// - channelInfo: channel  (camera , file path )
    ///
    /// (Default Value):
    /// - channelID: UUID = UUID()
    /// - "= UUID()" 
    /// - Call   : VideoChannel(channelInfo: info)
    /// -  : VideoChannel(channelID: myUUID, channelInfo: info)
    ///
    /// Usage example:
    /// ```swift
    /// //  1: channelID  Create
    /// let channel1 = VideoChannel(channelInfo: frontInfo)
    ///
    /// //  2: Specific channelID Use
    /// let id = UUID()
    /// let channel2 = VideoChannel(channelID: id, channelInfo: rearInfo)
    /// ```
    init(channelID: UUID = UUID(), channelInfo: ChannelInfo) {
        // self?
        // -   instance  
        // -         Use

        // self.channelID:  
        // channelID: 
        self.channelID = channelID
        self.channelInfo = channelInfo

        // decoding queue Create
        // label UUID  Each channel  queue  Create
        // Example: "com.blackboxplayer.channel.550e8400-e29b-41d4-a716-446655440000"
        self.decodingQueue = DispatchQueue(
            label: "com.blackboxplayer.channel.\(channelID.uuidString)",
            // \(): string (String Interpolation)
            // - string    

            qos: .userInitiated
            // Quality of Service:  
            // - background:  
            // - utility:  
            // - userInitiated:   (Use waiting)
            // - userInteractive:   (UI  )
        )

        //        Initialize :
        // - state = .idle
        // - currentFrame = nil (Optional )
        // - frameBuffer = []
        // - isDecoding = false
        // - targetFrameTime = 0.0
    }

    /// @brief  (deinit)
    /// @details
    /// deinit?
    /// - instance memory   to Call
    /// -  (cleanup) 
    /// - init  
    ///
    /// ARC (Automatic Reference Counting):
    /// - Swift memory  
    /// - instance   If none to memory 
    ///
    /// Example:
    /// ```swift
    /// var channel: VideoChannel? = VideoChannel(channelInfo: info)
    /// // memory VideoChannel instance Create,   = 1
    ///
    /// channel = nil
    /// //   = 0
    /// // -> deinit  Call
    /// // -> stop() Execute decoding ,  
    /// // -> memory Remove
    /// ```
    ///
    /// Why stop() Call?
    /// - decoding thread Execute   
    /// - More file  Status  
    /// - memory    
    deinit {
        stop()
    }

    // MARK: - Public Methods ( )

    /*
     Public vs Private:
     - Public:   Call 
     - Private:   Call 

     Public : initialize, startDecoding, stop, seek, getFrame, getBufferStatus, flushBuffer
     Private : decodingLoop, addFrameToBuffer
     */

    /// @brief channel More Initialize
    /// @throws ChannelError or DecoderError
    /// @details
    /// Initialize :
    /// 1. Status Check ( Initialize)
    /// 2. VideoDecoder Create
    /// 3. More Initialize (FFmpegto file )
    /// 4. status .readyto 
    ///
    /// throws?
    /// -   error (throw)   
    /// - Call  try  
    /// - do-catchto error Process 
    ///
    /// Usage example:
    /// ```swift
    /// do {
    ///     try channel.initialize()
    ///     print("Initialize success!")
    ///     channel.startDecoding()
    /// } catch {
    ///     print("Initialize failure: \(error)")
    /// }
    /// ```
    ///
    ///   error:
    /// - ChannelError.invalidState:  Initialize Status
    /// - DecoderError.cannotOpenFile: file   
    /// - DecoderError.noVideoStream: video  
    /// - DecoderError.codecNotFound:  to find  
    func initialize() throws {
        // 1. Status Check
        // guard-else:  false else  Execute   
        // guard "    " 
        guard state == .idle else {
            //  Initialize  error 
            throw ChannelError.invalidState("Channel already initialized")
        }

        // 2. VideoDecoder Create
        // let decoder: to  (   Use)
        // self.decoder:   (  Use)
        let decoder = VideoDecoder(filePath: channelInfo.filePath)

        // 3. More Initialize
        // try: error    Call to error 
        // decoder.initialize() throw   Execute  
        try decoder.initialize()

        // 4.   Save
        //   = Initialize success
        // Optional nil  to 
        self.decoder = decoder

        // 5. Status 
        // @Published to   to  
        // SwiftUI UI to Update
        state = .ready

        // successto Initialize completed, error   
        //  startDecoding() Call 
    }

    /// @brief  frame decoding Start
    /// @details
    /// (Background)?
    /// - Use    Execute 
    /// - UI  
    ///
    /// How it works:
    /// 1. Status Check (.ready Status )
    /// 2. isDecoding  trueto Set up
    /// 3.  thread decodingLoop() Execute
    /// 4.  return ( to  decoding  )
    ///
    /// (Asynchronous) :
    /// -    Return
    /// - decoding   
    /// - completed  
    ///
    /// ```
    /// startDecoding() Call
    ///     ↓
    ///    (0.001seconds)
    ///     ↓
    /// Call Next  Execute
    ///
    /// Simultaneous:
    ///  thread
    /// decodingLoop() Execute ( secondsto )
    /// ```
    ///
    /// Usage example:
    /// ```swift
    /// try channel.initialize()  // 1.  Initialize
    /// channel.startDecoding()   // 2. decoding Start ( Return)
    /// print("decoding Start!")     // 3. to Execute (decoding completed   )
    ///
    /// //   frame decoding ...
    /// ```
    ///
    /// :
    /// - initialize()  Call 
    /// - .ready Status  
    /// -  decoding   ( Start )
    func startDecoding() {
        // 1. Status Check
        // guard: Multiple  Simultaneous Check
        // state == .ready: Initialize completed Status 
        // !isDecoding: decoding    (! not, )
        //    false return ( )
        guard state == .ready, !isDecoding else {
            return  //  , error  
        }

        // 2. decoding Start  Set up
        isDecoding = true
        state = .decoding
        // @Publishedto UI "decoding "  

        // 3.  decoding Start
        // decodingQueue: init   thread
        // .async:  Execute (   return)
        decodingQueue.async { [weak self] in
            // [weak self]?
            // - self  (weak reference)to 
            // -  (Retain Cycle) 
            //
            //  ?
            // - A B , B A 
            // - to  memory   
            // - memory (Memory Leak)
            //
            // weak Use :
            // - to self  
            // - self to   (decodingQueue to )
            // -   
            // - weakto   
            //
            // self??
            // - weak self Optional
            // - instance    
            // - self? = nil   

            self?.decodingLoop()
            // decoding  Start
            // while isDecoding   Execute
        }

        // 4.   
        // decodingLoop()   Execute 
    }

    /// @brief decoding   
    /// @details
    /// (Cleanup) :
    /// 1. decoding   (isDecoding = false)
    /// 2. status .idleto Initialize
    /// 3. frame buffer 
    /// 4. More  (memory Return)
    /// 5.  frame Remove
    ///
    /// (Resource)?
    /// - memory, file , thread   
    /// - Use    
    /// -   memory 
    ///
    /// Use :
    /// -    
    /// -  to switch 
    /// -   
    /// - deinit  Call
    ///
    /// Usage example:
    /// ```swift
    /// channel.startDecoding()  // decoding Start
    /// // ...   ...
    /// channel.stop()           // 
    ///
    /// //   
    /// //  initialize() + startDecoding() 
    /// ```
    func stop() {
        // 1. decoding  
        isDecoding = false
        // -> decodingLoop() while isDecoding  
        // ->  thread  

        // 2. Status Initialize
        state = .idle
        // seconds Statusto 
        // @Publishedto UI "idle" 

        // 3. frame buffer  (Thread-safe)
        bufferLock.lock()
        //  thread buffer   

        frameBuffer.removeAll()
        // array All  Remove
        // memory 

        bufferLock.unlock()
        //  ,  thread   

        // 4. More 
        decoder = nil
        // Optional nilto Set up
        // VideoDecoder instance   
        //   0  to memory 
        // VideoDecoder deinit Call
        // -> FFmpeg  

        // 5.  frame Remove
        currentFrame = nil
        // Optional nilto Set up
        // @Publishedto UI frame  

        // All  completed
        // memory Use 
        //  initialize() Call 
    }

    /// @brief Specific  to 
    /// @param time    (seconds )
    /// @throws ChannelError or DecoderError
    /// @details
    /// (Seek)?
    /// -  Specific to  
    /// -      
    /// - Example: 10  5 to 
    ///
    ///  :
    /// 1. decoding  
    /// 2. buffer All frame Remove (  frame)
    /// 3. More new to  
    /// 4. target  Update
    /// 5. decoding 
    ///
    /// Why buffer ?
    /// - buffer  frame   
    /// - Example: 5seconds  20secondsto 
    /// - buffer 5secondsto6seconds frame 
    /// - 20seconds   
    /// - buffer  20seconds  decoding
    ///
    /// Usage example:
    /// ```swift
    /// // 10seconds to 
    /// try channel.seek(to: 10.0)
    ///
    /// // to 
    /// try channel.seek(to: 0.0)
    ///
    /// // 5 30secondsto 
    /// try channel.seek(to: 330.0)  // 5*60 + 30 = 330
    /// ```
    ///
    /// :
    /// - initialize()  Call 
    /// - More If none error 
    /// -   0to Process
    /// -     to 
    func seek(to time: TimeInterval) throws {
        // 1. More  Check
        // guard let: Optional 
        // - decoder nil   decoder  Save
        // - nil else  Execute
        guard let decoder = decoder else {
            // More Initialize 
            throw ChannelError.notInitialized
        }

        // 2. decoding Status Save  
        let wasDecoding = isDecoding
        //  decoding  
        //   Start  

        isDecoding = false
        // decoding  
        // decodingLoop() while isDecoding 
        //  thread  

        // 3. buffer  (Thread-safe)
        bufferLock.lock()
        frameBuffer.removeAll()
        bufferLock.unlock()
        //   frame  Remove

        // 4. More 
        try decoder.seek(to: time)
        // VideoDecoder new to  
        // FFmpeg file   
        // frame(I-frame)to 
        // error   throw (Call )

        // 5. target  Update
        targetFrameTime = time
        //  closest to frame   Save

        // 6. decoding  ( )
        if wasDecoding {
            //  decoding 
            startDecoding()
            //  decoding Start
            // new  frame decoding Start
        }

        // 7. Status Update
        state = .ready
        //  completed,   Status

        // successto  completed
        // getFrame(at: time)to new at position frame   
    }

    /// @brief target   frame Return
    /// @param time    (seconds )
    /// @param strategy frame   (: .nearest)
    /// @return  VideoFrame, If none nil
    /// @details
    /// ## frame  :
    /// - `.nearest`: Closest frame ()
    /// - `.before`: target  before Closest frame
    /// - `.after`: target   Closest frame
    /// - `.exact(tolerance)`:      frame
    ///
    /// ##  :
    /// -  to   (O(n) → O(log n))
    /// - frame   
    /// - frame  tolerance
    /// - More   
    ///
    /// frame  :
    /// 1. buffer  to target   
    /// 2.     frame 
    /// 3.  frame 
    ///
    /// Example:
    /// ```swift
    /// // Closest frame
    /// let frame1 = channel.getFrame(at: 5.0)
    ///
    /// // 5.0seconds before frame ( )
    /// let frame2 = channel.getFrame(at: 5.0, strategy: .before)
    ///
    /// // 5.0seconds  frame ( )
    /// let frame3 = channel.getFrame(at: 5.0, strategy: .after)
    ///
    /// //  5.0seconds±0.01seconds  frame
    /// let frame4 = channel.getFrame(at: 5.0, strategy: .exact(tolerance: 0.01))
    /// ```
    ///
    /// buffer :
    /// -   - 0.5seconds before frame Remove (1seconds → 0.5secondsto )
    /// - More   memory 
    ///
    /// nil Return :
    /// - buffer 
    /// -    frame 
    /// - exact  tolerance  frame 
    func getFrame(at time: TimeInterval, strategy: FrameSelectionStrategy = .nearest) -> VideoFrame? {
        // 1. buffer 
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // 2. buffer  Check
        guard !frameBuffer.isEmpty else {
            return nil
        }

        // 3.    frame 
        let selectedFrame: VideoFrame?

        switch strategy {
        case .nearest:
            // Closest frame ( )
            selectedFrame = findNearestFrame(to: time)

        case .before:
            // target  before Closest frame
            selectedFrame = findFrameBefore(time: time)

        case .after:
            // target   Closest frame
            selectedFrame = findFrameAfter(time: time)

        case .exact(let tolerance):
            //      frame
            selectedFrame = findExactFrame(at: time, tolerance: tolerance)
        }

        // 4.  frame  (0.5secondsto )
        let cleanupThreshold = time - 0.5
        frameBuffer.removeAll { frame in
            frame.timestamp < cleanupThreshold
        }

        // 5.  Return
        return selectedFrame
    }

    /// @brief  buffer status Return
    /// @return ( size,  size,  )
    /// @details
    /// buffer Status :
    /// - current:  buffer  frame 
    /// - max:  buffer size (30)
    /// - fillPercentage:   (0.0 to 1.0)
    ///
    /// Tuple()?
    /// - Multiple  to  
    /// - (Int, Int, Double) 
    /// -    : (current: Int, max: Int, fillPercentage: Double)
    ///
    /// Usage example:
    /// ```swift
    /// let status = channel.getBufferStatus()
    /// print("buffer: \(status.current)/\(status.max)")
    /// print(": \(status.fillPercentage * 100)%")
    ///
    /// // buffer   Check
    /// if status.fillPercentage < 0.2 {
    /// print("buffer !")
    /// }
    ///
    /// // buffer   Check
    /// if status.fillPercentage > 0.9 {
    ///     print("buffer  ")
    /// }
    /// ```
    ///
    /// :
    /// - UI buffer Status  (Loading )
    /// - buffer  "Loading " 
    /// - : buffer to  Check
    func getBufferStatus() -> (current: Int, max: Int, fillPercentage: Double) {
        // 1. buffer  (Thread-safe)
        bufferLock.lock()
        defer { bufferLock.unlock() }
        //  thread Simultaneous buffer  

        // 2.  buffer size
        let current = frameBuffer.count
        // count: array  count
        // 0 to 30 between 

        // 3.   Calculate
        let percentage = Double(current) / Double(maxBufferSize)
        // Double(): Int Doubleto Convert
        // -  : Int   
        // - 15 / 30 = 0 (Int )
        // - 15.0 / 30.0 = 0.5 (Double )
        //
        // percentage: 0.0 to 1.0
        // - 0.0 =  (0%)
        // - 0.5 =  (50%)
        // - 1.0 =   (100%)

        // 4. to Return
        return (current, maxBufferSize, percentage)
        // (current: 15, max: 30, fillPercentage: 0.5)

        // defer  to unlock Execute
    }

    /// @brief frame buffer 
    /// @details
    /// buffer (Flush)?
    /// - buffer All  Remove 
    /// -      
    /// - memory  Return
    ///
    /// Use :
    /// -   (seek   Call)
    /// - memory   
    /// - newto to switch 
    ///
    /// Note:
    /// - buffer  frame 
    /// - getFrame() nil Return
    /// - decoding     
    ///
    /// Usage example:
    /// ```swift
    /// // memory   buffer 
    /// channel.flushBuffer()
    ///
    /// // buffer Check
    /// let status = channel.getBufferStatus()
    /// print(status.current)  // 0
    /// ```
    func flushBuffer() {
        // Thread-safe buffer 
        bufferLock.lock()
        defer { bufferLock.unlock() }

        frameBuffer.removeAll()
        // array All  Remove
        // memory  
        // count = 0 
    }

    // MARK: - Private Methods ( )

    /*
     Private :
     -   Use
     -   Call 
     -   

       :
     - decodingLoop(): decoding  ( thread Execute)
     - addFrameToBuffer(): frame buffer Add
     - findNearestFrame(): Closest frame 
     - findFrameBefore():  frame 
     - findFrameAfter():  frame 
     - findExactFrame():  frame 
     */

    /// @brief target closest to frame 
    /// @param time target 
    /// @return Closest frame
    /// @details
    ///  to target closest to frame .
    /// buffer  timestamp to  to O(log n) .
    private func findNearestFrame(to time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        //  to   
        var left = 0
        var right = frameBuffer.count - 1

        //  : target  buffer range  
        if time <= frameBuffer[0].timestamp {
            return frameBuffer[0]
        }
        if time >= frameBuffer[right].timestamp {
            return frameBuffer[right]
        }

        //  
        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp == time {
                //   frame 
                return frame
            } else if frame.timestamp < time {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        // leftand right  target  
        // left = target    frame
        // right = target  before  frame
        if right >= 0 && left < frameBuffer.count {
            let beforeFrame = frameBuffer[right]
            let afterFrame = frameBuffer[left]

            let diffBefore = abs(beforeFrame.timestamp - time)
            let diffAfter = abs(afterFrame.timestamp - time)

            // More  frame  (  frame )
            return diffBefore <= diffAfter ? beforeFrame : afterFrame
        }

        // : array range Check
        if right >= 0 && right < frameBuffer.count {
            return frameBuffer[right]
        }
        if left >= 0 && left < frameBuffer.count {
            return frameBuffer[left]
        }

        return nil
    }

    /// @brief target  before Closest frame 
    /// @param time target 
    /// @return  frame
    /// @details
    ///    before frame   Use.
    private func findFrameBefore(time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        //  to target  before  frame 
        var left = 0
        var right = frameBuffer.count - 1
        var result: VideoFrame?

        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp < time {
                //  frame target  
                result = frame
                left = mid + 1  // More  frame   
            } else if frame.timestamp == time {
                //   ,  frame 
                if mid > 0 {
                    return frameBuffer[mid - 1]
                } else {
                    return nil  //  frame 
                }
            } else {
                //  frame target  
                right = mid - 1
            }
        }

        return result
    }

    /// @brief target   Closest frame 
    /// @param time target 
    /// @return  frame
    /// @details
    ///     frame   Use.
    private func findFrameAfter(time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        //  to target    frame 
        var left = 0
        var right = frameBuffer.count - 1
        var result: VideoFrame?

        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp > time {
                //  frame target  
                result = frame
                right = mid - 1  // More  frame   
            } else if frame.timestamp == time {
                //   ,  frame 
                if mid < frameBuffer.count - 1 {
                    return frameBuffer[mid + 1]
                } else {
                    return nil  //  frame 
                }
            } else {
                //  frame target  
                left = mid + 1
            }
        }

        return result
    }

    /// @brief      frame 
    /// @param time target 
    /// @param tolerance   (seconds)
    /// @return  frame
    /// @details
    /// Specific tolerance  frame Return. frame  tolerance .
    /// Example: 30fps → tolerance = 1/(30*2) = 0.0167seconds
    private func findExactFrame(at time: TimeInterval, tolerance: TimeInterval) -> VideoFrame? {
        //  Closest frame 
        guard let nearestFrame = findNearestFrame(to: time) else {
            return nil
        }

        // tolerance   Check
        let diff = abs(nearestFrame.timestamp - time)
        if diff <= tolerance {
            return nearestFrame
        }

        return nil  // tolerance  nil Return
    }

    /// @brief decoding  ( thread Execute)
    /// @details
    ///  (Infinite Loop)?
    /// - while isDecoding { ... } 
    /// - isDecoding true   
    /// - isDecoding false   
    ///
    ///  :
    /// ```
    /// Start
    ///   ↓
    /// ┌──────────────────┐
    /// │ isDecoding?      │ ← while  Check
    /// └──────────────────┘
    ///   ↓ true         ↓ false
    /// ┌──────────────┐  
    /// │ buffer Check     │
    /// │ frame decoding │
    /// │ buffer Add   │
    /// └──────────────┘
    ///   ↓
    /// ( to)
    /// ```
    ///
    /// autoreleasepool?
    /// -   Create    
    /// - memory Use 
    /// -   Execute memory   
    ///
    /// to(Logging):
    /// - infoLog, debugLog, errorLog Use
    /// -    to output
    /// - frame , buffer Status  
    ///
    /// error Process:
    /// - endOfFile: file  ,  
    /// - readFrameError: decoding error 
    /// -  error: error Statusto switch
    private func decodingLoop() {
        // Start to
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop started")
        // Example: "[VideoChannel:front camera] Decoding loop started"

        //  
        var frameCount = 0  // decoding  frame 
        var lastLogTime = Date()  //  to 

        //  
        // isDecoding true   Execute
        // stop() seek() Call isDecoding = false
        while isDecoding {
            // autoreleasepool:       memory 
            autoreleasepool {
                // autoreleasepool?
                // - Objective-Cand   memory  
                // -   Create    to end 
                // -   Use memory  
                //
                // Example:
                // ```
                // for i in 1...1000000 {
                //     autoreleasepool {
                //         let data = hugeData()  //   Create
                //         // Use...
                //     }  //  data  
                // }
                // ```

                // 1. buffer size Check (Thread-safe)
                bufferLock.lock()
                let bufferSize = frameBuffer.count
                bufferLock.unlock()
                //   ,  

                // 2. buffer   Check
                guard bufferSize < maxBufferSize else {
                    // buffer   (30)
                    // More decoding Add  
                    // Wait a moment

                    // 2seconds to output (  to )
                    if Date().timeIntervalSince(lastLogTime) > 2.0 {
                        debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffer full (\(bufferSize)/\(maxBufferSize)), waiting...")
                        lastLogTime = Date()
                    }

                    // 10milliseconds 
                    Thread.sleep(forTimeInterval: 0.01)
                    // Thread.sleep:  thread   
                    // 0.01seconds = 10milliseconds
                    // CPU  

                    return  // autoreleasepool , while  
                }

                // 3. More Check
                guard let decoder = decoder else {
                    // More  (stop() Call)
                    isDecoding = false
                    return  //  
                }

                // 4. Next frame decoding 
                do {
                    // try: error   
                    // do-catch: error Process

                    if let result = try decoder.decodeNextFrame() {
                        // decodeNextFrame(): Next  decoding
                        // Return: (video: VideoFrame?, audio: AudioFrame?)
                        // nil: EAGAIN (More   )

                        if let videoFrame = result.video {
                            // video frame decoding
                            addFrameToBuffer(videoFrame)
                            frameCount += 1
                        }

                        // audio frame 
                        //  channel   channel audio Use
                        // Each channel audio   
                    }
                    // result nil:
                    // - EAGAIN error (More   )
                    // - Next   

                } catch {
                    // error 
                    errorLog("Channel \(channelInfo.position.displayName) decode error: \(error)")

                    // error   Process
                    if case DecoderError.endOfFile = error {
                        // file   ( )
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed after \(frameCount) frames")

                    } else if case DecoderError.readFrameError(let code) = error, code == -541478725 {
                        // AVERROR_EOF from av_read_frame
                        // FFmpeg file  error 
                        // -541478725 = AVERROR_EOF
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed (EOF) after \(frameCount) frames")

                    } else {
                        //  error ( )
                        state = .error(error.localizedDescription)
                        isDecoding = false
                    }
                }
            }  // autoreleasepool 
            //    Create   
        }  // while 

        //   to
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop ended, total frames: \(frameCount)")
        // Example: "[VideoChannel:front camera] Decoding loop ended, total frames: 450"
    }

    /// @brief frame buffer Add
    /// @param frame Add VideoFrame
    /// @details
    /// Add :
    /// 1. buffer  (Thread-safe)
    /// 2. buffer frame Add
    /// 3. timestamp to 
    /// 4. buffer size  ( frame Remove)
    /// 5.   frame to output
    /// 6.  frame Update ( thread)
    ///
    /// (Sorting)  :
    /// - decoding and     
    /// - H.264 B-frame(  frame) 
    /// - decoding: I, P, B, P, B 
    /// - : I, B, B, P, P 
    /// - timestampto    
    private func addFrameToBuffer(_ frame: VideoFrame) {
        // 1. buffer 
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // 2. buffer frame Add
        frameBuffer.append(frame)
        // append(): array to end  Add
        // [Frame1, Frame2] + Frame3 = [Frame1, Frame2, Frame3]

        // 3. timestamp to 
        frameBuffer.sort { frame1, frame2 in
            // sort(by:): array 
            // to true Return frame1 frame2  
            frame1.timestamp < frame2.timestamp
            // timestamp   ()
        }
        //  : [0.0seconds, 0.033seconds, 0.067seconds, 0.1seconds, ...]

        // 4. buffer size 
        if frameBuffer.count > maxBufferSize {
            // buffer  size seconds
            //  frame Remove

            let removeCount = frameBuffer.count - maxBufferSize
            // Remove count
            // Example: 32 - 30 = 2 Remove

            frameBuffer.removeFirst(removeCount)
            // removeFirst(n):  n Remove
            // timestamp  () frame Remove
        }

        // 5.   frame to ()
        if frameBuffer.count <= 3 {
            //  3 frame to output
            //   to 

            debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffered frame #\(frame.frameNumber) at \(String(format: "%.2f", frame.timestamp))s, buffer size: \(frameBuffer.count)")
            // String(format:):  string Create
            // "%.2f":  2
            // Example: "Buffered frame #5 at 0.17s, buffer size: 3"
        }

        // 6.  frame Update ( thread)
        DispatchQueue.main.async { [weak self] in
            // DispatchQueue.main:  thread
            // .async:  Execute ( )
            //
            // Why  thread?
            // - @Published  Update  thread
            // - SwiftUI UI Update  thread
            // -  thread UI Update 
            //
            // [weak self]:   

            self?.currentFrame = frame
            // @Publishedto UI  Update
            //   frame 
        }
    }
}

// MARK: - Supporting Types ( )

/// @enum FrameSelectionStrategy
/// @brief frame    
/// @details
/// getFrame(at:strategy:)  Use frame  is.
///
/// ##  :
///
/// **nearest ()**:
/// - target closest to frame 
/// -  frame  
/// -   
///
/// **before**:
/// - target  before Closest frame
/// -      
/// - Example: 5.0seconds   4.967seconds frame Return
///
/// **after**:
/// - target   Closest frame
/// -      
/// - Example: 5.0seconds   5.033seconds frame Return
///
/// **exact(tolerance)**:
/// -      frame
/// - tolerance  nil Return
/// -  synchronization  
/// - Example: exact(tolerance: 0.01) → ±10ms  
///
/// ## Use Example:
/// ```swift
/// //   ()
/// let frame1 = channel.getFrame(at: 5.0)
///
/// // frame  
/// let frame2 = channel.getFrame(at: currentTime, strategy: .before)
///
/// // frame  
/// let frame3 = channel.getFrame(at: currentTime, strategy: .after)
///
/// //  synchronization (30fps based on)
/// let tolerance = 1.0 / (30.0 * 2)  //  0.0167seconds
/// let frame4 = channel.getFrame(at: 5.0, strategy: .exact(tolerance: tolerance))
/// ```
enum FrameSelectionStrategy {
    /// @brief Closest frame ()
    case nearest

    /// @brief target  before frame
    case before

    /// @brief target   frame
    case after

    /// @brief   frame (  )
    /// @param tolerance   (seconds )
    case exact(tolerance: TimeInterval)
}

/// @enum ChannelState
/// @brief channel status  
/// @details
/// enum()?
/// -   to  
/// -       
/// - switch to All  Process 
///
/// Equatable?
/// - ==, != to  
/// - state1 == state2 
///
///  (Associated Value):
/// - case error(String) Add    
/// - Example: .error("File not found")
///
/// Status (State Transition):
/// ```
/// .idle (idle)
///   ↓ initialize()
/// .ready (ready)
///   ↓ startDecoding()
/// .decoding (decoding )
///   ↓ file 
/// .completed (completed)
///
/// :
///   → .error (error)
///   → .idle (stop())
/// ```
enum ChannelState: Equatable {
    /// @brief idle Status (seconds Status,   )
    case idle

    /// @brief ready completed (More Initialize, decoding Start )
    case ready

    /// @brief decoding  ( frame decoding )
    case decoding

    /// @brief completed (file  decoding completed)
    case completed

    /// @brief error (error  )
    case error(String)

    /// @brief UI  Status 
    /// @return status  string
    var displayName: String {
        // computed property (Calculate )
        //  Save  Calculate Return

        switch self {
        // self:  enum 
        // switch: All   Process

        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .decoding:
            return "Decoding"
        case .completed:
            return "Completed"
        case .error(let message):
            // let message:   
            // .error("File not found") → message = "File not found"
            return "Error: \(message)"
        }
    }
}

/// @enum ChannelError
/// @brief channel  error  
/// @details
/// LocalizedError?
/// - Swift  error to
/// - errorDescriptionto Use   
/// - Error to More   
enum ChannelError: LocalizedError {
    /// @brief Initialize  (initialize()  Call )
    case notInitialized

    /// @brief  Status (Example:  Initialize)
    case invalidState(String)

    /// @brief error  (Use  )
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Channel not initialized"
        case .invalidState(let message):
            return "Invalid channel state: \(message)"
        }
    }

    // Usage example:
    // ```swift
    // do {
    //     try channel.seek(to: 5.0)
    // } catch let error as ChannelError {
    //     print(error.errorDescription)
    //     // "Channel not initialized"
    // }
    // ```
}

// MARK: - Equatable ( )

/// @brief VideoChannel   
/// @details
/// extension?
/// -   new  Add
/// -     
///
/// Equatable to:
/// - ==, !=  Use 
/// - array contains(), firstIndex(of:) Use 
///
/// channel :
/// - channelID   channel
/// -  (state, currentFrame) 
extension VideoChannel: Equatable {
    /// @brief  VideoChannel  
    /// @param lhs  
    /// @param rhs  
    /// @return channelID  true
    static func == (lhs: VideoChannel, rhs: VideoChannel) -> Bool {
        // static func:   (instance   )
        // ==:  Loading
        // lhs: left-hand side ()
        // rhs: right-hand side ()

        return lhs.channelID == rhs.channelID
        // UUID   channel
    }
}

// Usage example:
// ```swift
// let channel1 = VideoChannel(channelInfo: info1)
// let channel2 = VideoChannel(channelInfo: info2)
//
// if channel1 == channel2 {
//     print(" channel")
// } else {
//     print(" channel")
// }
//
// let channels = [channel1, channel2, channel3]
// if channels.contains(channel1) {
//     print("channel1 array ")
// }
// ```

// MARK: - Identifiable ( )

/// @brief VideoChannel SwiftUI   
/// @details
/// Identifiable to:
/// - SwiftUI List, ForEach Use
/// - id   ( )
/// - Each    Use
///
/// ForEach Usage example:
/// ```swift
/// ForEach(channels) { channel in
///     // channel.id to Use Each  
///     Text(channel.channelInfo.displayName)
/// }
/// ```
///
/// id If none:
/// ```swift
/// ForEach(channels, id: \.channelID) { channel in
///     // id  
/// }
/// ```
///
/// id :
/// ```swift
/// ForEach(channels) { channel in
///     // id  Use
/// }
/// ```
extension VideoChannel: Identifiable {
    /// @brief  
    /// @return channelID
    var id: UUID {
        // computed property
        // channelID idto Return
        channelID
        // return channelIDand  (Swift  )
    }
}
