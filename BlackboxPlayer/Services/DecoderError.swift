//
//  DecoderError.swift
//  BlackboxPlayer
//
//  Error types for video/audio decoder
//

import Foundation

/// Errors that can occur during video/audio decoding
enum DecoderError: Error {
    /// Failed to open input file
    case cannotOpenFile(String)

    /// Failed to find stream information
    case cannotFindStreamInfo(String)

    /// No video stream found in file
    case noVideoStream

    /// No audio stream found in file
    case noAudioStream

    /// Failed to find codec for stream
    case codecNotFound(String)

    /// Failed to allocate codec context
    case cannotAllocateCodecContext

    /// Failed to copy codec parameters
    case cannotCopyCodecParameters

    /// Failed to open codec
    case cannotOpenCodec(String)

    /// Failed to allocate frame
    case cannotAllocateFrame

    /// Failed to allocate packet
    case cannotAllocatePacket

    /// Failed to read frame from file
    case readFrameError(Int32)

    /// Failed to send packet to decoder
    case sendPacketError(Int32)

    /// Failed to receive frame from decoder
    case receiveFrameError(Int32)

    /// Failed to initialize scaler/resampler
    case scalerInitError

    /// Failed to scale/convert frame
    case scaleFrameError

    /// Invalid stream index
    case invalidStreamIndex(Int)

    /// Decoder already initialized
    case alreadyInitialized

    /// Decoder not initialized
    case notInitialized

    /// End of file reached
    case endOfFile

    /// Unknown error
    case unknown(String)
}

extension DecoderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"
        case .cannotFindStreamInfo(let path):
            return "Cannot find stream information: \(path)"
        case .noVideoStream:
            return "No video stream found"
        case .noAudioStream:
            return "No audio stream found"
        case .codecNotFound(let name):
            return "Codec not found: \(name)"
        case .cannotAllocateCodecContext:
            return "Cannot allocate codec context"
        case .cannotCopyCodecParameters:
            return "Cannot copy codec parameters"
        case .cannotOpenCodec(let name):
            return "Cannot open codec: \(name)"
        case .cannotAllocateFrame:
            return "Cannot allocate frame"
        case .cannotAllocatePacket:
            return "Cannot allocate packet"
        case .readFrameError(let code):
            return "Read frame error: \(code)"
        case .sendPacketError(let code):
            return "Send packet error: \(code)"
        case .receiveFrameError(let code):
            return "Receive frame error: \(code)"
        case .scalerInitError:
            return "Scaler initialization error"
        case .scaleFrameError:
            return "Frame scaling error"
        case .invalidStreamIndex(let index):
            return "Invalid stream index: \(index)"
        case .alreadyInitialized:
            return "Decoder already initialized"
        case .notInitialized:
            return "Decoder not initialized"
        case .endOfFile:
            return "End of file reached"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}
