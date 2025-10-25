/// @file VideoBuffer.swift
/// @brief Frame buffer for video playback
/// @author BlackboxPlayer Development Team
/// @details
/// This file class that buffers video framesdefines
/// Limits memory usage and ensures smooth playback.

import Foundation

/// @class VideoBuffer
/// @brief video frame buffer Thread-safe is.
///
/// @details
/// ## Key features:
/// -  buffer  (FIFO)
/// -  size  (memory )
/// - Thread-safe (DispatchQueue Use)
/// - Auto-remove old frame Delete
///
/// ## buffer :
/// - channel  30 frame buffer ( 1seconds, 30fps based on)
/// - buffer     frame  Delete
/// - decoding threadand rendering thread between synchronization
///
/// ## Usage example:
/// ```swift
/// let buffer = VideoBuffer(maxSize: 30)
///
/// // decoding thread
/// buffer.append(frame)
///
/// // rendering thread
/// if let frame = buffer.next() {
///     render(frame)
/// }
/// ```
class VideoBuffer {

    // MARK: - Properties

    /// @var frames
    /// @brief Save video frame array
    /// @details
    /// - FIFO Managed in order (First In, First Out)
    /// - private: Cannot be accessed directly from outside
    private var frames: [VideoFrame] = []

    /// @var maxSize
    /// @brief buffer  size (frame count)
    /// @details
    /// - : 30 frame (30fps based on 1seconds)
    /// - memory Use   Set up
    private let maxSize: Int

    /// @var queue
    /// @brief Thread-safe  serial queue
    /// @details
    /// - Multiple threadsimultaneous access from  Prevent data race
    /// - serial queue(serial queue): Only one task at a time Execute
    private let queue = DispatchQueue(label: "com.blackboxplayer.videobuffer", qos: .userInitiated)

    /// @var currentIndex
    /// @brief Current read position 
    /// @details
    /// - next() Call  Return frame 
    /// - Increment sequentially
    private var currentIndex: Int = 0

    /// @var isEmpty
    /// @brief buffer  
    var isEmpty: Bool {
        return queue.sync { frames.isEmpty }
    }

    /// @var count
    /// @brief  buffer Save frame count
    var count: Int {
        return queue.sync { frames.count }
    }

    /// @var isFull
    /// @brief buffer   
    var isFull: Bool {
        return queue.sync { frames.count >= maxSize }
    }

    // MARK: - Initialization

    /// @brief video buffer Create.
    ///
    /// @param maxSize buffer  size (frame count),  30
    ///
    /// @details
    ///  buffer size selection:
    /// - 30fps video: 30 frame = 1seconds
    /// - 60fps video: 60 frame = 1seconds
    /// -   memory waste,   buffer More 
    init(maxSize: Int = 30) {
        self.maxSize = maxSize
    }

    // MARK: - Public Methods

    /// @brief buffer new frame Add.
    ///
    /// @param frame Add video frame
    ///
    /// @details
    /// How it works:
    /// 1. buffer      frame Delete
    /// 2. new frame buffer to end Add
    /// 3. Thread-safe Process
    func append(_ frame: VideoFrame) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // buffer     frame Delete
            if self.frames.count >= self.maxSize {
                self.frames.removeFirst()
                //  Adjust (All due to deletion  -1)
                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                }
            }

            // new frame Add
            self.frames.append(frame)
        }
    }

    /// @brief Next frame .
    ///
    /// @return Next video frame, If none nil
    ///
    /// @details
    ///  Reading:
    /// - currentIndex at position frame Return
    /// - currentIndex Increment
    /// - buffer When reached end nil Return
    ///
    /// Note:
    /// - frame buffer Delete 
    /// - Multiple  Call 
    func next() -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }

            //  range Check
            guard self.currentIndex < self.frames.count else {
                return nil
            }

            let frame = self.frames[self.currentIndex]
            self.currentIndex += 1
            return frame
        }
    }

    /// @brief Specific timestampclosest to frame .
    ///
    /// @param timestamp to find timestamp (seconds )
    ///
    /// @return Closest video frame, If none nil
    ///
    /// @details
    /// Search method:
    /// 1. buffer All frame Traverse
    /// 2. Each frame target timestampdifference from Calculate
    /// 3. With smallest difference frame Return
    func frame(at timestamp: TimeInterval) -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self, !self.frames.isEmpty else {
                return nil
            }

            // Closest frame 
            var closestFrame: VideoFrame?
            var minDifference = Double.infinity

            for frame in self.frames {
                let difference = abs(frame.timestamp - timestamp)
                if difference < minDifference {
                    minDifference = difference
                    closestFrame = frame
                }
            }

            return closestFrame
        }
    }

    /// @brief  buffer   frame .
    ///
    /// @return   frame, If none nil
    ///
    /// @details
    /// buffer  frame Return.
    ///    Create .
    func latest() -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }
            return self.frames.last
        }
    }

    /// @brief bufferEmpty
    ///
    /// @details
    /// All frame Delete  Initialize.
    /// seek or file switch  Call.
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.frames.removeAll()
            self.currentIndex = 0
        }
    }

    /// @brief Reset read position to beginning.
    ///
    /// @details
    /// currentIndex 0to Set up.
    /// frame Delete      .
    func reset() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = 0
        }
    }

    /// @brief Specific timestamp All before frame Delete.
    ///
    /// @param timestamp based on timestamp (seconds )
    ///
    /// @details
    /// memory Optimization:
    /// - Old already played frame Delete
    /// - memory Use 
    /// - buffer Secure space
    func removeFrames(before timestamp: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // timestamp before frame count Calculate
            let removeCount = self.frames.prefix(while: { $0.timestamp < timestamp }).count

            // frame Delete
            if removeCount > 0 {
                self.frames.removeFirst(removeCount)
                //  Adjust
                self.currentIndex = max(0, self.currentIndex - removeCount)
            }
        }
    }

    /// @brief buffer Status  stringto Return.
    ///
    /// @return buffer Status string
    ///
    /// @details
    ///  for purpose of buffer status output.
    func getStatusString() -> String {
        return queue.sync { [weak self] in
            guard let self = self else { return "Buffer: disposed" }

            let usage = self.frames.count
            let capacity = self.maxSize
            let percentage = capacity > 0 ? Int(Double(usage) / Double(capacity) * 100) : 0

            var status = "Buffer: \(usage)/\(capacity) (\(percentage)%)"

            if let first = self.frames.first, let last = self.frames.last {
                let range = last.timestamp - first.timestamp
                status += " | Range: \(String(format: "%.2f", range))s"
            }

            return status
        }
    }
}
