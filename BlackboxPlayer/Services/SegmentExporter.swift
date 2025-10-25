/// @file SegmentExporter.swift
/// @brief Video segment extraction service
/// @author BlackboxPlayer Development Team
/// @details
/// Service to extract selected segments as separate video files.
/// Uses FFmpeg to efficiently extract segments and track progress.

import Foundation

/// @class SegmentExporter
/// @brief Video segment extraction service
///
/// @details
/// ## Features
/// - Extract segment from In Point to Out Point as new file
/// - Progress tracking and callbacks
/// - Simultaneous multi-channel extraction
/// - Preserve GPS metadata
///
/// ## Extraction Method
/// ```
/// FFmpeg command:
/// ffmpeg -ss <start_time> -i <input> -t <duration> -c copy <output>
///
/// Options:
/// - -ss: Start time (In Point)
/// - -t: Duration (duration = Out Point - In Point)
/// - -c copy: Copy codec (fast processing, no re-encoding)
/// ```
///
/// ## Usage Example
/// ```swift
/// let exporter = SegmentExporter()
///
/// exporter.exportSegment(
///     inputPath: "/path/to/input.mp4",
///     outputPath: "/path/to/output.mp4",
///     startTime: 5.0,
///     duration: 10.0
/// ) { progress in
///     print("Progress: \(progress * 100)%")
/// } completion: { result in
///     switch result {
///     case .success(let url):
///         print("Exported: \(url)")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
class SegmentExporter {
    // MARK: - Types

    /// @enum ExportError
    /// @brief Export error types
    enum ExportError: LocalizedError {
        /// Input file not found
        case inputFileNotFound

        /// Invalid output path
        case invalidOutputPath

        /// Invalid time range
        case invalidTimeRange

        /// FFmpeg execution failed
        case ffmpegExecutionFailed(String)

        /// Cancelled by user
        case cancelled

        /// Error description
        var errorDescription: String? {
            switch self {
            case .inputFileNotFound:
                return "Input file not found"
            case .invalidOutputPath:
                return "Invalid output path"
            case .invalidTimeRange:
                return "Invalid time range"
            case .ffmpegExecutionFailed(let message):
                return "FFmpeg execution failed: \(message)"
            case .cancelled:
                return "Export cancelled by user"
            }
        }
    }

    /// @struct ExportOptions
    /// @brief Export options
    struct ExportOptions {
        /// Video codec (nil = copy)
        var videoCodec: String?

        /// Audio codec (nil = copy)
        var audioCodec: String?

        /// Video bitrate (nil = keep original)
        var videoBitrate: Int?

        /// Audio bitrate (nil = keep original)
        var audioBitrate: Int?

        /// Quality preset (ultrafast, fast, medium, slow, etc.)
        var preset: String?

        /// Default options (codec copy)
        static var `default`: ExportOptions {
            return ExportOptions(
                videoCodec: "copy",
                audioCodec: "copy",
                videoBitrate: nil,
                audioBitrate: nil,
                preset: nil
            )
        }
    }

    // MARK: - Properties

    /// Cancellation flag
    private var isCancelled: Bool = false

    /// Currently running process
    private var currentProcess: Process?

    // MARK: - Public Methods

