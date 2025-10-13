/// @file SegmentExporter.swift
/// @brief 비디오 구간 추출 서비스
/// @author BlackboxPlayer Development Team
/// @details
/// 선택된 구간을 별도의 비디오 파일로 추출하는 서비스입니다.
/// FFmpeg을 사용하여 효율적으로 구간을 추출하고 진행률을 추적합니다.

import Foundation

/// @class SegmentExporter
/// @brief 비디오 구간 추출 서비스
///
/// @details
/// ## 기능
/// - In Point ~ Out Point 구간을 새 파일로 추출
/// - 진행률 추적 및 콜백
/// - 다중 채널 동시 추출
/// - GPS 메타데이터 보존
///
/// ## 추출 방식
/// ```
/// FFmpeg 명령:
/// ffmpeg -ss <start_time> -i <input> -t <duration> -c copy <output>
///
/// 옵션:
/// - -ss: 시작 시간 (In Point)
/// - -t: 지속 시간 (duration = Out Point - In Point)
/// - -c copy: 코덱 복사 (빠른 처리, 재인코딩 없음)
/// ```
///
/// ## 사용 예제
/// ```swift
/// let exporter = SegmentExporter()
///
/// exporter.exportSegment(
///     inputPath: "/path/to/input.mp4",
///     outputPath: "/path/to/output.mp4",
///     startTime: 5.0,
///     duration: 10.0
/// ) { progress in
///     print("Progress: \(progress * 100)%")
/// } completion: { result in
///     switch result {
///     case .success(let url):
///         print("Exported: \(url)")
///     case .failure(let error):
///         print("Error: \(error)")
///     }
/// }
/// ```
class SegmentExporter {
    // MARK: - Types

    /// @enum ExportError
    /// @brief 추출 에러 유형
    enum ExportError: LocalizedError {
        /// 입력 파일 없음
        case inputFileNotFound

        /// 출력 경로 무효
        case invalidOutputPath

        /// 시간 범위 무효
        case invalidTimeRange

        /// FFmpeg 실행 실패
        case ffmpegExecutionFailed(String)

        /// 사용자 취소
        case cancelled

        /// 에러 설명
        var errorDescription: String? {
            switch self {
            case .inputFileNotFound:
                return "Input file not found"
            case .invalidOutputPath:
                return "Invalid output path"
            case .invalidTimeRange:
                return "Invalid time range"
            case .ffmpegExecutionFailed(let message):
                return "FFmpeg execution failed: \(message)"
            case .cancelled:
                return "Export cancelled by user"
            }
        }
    }

    /// @struct ExportOptions
    /// @brief 추출 옵션
    struct ExportOptions {
        /// 비디오 코덱 (nil = 복사)
        var videoCodec: String?

        /// 오디오 코덱 (nil = 복사)
        var audioCodec: String?

        /// 비트레이트 (nil = 원본 유지)
        var videoBitrate: Int?

        /// 오디오 비트레이트 (nil = 원본 유지)
        var audioBitrate: Int?

        /// 품질 프리셋 (ultrafast, fast, medium, slow 등)
        var preset: String?

        /// 기본 옵션 (코덱 복사)
        static var `default`: ExportOptions {
            return ExportOptions(
                videoCodec: "copy",
                audioCodec: "copy",
                videoBitrate: nil,
                audioBitrate: nil,
                preset: nil
            )
        }
    }

    // MARK: - Properties

    /// 취소 플래그
    private var isCancelled: Bool = false

    /// 현재 실행 중인 프로세스
    private var currentProcess: Process?

    // MARK: - Public Methods

