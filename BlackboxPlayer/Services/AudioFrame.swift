/// @file AudioFrame.swift
/// @brief Decoded audio frame data model
/// @author BlackboxPlayer Development Team
/// @details
/// A structure containing raw audio data (PCM) decoded from FFmpeg.
/// When compressed audio (MP3/AAC) from video files is decoded, it produces
/// PCM (Pulse Code Modulation) raw audio data, which is managed per frame.
///
/// [Purpose of this file]
/// A structure containing raw audio data (PCM) decoded from FFmpeg.
/// When compressed audio (MP3/AAC) from video files is decoded, it produces
/// PCM (Pulse Code Modulation) raw audio data, which is managed per frame.
///
/// [What is an audio frame?]
/// Audio is processed in "frames" just like video:
/// - Video frame = One image
/// - Audio frame = A group of audio samples (typically 1024)
///
/// Example:
/// - Sample rate 48000Hz (48000 samples per second)
/// - 1024 samples per frame
/// - Frame duration = 1024 / 48000 = approximately 21ms
///
/// [What is PCM (Pulse Code Modulation)?]
/// The most basic form of converting analog sound to digital:
///
/// Analog sound wave  →  Sampling  →  Quantization  →  PCM data
///  (continuous wave)    (N times/sec)  (convert to numbers)  ([-1.0, 0.5, -0.3, ...])
///
/// Factors determining audio quality:
/// 1. Sample rate: How many measurements per second? (44.1kHz, 48kHz, etc.)
/// 2. Bit depth: How many bits represent each sample? (16bit, 32bit, etc.)
/// 3. Channel count: Mono(1)? Stereo(2)? 5.1 channel(6)?
///
/// [Data flow]
/// 1. VideoDecoder decodes MP3 with FFmpeg → PCM data generated
/// 2. AudioFrame structure stores PCM data + metadata
/// 3. AudioPlayer converts AudioFrame to AVAudioPCMBuffer
/// 4. AVAudioEngine plays through speakers
///
/// MP3 file (compressed) → FFmpeg decoding → AudioFrame (PCM) → AVAudioPCMBuffer → 🔊 playback
///

import Foundation
import AVFoundation

// MARK: - AudioFrame Structure

/// @struct AudioFrame
/// @brief Decoded audio frame (PCM sample data)
///
/// @details
/// A structure wrapping raw audio data decoded from FFmpeg for easy handling in Swift.
/// This structure contains the following information:
/// - Timestamp: At what point in the video does this audio belong?
/// - Audio format: Sample rate, channel count, data format
/// - PCM data: Actual audio sample values
///
/// ## Usage Example
/// ```swift
/// // Create audio frame decoded from FFmpeg
/// let frame = AudioFrame(
///     timestamp: 1.5,              // 1.5 second position in video
///     sampleRate: 48000,           // 48kHz (CD quality)
///     channels: 2,                 // Stereo
///     format: .floatPlanar,        // 32-bit float, planar layout
///     data: pcmData,               // Actual PCM bytes
///     sampleCount: 1024            // 1024 samples
/// )
///
/// // Convert to AVAudioPCMBuffer for playback
/// if let buffer = frame.toAudioBuffer() {
///     audioPlayer.enqueue(buffer)  // Add to playback queue
/// }
/// ```
///
/// ## Planar vs Interleaved Layout
/// Two ways to arrange stereo (2-channel) audio data in memory:
///
/// **Interleaved**: LRLRLRLR...
/// ```
/// [L0, R0, L1, R1, L2, R2, L3, R3, ...]
///  Left0, Right0, Left1, Right1...
/// ```
/// - Advantages: Memory contiguity, better cache efficiency
/// - Disadvantages: Requires stride for per-channel processing
///
/// **Planar**: LLL...RRR...
/// ```
/// [L0, L1, L2, L3, ...] [R0, R1, R2, R3, ...]
///  Entire left channel  Entire right channel
/// ```
/// - Advantages: Easier per-channel processing (DSP, effects)
/// - Disadvantages: Memory fragmentation
///
/// FFmpeg typically decodes to Planar format,
/// AVAudioEngine prefers Interleaved.
/// This structure handles the conversion.
struct AudioFrame {
    // MARK: - Properties

