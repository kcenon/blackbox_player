//
//  MetadataExtractor.swift
//  BlackboxPlayer
//
//  Service for extracting GPS and acceleration metadata from video files
//

import Foundation

/// Service for extracting metadata (GPS and acceleration) from dashcam videos
class MetadataExtractor {
    // MARK: - Properties

    private let gpsParser: GPSParser
    private let accelerationParser: AccelerationParser

    // MARK: - Initialization

    init() {
        self.gpsParser = GPSParser()
        self.accelerationParser = AccelerationParser()
    }

    // MARK: - Public Methods

    /// Extract metadata from video file
    /// - Parameter filePath: Path to video file
    /// - Returns: VideoMetadata or nil if extraction fails
    func extractMetadata(from filePath: String) -> VideoMetadata? {
        // Open video file
        var formatContext: OpaquePointer?
        guard avformat_open_input(&formatContext, filePath, nil, nil) == 0 else {
            return nil
        }
        defer {
            if let ctx = formatContext {
                var mutableCtx = UnsafeMutablePointer(mutating: ctx)
                avformat_close_input(&mutableCtx)
            }
        }

        // Find stream info
        guard avformat_find_stream_info(formatContext, nil) >= 0,
              let formatCtx = formatContext else {
            return nil
        }

        // Get base timestamp from file
        let baseDate = extractBaseDate(from: filePath) ?? Date()

        // Extract GPS data from metadata
        let gpsPoints = extractGPSData(from: formatCtx, baseDate: baseDate)

        // Extract acceleration data from metadata
        let accelerationData = extractAccelerationData(from: formatCtx, baseDate: baseDate)

        // Extract device information
        let deviceInfo = extractDeviceInfo(from: formatCtx)

        return VideoMetadata(
            gpsPoints: gpsPoints,
            accelerationData: accelerationData,
            deviceInfo: deviceInfo
        )
    }

    // MARK: - Private Methods

