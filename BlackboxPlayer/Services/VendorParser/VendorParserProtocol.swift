/**
 * @file VendorParserProtocol.swift
 * @brief Vendor-specific file parsing interface
 * @author BlackboxPlayer Development Team
 *
 * @details
 * Protocol to support various dashcam vendor file formats.
 * Each vendor implements this protocol to handle their own filename format and metadata.
 */

import Foundation

// ============================================================================
// MARK: - VendorParserProtocol
// ============================================================================

/**
 * @protocol VendorParserProtocol
 * @brief Vendor-specific file parsing interface
 *
 * @details
 * Each dashcam vendor implements this protocol to:
 * - Match filename patterns
 * - Extract metadata
 * - Parse GPS/acceleration data
 * - Support vendor-specific features
 */
protocol VendorParserProtocol {
    /// Vendor identifier (e.g., "blackvue", "cr2000omega")
    var vendorId: String { get }

    /// Vendor display name (e.g., "BlackVue", "CR-2000 OMEGA")
    var vendorName: String { get }

    /**
     * @brief Check if filename matches this vendor's format
     * @param filename Filename to check
     * @return Whether it matches
     */
    func matches(_ filename: String) -> Bool

    /**
     * @brief Extract metadata from filename
     * @param fileURL Video file URL
     * @return VideoFileInfo or nil (if parsing fails)
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo?

    /**
     * @brief Extract GPS data from video
     * @param fileURL Video file URL
     * @return Array of GPSPoint
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint]

    /**
     * @brief Extract acceleration data from video
     * @param fileURL Video file URL
     * @return Array of AccelerationData
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData]

    /**
     * @brief List of vendor-supported features
     * @return Array of VendorFeature
     */
    func supportedFeatures() -> [VendorFeature]
}

// ============================================================================
// MARK: - VendorFeature
// ============================================================================

/**
 * @enum VendorFeature
 * @brief Vendor-supported features
 *
 * @details
 * Enumerates features provided by each dashcam vendor.
 * Used by UI to enable/disable features.
 */
enum VendorFeature {
    case gpsData              // GPS data
    case accelerometer        // Accelerometer
    case gyroscope            // Gyroscope
    case speedometer          // Speedometer
    case parkingMode          // Parking mode
    case voiceRecording       // Voice recording
    case adas                 // ADAS (lane departure warning, etc.)
    case cloudSync            // Cloud synchronization
}

// ============================================================================
// MARK: - VendorParserError
// ============================================================================

/**
 * @enum VendorParserError
 * @brief Parser errors
 */
enum VendorParserError: Error {
    case unsupportedFormat(String)
    case metadataExtractionFailed(String)
    case invalidTimestamp(String)
}

extension VendorParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "Unsupported file format: \(format)"
        case .metadataExtractionFailed(let reason):
            return "Metadata extraction failed: \(reason)"
        case .invalidTimestamp(let timestamp):
            return "Invalid timestamp: \(timestamp)"
        }
    }
}