    /// @var timestamp
    /// @brief Presentation timestamp (in seconds)
    ///
    /// @details
    /// Indicates at what point in the video this audio frame should be played.
    ///
    /// **Why is this needed?**
    /// Essential for audio-video synchronization (Lip Sync).
    ///
    /// **Examples**:
    /// ```
    /// Frame 1: timestamp = 0.000s (start)
    /// Frame 2: timestamp = 0.021s (21ms later)
    /// Frame 3: timestamp = 0.043s (43ms later)
    /// ...
    /// ```
    ///
    /// Synchronization is achieved by comparing timestamps of video and audio frames.
    /// For example:
    /// - Video frame: 1.500s
    /// - Audio frame: 1.498s → Nearly matched (within ±2ms)
    let timestamp: TimeInterval

    /// @var sampleRate
    /// @brief Sample rate (samples per second)
    ///
    /// @details
    /// Indicates how many audio samples are measured per second.
    /// Higher values mean better quality but also larger data size.
    ///
    /// **Common sample rates**:
    /// - 8000 Hz: Telephone quality (low quality, voice calls)
    /// - 22050 Hz: Radio quality (medium quality)
    /// - 44100 Hz: CD quality (standard music quality) ⭐
    /// - 48000 Hz: DVD/Blu-ray quality (video standard) ⭐⭐
    /// - 96000 Hz: High-resolution audio (studio quality)
    ///
    /// **Nyquist theorem**:
    /// The highest frequency humans can hear is about 20kHz.
    /// To accurately reproduce this, a minimum sample rate of 40kHz is needed.
    /// (Sample rate ≥ 2 × maximum frequency)
    /// That's why CDs use 44.1kHz.
    ///
    /// **Example**:
    /// ```
    /// sampleRate = 48000 Hz
    /// → 1 second = 48,000 samples
    /// → 1ms = 48 samples
    /// → 1 sample = 0.0208ms
    /// ```
    let sampleRate: Int

    /// @var channels
    /// @brief Number of audio channels
    ///
    /// @details
    /// Indicates how many independent signal channels the audio has.
    ///
    /// **Channel configurations**:
    /// - 1 channel = Mono: Single speaker, voice recording
    /// - 2 channels = Stereo: Left/right separation, music/movie standard ⭐
    /// - 4 channels = Quad: Front/back + left/right
    /// - 5.1 channels = Home theater: 3 front + 2 rear + subwoofer
    /// - 7.1 channels = Premium home theater: 3 front + 2 side + 2 rear + subwoofer
    ///
    /// Dashcams typically use 1 channel (mono) or 2 channels (stereo).
    ///
    /// **Memory calculation**:
    /// ```
    /// channels = 2 (stereo)
    /// sampleCount = 1024
    /// bytesPerSample = 4 (float32)
    /// → Total size = 2 × 1024 × 4 = 8,192 bytes = 8KB
    /// ```
    let channels: Int

    /// @var format
    /// @brief Audio sample format (data type)
    ///
    /// @details
    /// Defines what data type is used to represent each PCM sample.
    /// Format affects audio quality, memory size, and processing speed.
    ///
    /// **Main formats**:
    /// - `.floatPlanar`: 32-bit float, planar layout (FFmpeg default) ⭐
    /// - `.floatInterleaved`: 32-bit float, interleaved layout
    /// - `.s16Planar`: 16-bit integer, planar layout (memory saving)
    /// - `.s16Interleaved`: 16-bit integer, interleaved layout (CD format)
    ///
    /// **Float vs Integer**:
    /// ```
    /// Float32 (32-bit floating point):
    /// - Range: -1.0 ~ +1.0 (normalized values)
    /// - Advantages: No overflow during processing, high precision
    /// - Disadvantages: 2x memory (4 bytes)
    ///
    /// Int16 (16-bit integer):
    /// - Range: -32768 ~ +32767
    /// - Advantages: Memory savings (2 bytes), CD standard
    /// - Disadvantages: Possible overflow during processing
    /// ```
    let format: AudioFormat

    /// @var data
    /// @brief Raw PCM audio data (byte array)
    ///
    /// @details
    /// Data storing actual audio sample values in binary format.
    /// How this data is interpreted depends on `format`, `channels`, and `sampleCount`.
    ///
    /// **Data structure example (stereo float planar)**:
    /// ```
    /// sampleCount = 4, channels = 2, format = .floatPlanar
    ///
    /// Memory layout:
    /// [L0_bytes][L1_bytes][L2_bytes][L3_bytes]  ← Left channel (16 bytes)
    /// [R0_bytes][R1_bytes][R2_bytes][R3_bytes]  ← Right channel (16 bytes)
    /// Total 32 bytes
    ///
    /// Float interpretation:
    /// Left: [-0.5, 0.3, -0.8, 0.1]
    /// Right: [-0.4, 0.2, -0.7, 0.0]
    /// ```
    ///
    /// **Data size calculation**:
    /// ```
    /// dataSize = sampleCount × channels × bytesPerSample
    ///          = 1024 × 2 × 4
    ///          = 8,192 bytes (8KB per frame)
    /// ```
    ///
    /// This Data is populated during FFmpeg decoding.
    let data: Data