    private func extractBaseDate(from filePath: String) -> Date? {
        // Try to extract date from filename (BlackVue format: YYYYMMDD_HHMMSS)
        let filename = (filePath as NSString).lastPathComponent
        let pattern = #"(\d{8})_(\d{6})"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: filename, options: [], range: NSRange(filename.startIndex..., in: filename)) else {
            return nil
        }

        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        return dateFormatter.date(from: dateString + timeString)
    }

    private func extractGPSData(from formatContext: OpaquePointer, baseDate: Date) -> [GPSPoint] {
        // Look for GPS metadata in various places

        // 1. Check for subtitle/data streams containing GPS data
        let numStreams = Int(formatContext.pointee.nb_streams)
        var streams = formatContext.pointee.streams

        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }
            let codecType = stream.pointee.codecpar.pointee.codec_type

            // GPS data might be in data or subtitle streams
            if codecType == AVMEDIA_TYPE_DATA || codecType == AVMEDIA_TYPE_SUBTITLE {
                if let gpsData = readStreamData(from: formatContext, streamIndex: i) {
                    let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
                    if !points.isEmpty {
                        return points
                    }
                }
            }
        }

        // 2. Check for GPS metadata in format-level metadata
        if let metadata = formatContext.pointee.metadata {
            if let gpsData = extractMetadataEntry(metadata, key: "gps") {
                let points = gpsParser.parseNMEA(data: gpsData, baseDate: baseDate)
                if !points.isEmpty {
                    return points
                }
            }
        }

        // 3. Check for GPMD (GoPro Metadata) or similar
        // This would require more specific parsing for different camera formats

        return []
    }

    private func extractAccelerationData(from formatContext: OpaquePointer, baseDate: Date) -> [AccelerationData] {
        // Look for acceleration metadata

        let numStreams = Int(formatContext.pointee.nb_streams)
        var streams = formatContext.pointee.streams

        for i in 0..<numStreams {
            guard let stream = streams?[i] else { continue }
            let codecType = stream.pointee.codecpar.pointee.codec_type

            // Acceleration data might be in data streams
            if codecType == AVMEDIA_TYPE_DATA {
                if let accelData = readStreamData(from: formatContext, streamIndex: i) {
                    // Try binary format first
                    let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
                    if !data.isEmpty {
                        return data
                    }

                    // Try CSV format
                    let csvData = accelerationParser.parseCSVData(accelData, baseDate: baseDate)
                    if !csvData.isEmpty {
                        return csvData
                    }
                }
            }
        }

        // Check format-level metadata
        if let metadata = formatContext.pointee.metadata {
            if let accelData = extractMetadataEntry(metadata, key: "accelerometer") ??
                               extractMetadataEntry(metadata, key: "gsensor") {
                let data = accelerationParser.parseAccelerationData(accelData, baseDate: baseDate)
                if !data.isEmpty {
                    return data
                }
            }
        }

        return []
    }

    private func extractDeviceInfo(from formatContext: OpaquePointer) -> DeviceInfo? {
        guard let metadata = formatContext.pointee.metadata else {
            return nil
        }

        // Extract common device metadata fields
        let manufacturer = extractMetadataString(metadata, key: "manufacturer") ??
                          extractMetadataString(metadata, key: "make")
        let model = extractMetadataString(metadata, key: "model")
        let firmware = extractMetadataString(metadata, key: "firmware") ??
                      extractMetadataString(metadata, key: "firmware_version")
        let serial = extractMetadataString(metadata, key: "serial_number") ??
                    extractMetadataString(metadata, key: "device_id")
        let mode = extractMetadataString(metadata, key: "recording_mode")

        // Only return DeviceInfo if we found at least one field
        if manufacturer != nil || model != nil || firmware != nil || serial != nil || mode != nil {
            return DeviceInfo(
                manufacturer: manufacturer,
                model: model,
                firmwareVersion: firmware,
                serialNumber: serial,
                recordingMode: mode
            )
        }

        return nil
    }

    private func readStreamData(from formatContext: OpaquePointer, streamIndex: Int) -> Data? {
        var accumulatedData = Data()

        // Allocate packet
        guard let packet = av_packet_alloc() else {
            return nil
        }
        defer { av_packet_free(&(UnsafeMutablePointer(mutating: packet))) }

        // Read packets from stream
        while av_read_frame(formatContext, packet) >= 0 {
            defer { av_packet_unref(packet) }

            if Int(packet.pointee.stream_index) == streamIndex {
                // Append packet data
                if let data = packet.pointee.data {
                    let size = Int(packet.pointee.size)
                    accumulatedData.append(Data(bytes: data, count: size))
                }
            }
        }

        // Seek back to beginning
        av_seek_frame(formatContext, Int32(streamIndex), 0, AVSEEK_FLAG_BACKWARD)

        return accumulatedData.isEmpty ? nil : accumulatedData
    }

    private func extractMetadataEntry(_ dict: OpaquePointer, key: String) -> Data? {
        var entry: UnsafeMutablePointer<AVDictionaryEntry>?
        entry = av_dict_get(dict, key, nil, 0)

        guard let entry = entry, let value = entry.pointee.value else {
            return nil
        }

        let string = String(cString: value)
        return string.data(using: .utf8)
    }

    private func extractMetadataString(_ dict: OpaquePointer, key: String) -> String? {
        var entry: UnsafeMutablePointer<AVDictionaryEntry>?
        entry = av_dict_get(dict, key, nil, 0)

        guard let entry = entry, let value = entry.pointee.value else {
            return nil
        }

        return String(cString: value)
    }
}

// MARK: - Extraction Errors

enum MetadataExtractionError: Error {
    case cannotOpenFile(String)
    case noMetadataFound
    case invalidMetadataFormat
}

extension MetadataExtractionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path):
            return "Cannot open file: \(path)"
        case .noMetadataFound:
            return "No metadata found in file"
        case .invalidMetadataFormat:
            return "Invalid metadata format"
        }
    }
}
