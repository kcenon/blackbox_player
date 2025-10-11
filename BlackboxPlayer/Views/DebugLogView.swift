//
//  DebugLogView.swift
//  BlackboxPlayer
//
//  Debug log viewer overlay
//

import SwiftUI

/// Debug log viewer overlay
struct DebugLogView: View {
    @ObservedObject var logManager = LogManager.shared
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Log")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                // Auto-scroll toggle
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundColor(.white)

                // Clear button
                Button(action: { logManager.clear() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Clear logs")
            }
            .padding()
            .background(Color.black.opacity(0.9))

            Divider()

            // Log list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logManager.logs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.8))
                .onChange(of: logManager.logs.count) { _ in
                    if autoScroll, let lastLog = logManager.logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .cornerRadius(8)
        .shadow(radius: 10)
    }
}

/// Single log entry row
private struct LogEntryRow: View {
    let entry: LogEntry

    var body: some View {
        Text(entry.formattedMessage)
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(textColor)
            .textSelection(.enabled)
    }

    private var textColor: Color {
        switch entry.level {
        case .debug:
            return .gray
        case .info:
            return .white
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

struct DebugLogView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue
            VStack {
                Spacer()
                DebugLogView()
                    .padding()
            }
        }
        .onAppear {
            LogManager.shared.log("Application started", level: .info)
            LogManager.shared.log("Loading video file: test.mp4", level: .debug)
            LogManager.shared.log("Warning: Low buffer detected", level: .warning)
            LogManager.shared.log("Error: Failed to decode frame", level: .error)
        }
    }
}
