//
//  AudioFrame.swift
//  BlackboxPlayer
//
//  Model for decoded audio frame
//

import Foundation
import AVFoundation

/// Decoded audio frame with PCM samples
struct AudioFrame {
    /// Presentation timestamp in seconds
    let timestamp: TimeInterval

    /// Sample rate (samples per second)
    let sampleRate: Int

    /// Number of audio channels (1=mono, 2=stereo)
    let channels: Int

    /// Audio sample format
    let format: AudioFormat

    /// Raw PCM audio data
    let data: Data

    /// Number of samples (per channel)
    let sampleCount: Int

    // MARK: - Initialization

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

    /// Duration of this audio frame in seconds
    var duration: TimeInterval {
        return Double(sampleCount) / Double(sampleRate)
    }

    /// Total size in bytes
    var dataSize: Int {
        return data.count
    }

    /// Bytes per sample
    var bytesPerSample: Int {
        return format.bytesPerSample * channels
    }

    // MARK: - Audio Buffer Conversion

    /// Convert to AVAudioPCMBuffer for playback
    /// - Returns: AVAudioPCMBuffer or nil if conversion fails
    func toAudioBuffer() -> AVAudioPCMBuffer? {
        guard let audioFormat = AVAudioFormat(
            commonFormat: format.commonFormat,
            sampleRate: Double(sampleRate),
            channels: AVAudioChannelCount(channels),
            interleaved: format.isInterleaved
        ) else {
            return nil
        }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: AVAudioFrameCount(sampleCount)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(sampleCount)

        // Copy audio data to buffer
        if format.isInterleaved {
            // Interleaved format: LRLRLR...
            if let channelData = buffer.floatChannelData {
                data.withUnsafeBytes { dataBytes in
                    if let sourcePtr = dataBytes.baseAddress {
                        memcpy(channelData[0], sourcePtr, data.count)
                    }
                }
            }
        } else {
            // Planar format: LLL...RRR...
            if let channelData = buffer.floatChannelData {
                let bytesPerChannel = sampleCount * format.bytesPerSample
                data.withUnsafeBytes { dataBytes in
                    if let sourcePtr = dataBytes.baseAddress {
                        for channel in 0..<channels {
                            let offset = channel * bytesPerChannel
                            memcpy(channelData[channel], sourcePtr + offset, bytesPerChannel)
                        }
                    }
                }
            }
        }

        return buffer
    }
}

// MARK: - Supporting Types

/// Audio sample format
enum AudioFormat: String, Codable {
    /// 32-bit floating point (planar)
    case floatPlanar = "fltp"

    /// 32-bit floating point (interleaved)
    case floatInterleaved = "flt"

    /// 16-bit signed integer (planar)
    case s16Planar = "s16p"

    /// 16-bit signed integer (interleaved)
    case s16Interleaved = "s16"

    /// 32-bit signed integer (planar)
    case s32Planar = "s32p"

    /// 32-bit signed integer (interleaved)
    case s32Interleaved = "s32"

    var bytesPerSample: Int {
        switch self {
        case .floatPlanar, .floatInterleaved, .s32Planar, .s32Interleaved:
            return 4
        case .s16Planar, .s16Interleaved:
            return 2
        }
    }

    var isInterleaved: Bool {
        switch self {
        case .floatInterleaved, .s16Interleaved, .s32Interleaved:
            return true
        case .floatPlanar, .s16Planar, .s32Planar:
            return false
        }
    }

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

extension AudioFrame: Equatable {
    static func == (lhs: AudioFrame, rhs: AudioFrame) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.sampleCount == rhs.sampleCount &&
               lhs.sampleRate == rhs.sampleRate &&
               lhs.channels == rhs.channels
    }
}

// MARK: - CustomStringConvertible

extension AudioFrame: CustomStringConvertible {
    var description: String {
        let channelStr = channels == 1 ? "mono" : channels == 2 ? "stereo" : "\(channels)ch"
        return String(format: "Audio @ %.3fs (%d Hz, %@, %@ format) %d samples, %d bytes",
                     timestamp, sampleRate, channelStr, format.rawValue,
                     sampleCount, dataSize)
    }
}