    /// @var sampleCount
    /// @brief Number of samples (per channel)
    ///
    /// @details
    /// The number of audio samples contained in this frame.
    /// Note: This is **samples per channel**, not total samples!
    ///
    /// **Example**:
    /// ```
    /// sampleCount = 1024
    /// channels = 2 (stereo)
    /// → Left channel: 1024 samples
    /// → Right channel: 1024 samples
    /// → Total: 2048 samples (but sampleCount is 1024)
    /// ```
    ///
    /// **Common frame sizes**:
    /// - AAC: 1024 samples per frame
    /// - MP3: 1152 samples per frame
    /// - Opus: 120~960 samples (variable)
    ///
    /// **Duration calculation**:
    /// ```
    /// duration = sampleCount / sampleRate
    ///          = 1024 / 48000
    ///          = 0.0213s = 21.3ms
    /// ```
    let sampleCount: Int

    // MARK: - Initialization

    /// @brief Initialize audio frame
    ///
    /// @details
    /// Creates an AudioFrame from PCM data decoded by FFmpeg.
    /// Typically called internally by VideoDecoder; direct instantiation is rare.
    ///
    /// @param timestamp Position in video timeline (seconds)
    /// @param sampleRate Sampling frequency (Hz)
    /// @param channels Number of channels (1=mono, 2=stereo)
    /// @param format PCM sample format
    /// @param data Raw PCM byte data
    /// @param sampleCount Number of samples per channel
    ///
    /// ## Creation Example (Inside VideoDecoder)
    /// ```swift
    /// // Convert AVFrame decoded from FFmpeg to AudioFrame
    /// let pcmData = Data(bytes: avFrame.data[0], count: dataSize)
    ///
    /// let audioFrame = AudioFrame(
    ///     timestamp: avFrame.pts * timeBase,
    ///     sampleRate: avFrame.sample_rate,
    ///     channels: avFrame.channels,
    ///     format: .floatPlanar,
    ///     data: pcmData,
    ///     sampleCount: avFrame.nb_samples
    /// )
    /// ```
    init(
        timestamp: TimeInterval,
        sampleRate: Int,
        channels: Int,
        format: AudioFormat,
        data: Data,
        sampleCount: Int
    ) {
        self.timestamp = timestamp
        self.sampleRate = sampleRate
        self.channels = channels
        self.format = format
        self.data = data
        self.sampleCount = sampleCount
    }

    // MARK: - Computed Properties

    /// @brief Duration of this audio frame (seconds)
    ///
    /// @return Duration (TimeInterval)
    ///
    /// @details
    /// Calculates the time required to play this frame.
    ///
    /// **Calculation Formula**:
    /// ```
    /// duration = sampleCount / sampleRate
    /// ```
    ///
    /// **Example Calculations**:
    /// ```
    /// // AAC standard frame
    /// sampleCount = 1024
    /// sampleRate = 48000 Hz
    /// duration = 1024 / 48000 = 0.021333...s = 21.33ms
    ///
    /// // MP3 standard frame
    /// sampleCount = 1152
    /// sampleRate = 44100 Hz
    /// duration = 1152 / 44100 = 0.026122...s = 26.12ms
    /// ```
    ///
    /// **Use Cases**:
    /// - Timestamp calculation: `nextTimestamp = currentTimestamp + duration`
    /// - Buffering time calculation: `totalBufferedTime = sum(frame.duration)`
    /// - Synchronization verification: compare frame duration vs actual playback time
    var duration: TimeInterval {
        return Double(sampleCount) / Double(sampleRate)

        // Example result:
        // sampleCount=1024, sampleRate=48000
        // → 1024.0 / 48000.0 = 0.0213s = 21.3ms
    }

