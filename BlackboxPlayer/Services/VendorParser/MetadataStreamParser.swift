/**
 * @file MetadataStreamParser.swift
 * @brief MP4 메타데이터 스트림 파서
 * @author BlackboxPlayer Development Team
 *
 * @details
 * FFmpeg를 사용하여 MP4 파일의 메타데이터 스트림에서
 * 텍스트 라인을 추출하고 파싱합니다.
 */

import Foundation

// ============================================================================
// MARK: - MetadataStreamParser
// ============================================================================

/**
 * @class MetadataStreamParser
 * @brief MP4 메타데이터 스트림 추출 및 파싱
 */
class MetadataStreamParser {

    // MARK: - Properties

    /// FFmpeg 실행 파일 경로
    private let ffmpegPath: String

    // MARK: - Initialization

    init(ffmpegPath: String = "/opt/homebrew/bin/ffmpeg") {
        self.ffmpegPath = ffmpegPath
    }

    // MARK: - Public Methods

    /**
     * @brief MP4 파일에서 메타데이터 스트림의 텍스트 라인 추출
     * @param fileURL 비디오 파일 URL
     * @param streamIndex 스트림 인덱스 (기본값: 2)
     * @return 텍스트 라인 배열
     *
     * @details
     * FFmpeg로 Stream #2의 raw 데이터를 추출하고,
     * 개행 문자로 분리하여 텍스트 라인 배열로 반환합니다.
     *
     * CR-2000 OMEGA 형식:
     * ```
     * 0.00,-0.01,0.00,gJ$GPRMC,001107.00,A,3725.31464,N,12707.10447,E,...
     * 0.00,0.00,-0.03,gJ$GPRMC,001108.00,A,3725.31368,N,12707.12163,E,...
     * ```
     */
    func extractMetadataLines(from fileURL: URL, streamIndex: Int = 2) -> [String] {
        // FFmpeg 프로세스 설정
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-i", fileURL.path,
            "-map", "0:\(streamIndex)",
            "-c", "copy",
            "-f", "data",
            "-"
        ]

        // stdout 파이프
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        // stderr 무시 (FFmpeg 로그)
        let errorPipe = Pipe()
        process.standardError = errorPipe

        // 프로세스 실행
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        // 종료 코드 확인
        guard process.terminationStatus == 0 else {
            return []
        }

        // 메타데이터 읽기
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()

        guard !data.isEmpty else {
            return []
        }

        // 텍스트로 변환 및 라인 분리
        return parseLines(from: data)
    }

    // MARK: - Private Methods

    /**
     * @brief 바이너리 데이터에서 텍스트 라인 추출
     * @param data raw metadata
     * @return 텍스트 라인 배열
     *
     * @details
     * 메타데이터는 각 라인이 개행 문자(\r 또는 \n)로 구분됩니다.
     * 바이너리 헤더를 제거하고 텍스트 부분만 추출합니다.
     */
    private func parseLines(from data: Data) -> [String] {
        // UTF-8로 디코드 (lossy - 바이너리 문자 무시)
        let text = String(decoding: data, as: UTF8.self)

        // 개행 문자로 분리 (개행 문자 여러 종류 시도)
        var lines: [String] = []

        // \r로 분리 시도
        let rLines = text.components(separatedBy: "\r")
        if rLines.count > 1 {
            lines = rLines
        } else {
            // \n으로 분리 시도
            lines = text.components(separatedBy: "\n")
        }

        // 클린업 및 필터링
        return lines
            .map { line -> String in
                // 바이너리 헤더 제거 (printable ASCII 문자만 유지)
                let cleaned = line.filter { char in
                    let ascii = char.asciiValue ?? 0
                    return (ascii >= 32 && ascii <= 126) || char == ","
                }
                return cleaned
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                // GPS 데이터 또는 가속도 데이터만 필터링
                line.contains("$GPRMC") || line.split(separator: ",").count >= 3
            }
    }
}
