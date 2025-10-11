//
//  LogManager.swift
//  BlackboxPlayer
//
//  Centralized logging manager for debugging
//

import Foundation
import Combine

/// Log entry with timestamp and message
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let level: LogLevel

    var formattedMessage: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeString = formatter.string(from: timestamp)
        return "[\(timeString)] [\(level.displayName)] \(message)"
    }
}

/// Log level
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var displayName: String {
        return self.rawValue
    }
}

/// Centralized log manager
class LogManager: ObservableObject {
    /// Shared instance
    static let shared = LogManager()

    /// Published log entries
    @Published private(set) var logs: [LogEntry] = []

    /// Maximum number of logs to keep
    private let maxLogs = 500

    /// Lock for thread-safe access
    private let lock = NSLock()

    private init() {}

    /// Log a message
    /// - Parameters:
    ///   - message: Log message
    ///   - level: Log level
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)

        lock.lock()
        logs.append(entry)

        // Keep only recent logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        lock.unlock()

        // Also print to console
        print("[\(level.displayName)] \(message)")
    }

    /// Clear all logs
    func clear() {
        lock.lock()
        logs.removeAll()
        lock.unlock()
    }
}

/// Convenience logging functions
func debugLog(_ message: String) {
    LogManager.shared.log(message, level: .debug)
}

func infoLog(_ message: String) {
    LogManager.shared.log(message, level: .info)
}

func warningLog(_ message: String) {
    LogManager.shared.log(message, level: .warning)
}

func errorLog(_ message: String) {
    LogManager.shared.log(message, level: .error)
}