    /// @brief Total byte size of PCM data
    ///
    /// @return Data size (bytes)
    ///
    /// @details
    /// Returns the size of the byte array stored in the `data` property.
    ///
    /// **Size Calculation Examples**:
    /// ```
    /// // Stereo float planar
    /// sampleCount = 1024
    /// channels = 2
    /// bytesPerSample = 4 (float32)
    ///
    /// dataSize = 1024 × 2 × 4 = 8,192 bytes = 8KB
    ///
    /// // Data rate (48kHz stereo float)
    /// sampleRate = 48000
    /// frames_per_second = 48000 / 1024 ≈ 47 frames
    /// data_per_second = 8192 × 47 ≈ 385KB/s
    /// data_per_minute = 385KB × 60 ≈ 22.6MB/min
    /// ```
    ///
    /// **Size Comparison by Format (1024 samples, stereo)**:
    /// - Float32: 1024 × 2 × 4 = 8,192 bytes
    /// - Int16: 1024 × 2 × 2 = 4,096 bytes (50% savings!)
    var dataSize: Int {
        return data.count
    }

    /// @brief Byte size per sample (all channels included)
    ///
    /// @return Byte size
    ///
    /// @details
    /// The number of bytes required to store samples from all channels at one "time point".
    ///
    /// **Calculation Formula**:
    /// ```
    /// bytesPerSample = format.bytesPerSample × channels
    /// ```
    ///
    /// **Example Calculations**:
    /// ```
    /// // Float32 stereo
    /// format.bytesPerSample = 4 bytes (float32)
    /// channels = 2
    /// → bytesPerSample = 4 × 2 = 8 bytes
    ///   (left 4 bytes + right 4 bytes)
    ///
    /// // Int16 mono
    /// format.bytesPerSample = 2 bytes (int16)
    /// channels = 1
    /// → bytesPerSample = 2 × 1 = 2 bytes
    /// ```
    ///
    /// **Memory Layout in Interleaved Format**:
    /// ```
    /// bytesPerSample = 8 (Float32 Stereo)
    ///
    /// [L0: 4bytes][R0: 4bytes] ← sample 0 (8 bytes)
    /// [L1: 4bytes][R1: 4bytes] ← sample 1 (8 bytes)
    /// [L2: 4bytes][R2: 4bytes] ← sample 2 (8 bytes)
    /// ...
    /// ```
    var bytesPerSample: Int {
        return format.bytesPerSample * channels
    }

    // MARK: - Audio Buffer Conversion

    /// @brief Convert to AVAudioPCMBuffer (for playback)
    ///
    /// @return Converted AVAudioPCMBuffer, or nil on failure
    ///
    /// @details
    /// Converts FFmpeg PCM data to AVAudioPCMBuffer format
    /// that can be played by Apple's AVAudioEngine.
    ///
    /// **Conversion Process**:
    /// ```
    /// 1. Create AVAudioFormat
    ///    - Set sample rate, channel count, format info
    ///
    /// 2. Allocate AVAudioPCMBuffer
    ///    - Reserve required memory space
    ///
    /// 3. Copy PCM data
    ///    - Planar → Planar: copy per channel
    ///    - Interleaved → Interleaved: copy entire block
    ///
    /// 4. Set frameLength
    ///    - Indicate actual number of samples used
    /// ```
    ///
    /// **Planar vs Interleaved Conversion**:
    /// ```
    /// Planar input (FFmpeg default):
    /// data = [L0,L1,L2,L3][R0,R1,R2,R3]
    ///         ↓ copy per channel
    /// AVAudioPCMBuffer (Planar):
    /// channelData[0] = [L0,L1,L2,L3]
    /// channelData[1] = [R0,R1,R2,R3]
    ///
    /// Interleaved input:
    /// data = [L0,R0,L1,R1,L2,R2,L3,R3]
    ///         ↓ copy entire block
    /// AVAudioPCMBuffer (Interleaved):
    /// channelData[0] = [L0,R0,L1,R1,L2,R2,L3,R3]
    /// ```
    ///
    /// **Actual Usage Example**:
    /// ```swift
    /// // Playback in AudioPlayer
    /// func playFrame(_ frame: AudioFrame) {
    ///     guard let buffer = frame.toAudioBuffer() else {
    ///         print("Buffer conversion failed")
    ///         return
    ///     }
    ///
    ///     // Schedule to AVAudioPlayerNode
    ///     playerNode.scheduleBuffer(buffer) {
    ///         print("Playback complete")
    ///     }
    /// }
    /// ```
    ///
    /// **Failure Cases**:
    /// - Unsupported audio format
    /// - Invalid sample rate or channel count
    /// - Out of memory
    func toAudioBuffer() -> AVAudioPCMBuffer? {
        // Step 1: Create AVAudioFormat
        // Create a format object that Apple's audio system can understand
        guard let audioFormat = AVAudioFormat(
            commonFormat: format.commonFormat,      // Sample type (.pcmFormatFloat32, etc.)
            sampleRate: Double(sampleRate),         // 48000.0 Hz
            channels: AVAudioChannelCount(channels), // 2 (stereo)
            interleaved: format.isInterleaved       // false (planar)
        ) else {
            // Format creation failed = unsupported combination
            return nil
        }

        // Step 2: Allocate AVAudioPCMBuffer
        // Create memory buffer to hold actual PCM data
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,                        // Format created above
            frameCapacity: AVAudioFrameCount(sampleCount) // Maximum 1024 samples
        ) else {
            // Buffer allocation failed = out of memory
            return nil
        }

