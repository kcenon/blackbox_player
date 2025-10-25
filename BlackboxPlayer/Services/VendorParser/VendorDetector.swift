/**
 * @file VendorDetector.swift
 * @brief Automatic dashcam vendor detection
 * @author BlackboxPlayer Development Team
 *
 * @details
 * Analyzes filename patterns and directory structure to automatically detect dashcam vendor.
 * Tries multiple parsers to select the most suitable one.
 */

import Foundation

// ============================================================================
// MARK: - VendorDetector
// ============================================================================

/**
 * @class VendorDetector
 * @brief Automatic vendor detection and parser management
 *
 * @details
 * 1. Collect sample files (max 10)
 * 2. Try matching with each parser
 * 3. Select parser with highest score
 * 4. Confidence check (50% or more matches)
 * 5. Performance optimization through caching
 */
class VendorDetector {

    // MARK: - Properties

    /// All registered parsers
    private var parsers: [VendorParserProtocol] = []

    /// Detected vendor cache (directory path → parser)
    private var detectedVendorCache: [String: VendorParserProtocol] = [:]

    /// Cache lock (thread-safe)
    private let cacheLock = NSLock()

    // MARK: - Initialization

    /**
     * @brief Initialize VendorDetector
     *
     * Registers default parsers.
     */
    init() {
        registerDefaultParsers()
    }

    // MARK: - Private Methods

    /**
     * @brief Register default parsers
     *
     * Registers parsers for all supported vendors.
     * To add new parsers in the future, only modify this method.
     */
    private func registerDefaultParsers() {
        // BlackVue parser
        parsers.append(BlackVueParser())

        // CR-2000 OMEGA parser
        parsers.append(CR2000OmegaParser())

        // Future additions:
        // parsers.append(ThinkwareParser())
        // parsers.append(ViofoParser())
        // parsers.append(NextbaseParser())
    }

    // MARK: - Public Methods

    /**
     * @brief Register new parser (plugin)
     * @param parser Parser to register
     *
     * Allows adding custom parsers from outside.
     */
    func registerParser(_ parser: VendorParserProtocol) {
        parsers.append(parser)

        // Invalidate cache (when adding new parser)
        cacheLock.lock()
        detectedVendorCache.removeAll()
        cacheLock.unlock()
    }

    /**
     * @brief Automatic vendor detection by scanning directory
     * @param directoryURL Directory to scan
     * @return Detected parser, nil if failed
     *
     * @details
     * 1. Check cache
     * 2. Collect sample files (max 10)
     * 3. Try matching with each parser
     * 4. Select parser with highest score
     * 5. Confidence check (50% or more)
     */
    func detectVendor(in directoryURL: URL) -> VendorParserProtocol? {
        // Check cache
        let cacheKey = directoryURL.path
        cacheLock.lock()
        if let cached = detectedVendorCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Collect sample files (first 10)
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var sampleFiles: [String] = []
        for case let fileURL as URL in enumerator {
            guard sampleFiles.count < 10 else { break }

            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()

            // Sample only video files
            if ["mp4", "mov", "avi", "mkv"].contains(ext) {
                sampleFiles.append(filename)
            }
        }

        guard !sampleFiles.isEmpty else { return nil }

        // Try matching with each parser
        var matchScores: [(parser: VendorParserProtocol, score: Int)] = []

        for parser in parsers {
            var score = 0
            for filename in sampleFiles {
                if parser.matches(filename) {
                    score += 1
                }
            }
            if score > 0 {
                matchScores.append((parser, score))
            }
        }

        // Select parser with highest score
        guard let best = matchScores.max(by: { $0.score < $1.score }) else {
            return nil
        }

        // Confidence check: must match at least 50%
        let confidence = Double(best.score) / Double(sampleFiles.count)
        guard confidence >= 0.5 else {
            print("⚠️ Low confidence (\(Int(confidence * 100))%): \(best.parser.vendorName)")
            return nil
        }

        print("✓ Detected vendor: \(best.parser.vendorName) (confidence: \(Int(confidence * 100))%)")

        // Save to cache
        cacheLock.lock()
        detectedVendorCache[cacheKey] = best.parser
        cacheLock.unlock()

        return best.parser
    }

    /**
     * @brief Detect vendor for specific filename
     * @param filename Filename
     * @return Detected parser, nil if failed
     *
     * Quickly detects vendor for a single file.
     */
    func detectVendor(for filename: String) -> VendorParserProtocol? {
        for parser in parsers {
            if parser.matches(filename) {
                return parser
            }
        }
        return nil
    }

    /**
     * @brief List of all registered parsers
     * @return Array of parsers
     */
    func allParsers() -> [VendorParserProtocol] {
        return parsers
    }

    /**
     * @brief Search parser by vendorId
     * @param vendorId Vendor identifier
     * @return Parser or nil
     */
    func parser(for vendorId: String) -> VendorParserProtocol? {
        return parsers.first { $0.vendorId == vendorId }
    }

    /**
     * @brief Clear cache
     *
     * Deletes cache for memory saving or re-detection.
     */
    func clearCache() {
        cacheLock.lock()
        detectedVendorCache.removeAll()
        cacheLock.unlock()
    }
}
