/**
 * @file MetadataStreamParser.swift
 * @brief MP4 metadata stream parser
 * @author BlackboxPlayer Development Team
 *
 * @details
 * Extracts and parses text lines from MP4 file metadata streams
 * using FFmpeg.
 */

import Foundation

// ============================================================================
// MARK: - MetadataStreamParser
// ============================================================================

/**
 * @class MetadataStreamParser
 * @brief MP4 metadata stream extraction and parsing
 */
class MetadataStreamParser {

    // MARK: - Properties

    /// FFmpeg executable path
    private let ffmpegPath: String

    // MARK: - Initialization

    init(ffmpegPath: String = "/opt/homebrew/bin/ffmpeg") {
        self.ffmpegPath = ffmpegPath
    }

    // MARK: - Public Methods

    /**
     * @brief Extract text lines from metadata stream in MP4 file
     * @param fileURL Video file URL
     * @param streamIndex Stream index (default: 2)
     * @return Array of text lines
     *
     * @details
     * Extracts raw data from Stream #2 using FFmpeg,
     * splits by newline characters, and returns as text line array.
     *
     * CR-2000 OMEGA format:
     * ```
     * 0.00,-0.01,0.00,gJ$GPRMC,001107.00,A,3725.31464,N,12707.10447,E,...
     * 0.00,0.00,-0.03,gJ$GPRMC,001108.00,A,3725.31368,N,12707.12163,E,...
     * ```
     */
    func extractMetadataLines(from fileURL: URL, streamIndex: Int = 2) -> [String] {
        // Configure FFmpeg process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", fileURL.path,
            "-map", "0:\(streamIndex)",
            "-c", "copy",
            "-f", "data",
            "-"
        ]

        // stdout pipe
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        // Ignore stderr (FFmpeg logs)
        let errorPipe = Pipe()
        process.standardError = errorPipe

        // Run process
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        // Check exit code
        guard process.terminationStatus == 0 else {
            return []
        }

        // Read metadata
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard !data.isEmpty else {
            return []
        }

        // Convert to text and split into lines
        return parseLines(from: data)
    }

    // MARK: - Private Methods

    /**
     * @brief Extract text lines from binary data
     * @param data raw metadata
     * @return Array of text lines
     *
     * @details
     * Metadata lines are separated by newline characters (\r or \n).
     * Removes binary headers and extracts only the text portion.
     */
    private func parseLines(from data: Data) -> [String] {
        // Decode to UTF-8 (lossy - ignore binary characters)
        let text = String(decoding: data, as: UTF8.self)

        // Split by newline characters (try multiple newline types)
        var lines: [String] = []

        // Try splitting by \r
        let rLines = text.components(separatedBy: "\r")
        if rLines.count > 1 {
            lines = rLines
        } else {
            // Try splitting by \n
            lines = text.components(separatedBy: "\n")
        }

        // Cleanup and filtering
        return lines
            .map { line -> String in
                // Remove binary headers (keep only printable ASCII characters)
                let cleaned = line.filter { char in
                    let ascii = char.asciiValue ?? 0
                    return (ascii >= 32 && ascii <= 126) || char == ","
                }
                return cleaned
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                // Filter only GPS data or acceleration data
                line.contains("$GPRMC") || line.split(separator: ",").count >= 3
            }
    }
}