        // Set actual frame count to use (important!)
        // frameCapacity is "maximum capacity", frameLength is "actual usage"
        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // Example:
        // frameCapacity = 1024 (allocated space)
        // frameLength = 512 (actually used space)
        // → Only 512 samples will be played

        // Step 3: Copy PCM data
        // self.data (Data) → buffer.floatChannelData (UnsafeMutablePointer)

        if format.isInterleaved {
            // ═══════════════════════════════════════════════════════════
            // Interleaved format: LRLRLR... pattern
            // ═══════════════════════════════════════════════════════════
            //
            // Data layout (stereo):
            // [L0, R0, L1, R1, L2, R2, ...]
            //
            // AVAudioPCMBuffer (Interleaved):
            // channelData[0] = all data (L and R interleaved)
            //
            // Copy method: memcpy entire block at once
            //
            if let channelData = buffer.floatChannelData {
                // Access Data as unsafe bytes
                data.withUnsafeBytes { dataBytes in
                    // baseAddress = starting pointer of Data
                    if let sourcePtr = dataBytes.baseAddress {
                        // Copy entire data to channelData[0]
                        memcpy(
                            channelData[0],   // Destination: buffer's first channel
                            sourcePtr,        // Source: start of self.data
                            data.count        // Size: total bytes
                        )

                        // Example: copy 8 bytes (Float32 stereo, 1 sample)
                        // sourcePtr:      [L0:4byte][R0:4byte]
                        //                    ↓ memcpy
                        // channelData[0]: [L0:4byte][R0:4byte]
                    }
                }
            }

        } else {
            // ═══════════════════════════════════════════════════════════
            // Planar format: LLL...RRR... pattern (FFmpeg default)
            // ═══════════════════════════════════════════════════════════
            //
            // Data layout (stereo):
            // [L0, L1, L2, ...] [R0, R1, R2, ...]
            //  entire left ch    entire right ch
            //
            // AVAudioPCMBuffer (Planar):
            // channelData[0] = [L0, L1, L2, ...]
            // channelData[1] = [R0, R1, R2, ...]
            //
            // Copy method: memcpy per channel
            //
            if let channelData = buffer.floatChannelData {
                // Calculate byte size per channel
                let bytesPerChannel = sampleCount * format.bytesPerSample
                // Example: 1024 samples × 4 bytes (float32) = 4096 bytes

                data.withUnsafeBytes { dataBytes in
                    if let sourcePtr = dataBytes.baseAddress {
                        // Iterate through each channel and copy
                        for channel in 0..<channels {
                            // Calculate starting position for this channel's data
                            let offset = channel * bytesPerChannel

                            // Example (stereo):
                            // channel 0 (left): offset = 0 × 4096 = 0
                            // channel 1 (right): offset = 1 × 4096 = 4096
                            //
                            // Memory map:
                            // sourcePtr + 0    : [L0,L1,L2,L3,...] (4096 bytes)
                            // sourcePtr + 4096 : [R0,R1,R2,R3,...] (4096 bytes)

                            // Copy this channel's data to buffer
                            memcpy(
                                channelData[channel],  // Destination: per-channel buffer
                                sourcePtr + offset,    // Source: channel start position
                                bytesPerChannel        // Size: 4096 bytes
                            )

                            // Result:
                            // channelData[0] ← [L0,L1,L2,L3,...]
                            // channelData[1] ← [R0,R1,R2,R3,...]
                        }
                    }
                }
            }
        }

        // Step 4: Return converted buffer
        // Now playable via AVAudioPlayerNode.scheduleBuffer()
        return buffer
    }
}

// MARK: - Supporting Types