    /// 비디오 구간 추출
    ///
    /// ## 추출 프로세스
    /// ```
    /// 1. 입력 파일 존재 확인
    /// 2. 출력 경로 유효성 확인
    /// 3. FFmpeg 명령 생성
    /// 4. 프로세스 실행 (백그라운드)
    /// 5. 진행률 추적
    /// 6. 완료 콜백 호출
    /// ```
    ///
    /// - Parameters:
    ///   - inputPath: 입력 비디오 파일 경로
    ///   - outputPath: 출력 비디오 파일 경로
    ///   - startTime: 시작 시간 (초)
    ///   - duration: 지속 시간 (초)
    ///   - options: 추출 옵션 (기본값: .default)
    ///   - progressHandler: 진행률 콜백 (0.0 ~ 1.0)
    ///   - completion: 완료 콜백
    func exportSegment(
        inputPath: String,
        outputPath: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        options: ExportOptions = .default,
        progressHandler: @escaping (Double) -> Void = { _ in },
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 백그라운드 큐에서 실행
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 취소 플래그 초기화
            self.isCancelled = false

            // 1. 입력 파일 확인
            guard FileManager.default.fileExists(atPath: inputPath) else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.inputFileNotFound))
                }
                return
            }

            // 2. 시간 범위 확인
            guard startTime >= 0 && duration > 0 else {
                DispatchQueue.main.async {
                    completion(.failure(ExportError.invalidTimeRange))
                }
                return
            }

            // 3. 출력 디렉토리 생성
            let outputURL = URL(fileURLWithPath: outputPath)
            let outputDirectory = outputURL.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(
                    at: outputDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            // 4. FFmpeg 명령 실행
            do {
                try self.runFFmpegExport(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    startTime: startTime,
                    duration: duration,
                    options: options,
                    progressHandler: progressHandler
                )

                // 성공
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }

            } catch {
                // 실패
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// 다중 채널 동시 추출
    ///
    /// ## 다중 채널 처리
    /// - 모든 채널을 동시에 추출
    /// - 각 채널별 진행률 추적
    /// - 모든 채널 완료 후 콜백
    ///
    /// - Parameters:
    ///   - channels: 채널 정보 배열 (inputPath 포함)
    ///   - outputDirectory: 출력 디렉토리
    ///   - startTime: 시작 시간 (초)
    ///   - duration: 지속 시간 (초)
    ///   - progressHandler: 전체 진행률 콜백 (0.0 ~ 1.0)
    ///   - completion: 완료 콜백 (성공: 출력 파일 URL 배열)
    func exportMultipleChannels(
        channels: [(position: ChannelPosition, inputPath: String)],
        outputDirectory: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        progressHandler: @escaping (Double) -> Void = { _ in },
        completion: @escaping (Result<[URL], Error>) -> Void
    ) {
        let group = DispatchGroup()
        var results: [Result<URL, Error>] = Array(repeating: .failure(ExportError.cancelled), count: channels.count)
        var channelProgress: [Double] = Array(repeating: 0.0, count: channels.count)

        for (index, channel) in channels.enumerated() {
            group.enter()

            // 출력 파일 이름 생성
            let outputFileName = "segment_\(channel.position.rawValue).mp4"
            let outputPath = (outputDirectory as NSString).appendingPathComponent(outputFileName)

            // 각 채널 추출
            exportSegment(
                inputPath: channel.inputPath,
                outputPath: outputPath,
                startTime: startTime,
                duration: duration
            ) { progress in
                // 개별 채널 진행률 업데이트
                channelProgress[index] = progress

                // 전체 진행률 계산 (평균)
                let totalProgress = channelProgress.reduce(0, +) / Double(channels.count)
                progressHandler(totalProgress)

            } completion: { result in
                results[index] = result
                group.leave()
            }
        }

        // 모든 채널 완료 대기
        group.notify(queue: .main) {
            // 모든 결과 확인
            var successURLs: [URL] = []
            for result in results {
                switch result {
                case .success(let url):
                    successURLs.append(url)
                case .failure(let error):
                    // 하나라도 실패하면 전체 실패
                    completion(.failure(error))
                    return
                }
            }

            // 모두 성공
            completion(.success(successURLs))
        }
    }

    /// 추출 취소
    ///
    /// ## 취소 처리
    /// - 현재 실행 중인 프로세스 종료
    /// - isCancelled 플래그 설정
    /// - 진행 중인 모든 추출 작업 중단
    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    // MARK: - Private Methods

    /// FFmpeg 명령 실행
    ///
    /// ## 명령 형식
    /// ```bash
    /// ffmpeg -ss <start> -i <input> -t <duration> -c copy <output>
    /// ```
    ///
    /// - Parameters:
    ///   - inputPath: 입력 파일 경로
    ///   - outputPath: 출력 파일 경로
    ///   - startTime: 시작 시간 (초)
    ///   - duration: 지속 시간 (초)
    ///   - options: 추출 옵션
    ///   - progressHandler: 진행률 콜백
    private func runFFmpegExport(
        inputPath: String,
        outputPath: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        options: ExportOptions,
        progressHandler: @escaping (Double) -> Void
    ) throws {
        // FFmpeg 실행 파일 경로 찾기
        guard let ffmpegPath = findFFmpegPath() else {
            throw ExportError.ffmpegExecutionFailed("FFmpeg not found")
        }

        // 프로세스 생성
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        // 명령 인자 구성
        var arguments: [String] = [
            "-y",  // 덮어쓰기 확인 없이
            "-ss", String(format: "%.3f", startTime),  // 시작 시간
            "-i", inputPath,  // 입력 파일
            "-t", String(format: "%.3f", duration)  // 지속 시간
        ]

        // 코덱 옵션
        if let videoCodec = options.videoCodec {
            arguments.append(contentsOf: ["-c:v", videoCodec])
        }
        if let audioCodec = options.audioCodec {
            arguments.append(contentsOf: ["-c:a", audioCodec])
        }

        // 비트레이트 옵션
        if let videoBitrate = options.videoBitrate {
            arguments.append(contentsOf: ["-b:v", "\(videoBitrate)k"])
        }
        if let audioBitrate = options.audioBitrate {
            arguments.append(contentsOf: ["-b:a", "\(audioBitrate)k"])
        }

        // 프리셋 옵션
        if let preset = options.preset {
            arguments.append(contentsOf: ["-preset", preset])
        }

        // 출력 파일
        arguments.append(outputPath)

        process.arguments = arguments

        // 표준 출력/에러 파이프 (진행률 추적용)
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 에러 출력 읽기 (FFmpeg는 진행률을 stderr로 출력)
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self = self, !self.isCancelled else { return }

            let data = handle.availableData
            if let output = String(data: data, encoding: .utf8) {
                // FFmpeg 진행률 파싱 (time=00:00:05.00)
                if let progress = self.parseFFmpegProgress(output: output, totalDuration: duration) {
                    DispatchQueue.main.async {
                        progressHandler(progress)
                    }
                }
            }
        }

        // 프로세스 실행
        currentProcess = process

        try process.run()
        process.waitUntilExit()

        // 취소 확인
        if isCancelled {
            throw ExportError.cancelled
        }

        // 종료 상태 확인
        if process.terminationStatus != 0 {
            throw ExportError.ffmpegExecutionFailed("Exit code: \(process.terminationStatus)")
        }
    }

    /// FFmpeg 실행 파일 경로 찾기
    ///
    /// ## 검색 우선순위
    /// 1. /usr/local/bin/ffmpeg (Homebrew 기본 경로)
    /// 2. /opt/homebrew/bin/ffmpeg (Apple Silicon Homebrew)
    /// 3. which ffmpeg (PATH 환경 변수)
    ///
    /// - Returns: FFmpeg 경로 또는 nil
    private func findFFmpegPath() -> String? {
        // 일반적인 경로 확인
        let commonPaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        // which 명령으로 찾기
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// FFmpeg 진행률 파싱
    ///
    /// ## FFmpeg 출력 형식
    /// ```
    /// frame=   75 fps= 25 q=-1.0 size=    1024kB time=00:00:03.00 bitrate=2793.5kbits/s speed=1.0x
    /// ```
    ///
    /// - Parameters:
    ///   - output: FFmpeg stderr 출력
    ///   - totalDuration: 전체 지속 시간 (초)
    /// - Returns: 진행률 (0.0 ~ 1.0) 또는 nil
    private func parseFFmpegProgress(output: String, totalDuration: TimeInterval) -> Double? {
        // "time=" 패턴 찾기
        guard let timeRange = output.range(of: "time=") else {
            return nil
        }

        // 시간 문자열 추출 (00:00:05.00 형식)
        let timeStart = output.index(timeRange.upperBound, offsetBy: 0)
        let timeEnd = output.index(timeStart, offsetBy: 11, limitedBy: output.endIndex) ?? output.endIndex
        let timeString = output[timeStart..<timeEnd]

        // 시간 파싱 (HH:MM:SS.MS)
        let components = timeString.split(separator: ":")
        guard components.count == 3 else { return nil }

        let hours = Double(components[0]) ?? 0
        let minutes = Double(components[1]) ?? 0
        let seconds = Double(components[2]) ?? 0

        let currentTime = hours * 3600 + minutes * 60 + seconds

        // 진행률 계산
        return min(1.0, currentTime / totalDuration)
    }
}

// MARK: - Supporting Types

/// @enum ChannelPosition
/// @brief 카메라 채널 위치
///
/// ## 채널 종류
/// - front: 전면 카메라
/// - rear: 후면 카메라
/// - left: 좌측 카메라
/// - right: 우측 카메라
enum ChannelPosition: String, Codable {
    case front = "front"
    case rear = "rear"
    case left = "left"
    case right = "right"

    var displayName: String {
        switch self {
        case .front:
            return "Front"
        case .rear:
            return "Rear"
        case .left:
            return "Left"
        case .right:
            return "Right"
        }
    }
}