    /// Export video segment
    ///
    /// ## Export Process
    /// ```
    /// 1. Check input file exists
    /// 2. Validate output path
    /// 3. Generate FFmpeg command
    /// 4. Execute process (background)
    /// 5. Track progress
    /// 6. Call completion callback
    /// ```
    ///
    /// - Parameters:
    ///   - inputPath: Input video file path
    ///   - outputPath: Output video file path
    ///   - startTime: Start time (seconds)
    ///   - duration: Duration (seconds)
    ///   - options: Export options (default: .default)
    ///   - progressHandler: Progress callback (0.0 ~ 1.0)
    ///   - completion: Completion callback
    func exportSegment(
        inputPath: String,
        outputPath: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        options: ExportOptions = .default,
        progressHandler: @escaping (Double) -> Void = { _ in },
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // Execute in background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Initialize cancellation flag
            self.isCancelled = false

            // 1. Check input file
            guard FileManager.default.fileExists(atPath: inputPath) else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.inputFileNotFound))
                }
                return
            }

            // 2. Check time range
            guard startTime >= 0 && duration > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.invalidTimeRange))
                }
                return
            }

            // 3. Create output directory
            let outputURL = URL(fileURLWithPath: outputPath)
            let outputDirectory = outputURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(
                    at: outputDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            // 4. Execute FFmpeg command
            do {
                try self.runFFmpegExport(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    startTime: startTime,
                    duration: duration,
                    options: options,
                    progressHandler: progressHandler
                )

                // Success
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }

            } catch {
                // Failure
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Export multiple channels simultaneously
    ///
    /// ## Multi-channel Processing
    /// - Extract all channels simultaneously
    /// - Track progress for each channel
    /// - Call callback after all channels complete
    ///
    /// - Parameters:
    ///   - channels: Array of channel info (with inputPath)
    ///   - outputDirectory: Output directory
    ///   - startTime: Start time (seconds)
    ///   - duration: Duration (seconds)
    ///   - progressHandler: Overall progress callback (0.0 ~ 1.0)
    ///   - completion: Completion callback (success: array of output file URLs)
    func exportMultipleChannels(
        channels: [(position: ChannelPosition, inputPath: String)],
        outputDirectory: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        progressHandler: @escaping (Double) -> Void = { _ in },
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        let group = DispatchGroup()
        var results: [Result<URL, Error>] = Array(repeating: .failure(ExportError.cancelled), count: channels.count)
        var channelProgress: [Double] = Array(repeating: 0.0, count: channels.count)

        for (index, channel) in channels.enumerated() {
            group.enter()

            // Generate output file name
            let outputFileName = "segment_\(channel.position.rawValue).mp4"
            let outputPath = (outputDirectory as NSString).appendingPathComponent(outputFileName)

            // Extract each channel
            exportSegment(
                inputPath: channel.inputPath,
                outputPath: outputPath,
                startTime: startTime,
                duration: duration
            ) { progress in
                // Update individual channel progress
                channelProgress[index] = progress

                // Calculate overall progress (average)
                let totalProgress = channelProgress.reduce(0, +) / Double(channels.count)
                progressHandler(totalProgress)

            } completion: { result in
                results[index] = result
                group.leave()
            }
        }

        // Wait for all channels to complete
        group.notify(queue: .main) {
            // Check all results
            var successURLs: [URL] = []
            for result in results {
                switch result {
                case .success(let url):
                    successURLs.append(url)
                case .failure(let error):
                    // If any fails, entire operation fails
                    completion(.failure(error))
                    return
                }
            }

            // All succeeded
            completion(.success(successURLs))
        }
    }

    /// Cancel export
    ///
    /// ## Cancellation Handling
    /// - Terminate currently running process
    /// - Set isCancelled flag
    /// - Abort all ongoing export operations
    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    // MARK: - Private Methods

    /// Execute FFmpeg command
    ///
    /// ## Command Format
    /// ```bash
    /// ffmpeg -ss <start> -i <input> -t <duration> -c copy <output>
    /// ```
    ///
    /// - Parameters:
    ///   - inputPath: Input file path
    ///   - outputPath: Output file path
    ///   - startTime: Start time (seconds)
    ///   - duration: Duration (seconds)
    ///   - options: Export options
    ///   - progressHandler: Progress callback
    private func runFFmpegExport(
        inputPath: String,
        outputPath: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        options: ExportOptions,
        progressHandler: @escaping (Double) -> Void
    ) throws {
        // Find FFmpeg executable path
        guard let ffmpegPath = findFFmpegPath() else {
            throw ExportError.ffmpegExecutionFailed("FFmpeg not found")
        }

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        // Build command arguments
        var arguments: [String] = [
            "-y",  // Overwrite without asking
            "-ss", String(format: "%.3f", startTime),  // Start time
            "-i", inputPath,  // Input file
            "-t", String(format: "%.3f", duration)  // Duration
        ]

        // Codec options
        if let videoCodec = options.videoCodec {
            arguments.append(contentsOf: ["-c:v", videoCodec])
        }
        if let audioCodec = options.audioCodec {
            arguments.append(contentsOf: ["-c:a", audioCodec])
        }

        // Bitrate options
        if let videoBitrate = options.videoBitrate {
            arguments.append(contentsOf: ["-b:v", "\(videoBitrate)k"])
        }
        if let audioBitrate = options.audioBitrate {
            arguments.append(contentsOf: ["-b:a", "\(audioBitrate)k"])
        }

        // Preset option
        if let preset = options.preset {
            arguments.append(contentsOf: ["-preset", preset])
        }

        // Output file
        arguments.append(outputPath)

        process.arguments = arguments

        // Standard output/error pipes (for progress tracking)
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Read error output (FFmpeg outputs progress to stderr)
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self, !self.isCancelled else { return }

            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                // Parse FFmpeg progress (time=00:00:05.00)
                if let progress = self.parseFFmpegProgress(output: output, totalDuration: duration) {
                    DispatchQueue.main.async {
                        progressHandler(progress)
                    }
                }
            }
        }

        // Execute process
        currentProcess = process

        try process.run()
        process.waitUntilExit()

        // Check for cancellation
        if isCancelled {
            throw ExportError.cancelled
        }

        // Check termination status
        if process.terminationStatus != 0 {
            throw ExportError.ffmpegExecutionFailed("Exit code: \(process.terminationStatus)")
        }
    }

    /// Find FFmpeg executable path
    ///
    /// ## Search Priority
    /// 1. /usr/local/bin/ffmpeg (Homebrew default path)
    /// 2. /opt/homebrew/bin/ffmpeg (Apple Silicon Homebrew)
    /// 3. which ffmpeg (PATH environment variable)
    ///
    /// - Returns: FFmpeg path or nil
    private func findFFmpegPath() -> String? {
        // Check common paths
        let commonPaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // Find using which command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Parse FFmpeg progress
    ///
    /// ## FFmpeg Output Format
    /// ```
    /// frame=   75 fps= 25 q=-1.0 size=    1024kB time=00:00:03.00 bitrate=2793.5kbits/s speed=1.0x
    /// ```
    ///
    /// - Parameters:
    ///   - output: FFmpeg stderr output
    ///   - totalDuration: Total duration (seconds)
    /// - Returns: Progress (0.0 ~ 1.0) or nil
    private func parseFFmpegProgress(output: String, totalDuration: TimeInterval) -> Double? {
        // Find "time=" pattern
        guard let timeRange = output.range(of: "time=") else {
            return nil
        }

        // Extract time string (00:00:05.00 format)
        let timeStart = output.index(timeRange.upperBound, offsetBy: 0)
        let timeEnd = output.index(timeStart, offsetBy: 11, limitedBy: output.endIndex) ?? output.endIndex
        let timeString = output[timeStart..<timeEnd]

        // Parse time (HH:MM:SS.MS)
        let components = timeString.split(separator: ":")
        guard components.count == 3 else { return nil }

        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0

        let currentTime = hours * 3600 + minutes * 60 + seconds

        // Calculate progress
        return min(1.0, currentTime / totalDuration)
    }
}

// MARK: - Supporting Types

/// @enum ChannelPosition
/// @brief Camera channel position
///
/// ## Channel Types
/// - front: Front camera
/// - rear: Rear camera
/// - left: Left camera
/// - right: Right camera
enum ChannelPosition: String, Codable {
    case front = "front"
    case rear = "rear"
    case left = "left"
    case right = "right"

    var displayName: String {
        switch self {
        case .front:
            return "Front"
        case .rear:
            return "Rear"
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}