/// @enum AudioFormat
/// @brief Audio sample format definition
///
/// @details
/// Defines how PCM (Pulse Code Modulation) samples are stored in memory.
/// Format selection affects audio quality, memory size, and processing speed.
///
/// ## Format Selection Guide
///
/// **Float (floating-point) vs Integer**:
/// ```
/// Float format (recommended):
/// ✅ No overflow during processing (-1.0 ~ +1.0 normalized)
/// ✅ High precision (32-bit = ~150dB dynamic range)
/// ✅ Easy DSP operations (amplification, mixing, etc.)
/// ❌ 2x memory (4 bytes)
/// ❌ Inefficient for disk storage
///
/// Integer format:
/// ✅ Memory savings (2 bytes)
/// ✅ CD standard (Int16)
/// ✅ Efficient disk storage
/// ❌ Watch for overflow during processing
/// ❌ Limited precision (16-bit = 96dB)
/// ```
///
/// **Planar vs Interleaved**:
/// ```
/// Planar (channel separation):
/// ✅ Easy per-channel processing (volume, effects)
/// ✅ FFmpeg default output
/// ❌ Lower cache efficiency
/// ❌ Memory fragmentation
///
/// Interleaved (channel interleaving):
/// ✅ Memory contiguity
/// ✅ Higher cache efficiency
/// ✅ CD/file storage standard
/// ❌ Requires stride for per-channel processing
/// ```
///
/// ## Memory Size Comparison by Format
/// (1024 samples, stereo, 48kHz)
///
/// | Format | 1 frame | 1 sec | 1 min |
/// |--------|---------|-------|-------|
/// | Float32 | 8KB | 375KB | 22MB |
/// | Int16 | 4KB | 188KB | 11MB |
///
/// ## Usage Example
/// ```swift
/// // FFmpeg decoding result (typically Planar)
/// let format: AudioFormat = .floatPlanar
///
/// // Automatic conversion for AVAudioEngine playback
/// if format.isInterleaved {
///     // Use as is
/// } else {
///     // Planar → Interleaved conversion (inside toAudioBuffer)
/// }
/// ```
enum AudioFormat: String, Codable {
    // ═══════════════════════════════════════════════════════
    // Float format (32-bit floating-point)
    // ═══════════════════════════════════════════════════════

    /// @brief 32-bit Float (Planar layout)
    ///
    /// @details
    /// FFmpeg's default audio output format.
    /// Samples of each channel are stored separately and contiguously in memory.
    ///
    /// **Memory Layout (stereo, 4 samples)**:
    /// ```
    /// Offset 0~15:  [L0][L1][L2][L3]  ← left channel (16 bytes)
    /// Offset 16~31: [R0][R1][R2][R3]  ← right channel (16 bytes)
    /// ```
    ///
    /// **Sample Value Range**: -1.0 ~ +1.0
    /// - -1.0 = maximum sound pressure (negative)
    /// -  0.0 = silence
    /// - +1.0 = maximum sound pressure (positive)
    ///
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_FLTP`
    /// - CoreAudio: `kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved`
    /// - Size: 4 bytes × sample count × channel count
    case floatPlanar = "fltp"

    /// @brief 32-bit Float (Interleaved layout)
    ///
    /// @details
    /// For stereo, left and right samples alternate.
    /// Preferred format by some audio processing libraries.
    ///
    /// **Memory Layout (stereo, 4 samples)**:
    /// ```
    /// [L0][R0][L1][R1][L2][R2][L3][R3]
    ///  ↑   ↑   ↑   ↑   ...
    ///  L   R   L   R
    /// ```
    ///
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_FLT`
    /// - CoreAudio: `kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked`
    /// - Size: 4 bytes × sample count × channel count
    case floatInterleaved = "flt"

    // ═══════════════════════════════════════════════════════
    // Integer format (16-bit/32-bit integer)
    // ═══════════════════════════════════════════════════════

    /// @brief 16-bit Signed Integer (Planar layout)
    ///
    /// @details
    /// Saves memory while providing CD quality.
    /// Stored separately per channel.
    ///
    /// **Memory Layout (stereo, 4 samples)**:
    /// ```
    /// Offset 0~7:  [L0][L1][L2][L3]  ← left channel (8 bytes)
    /// Offset 8~15: [R0][R1][R2][R3]  ← right channel (8 bytes)
    /// ```
    ///
    /// **Sample Value Range**: -32768 ~ +32767
    /// - -32768 = maximum sound pressure (negative)
    /// -      0 = silence
    /// - +32767 = maximum sound pressure (positive)
    ///
    /// **Float Conversion**:
    /// ```
    /// intValue → floatValue:
    /// floatValue = intValue / 32768.0
    ///
    /// Examples:
    /// 32767 → 32767 / 32768.0 = +0.999969... ≈ +1.0
    /// -16384 → -16384 / 32768.0 = -0.5
    /// 0 → 0 / 32768.0 = 0.0
    /// ```
    ///
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S16P`
    /// - CD standard (CD-DA)
    /// - Size: Half of Float (2 bytes × sample count × channel count)
    case s16Planar = "s16p"

    /// @brief 16-bit Signed Integer (Interleaved layout)
    ///
    /// @details
    /// CD audio standard format.
    /// Also the default format for WAV files.
    ///
    /// **Memory Layout (stereo, 4 samples)**:
    /// ```
    /// [L0][R0][L1][R1][L2][R2][L3][R3]
    /// Each sample 2 bytes, total 16 bytes
    /// ```
    ///
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S16`
    /// - CD standard, WAV standard
    /// - Size: 2 bytes × sample count × channel count
    case s16Interleaved = "s16"

    /// @brief 32-bit Signed Integer (Planar layout)
    ///
    /// @details
    /// Used when high quality is needed but floating-point operations should be avoided.
    /// Used in DVD-Audio and some high-end audio equipment.
    ///
    /// **Sample Value Range**: -2,147,483,648 ~ +2,147,483,647
    ///
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S32P`
    /// - Size: 4 bytes × sample count × channel count (same as Float)
    case s32Planar = "s32p"

    /// @brief 32-bit Signed Integer (Interleaved layout)
    ///
    /// @details
    /// **Characteristics**:
    /// - FFmpeg: `AV_SAMPLE_FMT_S32`
    /// - Size: 4 bytes × sample count × channel count
    case s32Interleaved = "s32"

    /// @brief Byte size per sample
    ///
    /// @return Byte size
    ///
    /// @details
    /// The number of bytes required to store one sample value, excluding channel count.
    ///
    /// **Return Values**:
    /// ```
    /// Float32 / Int32: 4 bytes
    /// Int16:           2 bytes
    /// ```
    var bytesPerSample: Int {
        switch self {
        case .floatPlanar, .floatInterleaved, .s32Planar, .s32Interleaved:
            return 4  // 32-bit = 4 bytes
        case .s16Planar, .s16Interleaved:
            return 2  // 16-bit = 2 bytes
        }
    }

    /// @brief Is this an interleaved format?
    ///
    /// @return true if Interleaved, false if Planar
    ///
    /// @details
    /// Returns whether channels are interleaved or separated (planar).
    ///
    /// **Return Values**:
    /// ```
    /// Interleaved formats: true  (flt, s16, s32)
    /// Planar formats:      false (fltp, s16p, s32p)
    /// ```
    var isInterleaved: Bool {
        switch self {
        case .floatInterleaved, .s16Interleaved, .s32Interleaved:
            return true  // Interleaved layout
        case .floatPlanar, .s16Planar, .s32Planar:
            return false // Planar layout
        }
    }

    /// @brief Convert to AVAudioCommonFormat
    ///
    /// @return AVAudioCommonFormat
    ///
    /// @details
    /// Converts to the standard format enum used by Apple's AVFoundation.
    /// Used when creating AVAudioFormat in the toAudioBuffer() method.
    ///
    /// **Mapping**:
    /// ```
    /// Float (32-bit) → .pcmFormatFloat32
    /// Int16 (16-bit) → .pcmFormatInt16
    /// Int32 (32-bit) → .pcmFormatInt32
    /// ```
    var commonFormat: AVAudioCommonFormat {
        switch self {
        case .floatPlanar, .floatInterleaved:
            return .pcmFormatFloat32
        case .s16Planar, .s16Interleaved:
            return .pcmFormatInt16
        case .s32Planar, .s32Interleaved:
            return .pcmFormatInt32
        }
    }
}

// MARK: - Equatable

/// @brief AudioFrame equality comparison
///
/// @details
/// Determines if two AudioFrames are "the same" frame.
/// Mainly used for debugging, testing, and duplicate removal.
///
/// **Comparison Criteria**:
/// - timestamp: Same time point?
/// - sampleCount: Same number of samples?
/// - sampleRate: Same sample rate?
/// - channels: Same channel count?
///
/// **Note**: `data` is NOT compared!
/// Even if the actual PCM byte data differs, frames are considered "equal" if metadata matches.
/// This is for performance reasons (data can be thousands of bytes).
///
/// ## Usage Example
/// ```swift
/// let frame1 = AudioFrame(timestamp: 1.0, ...)
/// let frame2 = AudioFrame(timestamp: 1.0, ...)
/// let frame3 = AudioFrame(timestamp: 2.0, ...)
///
/// frame1 == frame2  // true (same timestamp)
/// frame1 == frame3  // false (different timestamp)
///
/// // Remove duplicate frames
/// let frames = [frame1, frame2, frame3]
/// let uniqueFrames = Array(Set(frames))  // [frame1, frame3]
/// ```
extension AudioFrame: Equatable {
    /// @brief Compare two AudioFrames
    /// @param lhs Left-hand side operand
    /// @param rhs Right-hand side operand
    /// @return true if equal
    static func == (lhs: AudioFrame, rhs: AudioFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
            lhs.sampleCount == rhs.sampleCount &&
            lhs.sampleRate == rhs.sampleRate &&
            lhs.channels == rhs.channels

        // data is not compared (for performance)
        // Can add data comparison if needed:
        // && lhs.data == rhs.data
    }
}

// MARK: - CustomStringConvertible

/// @brief AudioFrame debug string representation
///
/// @details
/// Converts AudioFrame to a readable format when printed or displayed in debugger.
///
/// **Output Example**:
/// ```
/// Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
///
/// Interpretation:
/// - Timestamp: 1.500 seconds
/// - Sample rate: 48000 Hz
/// - Channels: stereo (2 channels)
/// - Format: fltp (Float32 Planar)
/// - Sample count: 1024 samples
/// - Data size: 8192 bytes (8KB)
/// ```
///
/// **Channel Display**:
/// ```
/// channels = 1 → "mono"
/// channels = 2 → "stereo"
/// channels = 6 → "6ch" (5.1 surround)
/// ```
///
/// ## Usage Example
/// ```swift
/// let frame = AudioFrame(...)
///
/// // Direct output
/// print(frame)
/// // Output: Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
///
/// // Include in log
/// print("Playing: \(frame)")
/// // Output: Playing: Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes
/// ```
extension AudioFrame: CustomStringConvertible {
    /// @brief Debug string
    var description: String {
        // Convert channel count to human-readable string
        let channelStr: String
        if channels == 1 {
            channelStr = "mono"      // Mono
        } else if channels == 2 {
            channelStr = "stereo"    // Stereo
        } else {
            channelStr = "\(channels)ch"  // "6ch", "8ch", etc.
        }

        // Generate formatted string
        return String(
            format: "Audio @ %.3fs (%d Hz, %@, %@ format) %d samples, %d bytes",
            timestamp,              // Timestamp (3 decimal places)
            sampleRate,            // Sample rate
            channelStr,            // Channel string
            format.rawValue,       // Format ("fltp", "s16", etc.)
            sampleCount,           // Sample count
            dataSize               // Byte size
        )

        // Example result:
        // "Audio @ 1.500s (48000 Hz, stereo, fltp format) 1024 samples, 8192 bytes"
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Integrated Guide: AudioFrame Usage Flow
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ Decoding (VideoDecoder)
// ────────────────────────────────────────────────
// MP3/AAC file → FFmpeg decoding → PCM data
//
// let audioFrame = AudioFrame(
//     timestamp: pts,
//     sampleRate: 48000,
//     channels: 2,
//     format: .floatPlanar,
//     data: pcmData,
//     sampleCount: 1024
// )
//
// 2️⃣ Queueing (VideoChannel)
// ────────────────────────────────────────────────
// Store decoded frames in buffer
//
// audioBuffer.append(audioFrame)
//
// 3️⃣ Synchronization (SyncController)
// ────────────────────────────────────────────────
// Compare timestamps with video frames
//
// if abs(videoFrame.timestamp - audioFrame.timestamp) < 0.05 {
//     // Sync OK (within ±50ms)
// }
//
// 4️⃣ Playback (AudioPlayer)
// ────────────────────────────────────────────────
// Convert to AVAudioPCMBuffer and play
//
// if let buffer = audioFrame.toAudioBuffer() {
//     playerNode.scheduleBuffer(buffer)
// }
//
// 5️⃣ Speaker Output
// ────────────────────────────────────────────────
// AVAudioEngine → System Audio → 🔊
//
// ═══════════════════════════════════════════════════════════════════════════
