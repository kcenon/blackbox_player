/**
 * @file CR2000OmegaParser.swift
 * @brief CR-2000 OMEGA 블랙박스 파일 파서
 * @author BlackboxPlayer Development Team
 *
 * @details
 * CR-2000 OMEGA 블랙박스의 파일명 형식과 메타데이터를 파싱합니다.
 *
 * 파일명 형식: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
 * - 예: 2025-10-07-09h-11m-09s_F_normal.mp4
 *
 * 메타데이터: Stream #2 (mp4s)
 * - GPS: X,Y,Z,gJ$GPRMC (NMEA 0183)
 * - 가속도: X,Y,Z (앞부분)
 */

import Foundation

// ============================================================================
// MARK: - CR2000OmegaParser
// ============================================================================

/**
 * @class CR2000OmegaParser
 * @brief CR-2000 OMEGA 블랙박스 파일 파서
 */
class CR2000OmegaParser: VendorParserProtocol {

    // MARK: - VendorParserProtocol Properties

    let vendorId = "cr2000omega"
    let vendorName = "CR-2000 OMEGA"

    // MARK: - Private Properties

    /**
     * 파일명 정규식 패턴: YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4
     *
     * 캡처 그룹:
     * - 1: 년 (YYYY) - 4자리 숫자
     * - 2: 월 (MM) - 2자리 숫자
     * - 3: 일 (DD) - 2자리 숫자
     * - 4: 시 (HH) - 2자리 숫자
     * - 5: 분 (MM) - 2자리 숫자
     * - 6: 초 (SS) - 2자리 숫자
     * - 7: 카메라 위치 (F/R/L/I)
     * - 8: 녹화 타입 (normal/event/parking/motion)
     * - 9: 확장자 (mp4/avi 등)
     */
    private let filenamePattern = #"^(\d{4})-(\d{2})-(\d{2})-(\d{2})h-(\d{2})m-(\d{2})s_([FRLIi])_(normal|event|parking|motion)\.(\w+)$"#

    /// 컴파일된 정규식
    private let filenameRegex: NSRegularExpression?

    // MARK: - Initialization

    init() {
        self.filenameRegex = try? NSRegularExpression(
            pattern: filenamePattern,
            options: []
        )
    }

    // MARK: - VendorParserProtocol Methods

    /**
     * @brief 파일명이 CR-2000 OMEGA 형식과 일치하는지 검사
     * @param filename 검사할 파일명
     * @return 일치 여부
     */
    func matches(_ filename: String) -> Bool {
        guard let regex = filenameRegex else { return false }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    }

    /**
     * @brief 파일명에서 메타데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return VideoFileInfo 또는 nil
     *
     * @details
     * 파일명 파싱 과정:
     * 1. 정규식으로 날짜, 시간, 카메라 위치, 타입 추출
     * 2. 날짜/시간 문자열 → Date 변환
     * 3. 카메라 위치 코드 → CameraPosition enum
     * 4. 파일명에서 이벤트 타입 직접 추출 (normal/event/parking)
     * 5. 파일 크기 조회
     * 6. VideoFileInfo 생성
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent

        // 정규식 매칭
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            return nil
        }

        // 캡처 그룹 개수 확인: [전체, 년, 월, 일, 시, 분, 초, 위치, 타입, 확장자]
        guard match.numberOfRanges == 10 else { return nil }

        // 캡처 그룹 추출
        let year = (filename as NSString).substring(with: match.range(at: 1))
        let month = (filename as NSString).substring(with: match.range(at: 2))
        let day = (filename as NSString).substring(with: match.range(at: 3))
        let hour = (filename as NSString).substring(with: match.range(at: 4))
        let minute = (filename as NSString).substring(with: match.range(at: 5))
        let second = (filename as NSString).substring(with: match.range(at: 6))
        let positionCode = (filename as NSString).substring(with: match.range(at: 7))
        let eventTypeString = (filename as NSString).substring(with: match.range(at: 8))

        // 타임스탬프 파싱: "20251007091109" → Date
        let timestampString = "\(year)\(month)\(day)\(hour)\(minute)\(second)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            return nil
        }

        // 카메라 위치 감지
        let position = CameraPosition.detect(from: positionCode)

        // 파일명에서 이벤트 타입 직접 추출
        let eventType: EventType
        switch eventTypeString.lowercased() {
        case "normal":
            eventType = .normal
        case "event":
            eventType = .impact  // event를 impact로 매핑
        case "parking":
            eventType = .parking
        case "motion":
            eventType = .impact  // motion을 impact로 매핑
        default:
            eventType = .unknown
        }

        // 파일 크기 조회
        let fileSize = UInt64(
            (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
        )

        // 기본 파일명 생성 (카메라 위치와 타입 제외)
        // "2025-10-07-09h-11m-09s_F_normal.mp4" → "2025-10-07-09h-11m-09s"
        let baseFilename = "\(year)-\(month)-\(day)-\(hour)h-\(minute)m-\(second)s"

        return VideoFileInfo(
            url: fileURL,
            timestamp: timestamp,
            position: position,
            eventType: eventType,
            fileSize: fileSize,
            baseFilename: baseFilename
        )
    }

    /**
     * @brief 비디오에서 GPS 데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return GPSPoint 배열
     *
     * @details
     * CR-2000 OMEGA는 Stream #2에 "X,Y,Z,gJ$GPRMC,..." 형식으로 저장
     * gJ 이후의 NMEA 0183 부분만 추출하여 GPSParser로 파싱합니다.
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // MetadataStreamParser로 메타데이터 라인 추출
        let parser = MetadataStreamParser()
        let lines = parser.extractMetadataLines(from: fileURL, streamIndex: 2)

        guard !lines.isEmpty else {
            return []
        }

        // 파일명에서 baseDate 추출 (NMEA 시간과 결합용)
        let baseDate = extractBaseDate(from: fileURL)

        // GPSParser로 파싱
        let gpsParser = GPSParser()
        var gpsPoints: [GPSPoint] = []

        for line in lines {
            // "$GPRMC" NMEA 부분 추출 (바이너리 헤더 이미 제거됨)
            if let nmeaStart = line.range(of: "$GPRMC") {
                let nmea = String(line[nmeaStart.lowerBound...])

                // NMEA 문자열을 Data로 변환
                if let nmeaData = nmea.data(using: .ascii) {
                    let points = gpsParser.parseNMEA(data: nmeaData, baseDate: baseDate)
                    gpsPoints.append(contentsOf: points)
                }
            }
        }

        return gpsPoints
    }

    /**
     * @brief 비디오에서 가속도 데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return AccelerationData 배열
     *
     * @details
     * CR-2000 OMEGA는 Stream #2에 "X,Y,Z,gJ$GPRMC,..." 형식으로 저장
     * 앞부분의 X,Y,Z 값을 추출합니다.
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData] {
        // MetadataStreamParser로 메타데이터 라인 추출
        let parser = MetadataStreamParser()
        let lines = parser.extractMetadataLines(from: fileURL, streamIndex: 2)

        guard !lines.isEmpty else {
            return []
        }

        // 파일명에서 baseDate 추출
        let baseDate = extractBaseDate(from: fileURL)

        var accelerationData: [AccelerationData] = []
        var timestamp: TimeInterval = 0.0

        for line in lines {
            // 라인 형식: "X,Y,Z,gJ$GPRMC,..."
            // 앞 3개 값 (X, Y, Z) 추출
            let components = line.split(separator: ",", maxSplits: 3)

            guard components.count >= 3,
                  let x = Double(components[0]),
                  let y = Double(components[1]),
                  let z = Double(components[2]) else {
                continue
            }

            // AccelerationData 생성 (1초 간격)
            let data = AccelerationData(
                timestamp: baseDate.addingTimeInterval(timestamp),
                x: x,
                y: y,
                z: z
            )

            accelerationData.append(data)
            timestamp += 1.0  // 1초씩 증가
        }

        return accelerationData
    }

    /**
     * @brief CR-2000 OMEGA 지원 기능
     * @return VendorFeature 배열
     */
    func supportedFeatures() -> [VendorFeature] {
        return [
            .gpsData,
            .accelerometer,
            .parkingMode,
            .voiceRecording
        ]
    }

    // MARK: - Private Methods

    /**
     * @brief 파일 URL에서 녹화 시작 시각 추출
     * @param fileURL 비디오 파일 URL
     * @return 녹화 시작 Date
     *
     * @details
     * 파일명 형식: "YYYY-MM-DD-HHh-MMm-SSs_X_type.mp4"
     * 예: "2025-10-07-09h-11m-09s_F_normal.mp4"
     * → Date(2025-10-07 09:11:09 +0900)
     */
    private func extractBaseDate(from fileURL: URL) -> Date {
        let filename = fileURL.lastPathComponent

        // 정규식 매칭
        guard let regex = filenameRegex else {
            return Date()
        }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range),
              match.numberOfRanges == 10 else {
            return Date()
        }

        // 캡처 그룹 추출
        let year = (filename as NSString).substring(with: match.range(at: 1))
        let month = (filename as NSString).substring(with: match.range(at: 2))
        let day = (filename as NSString).substring(with: match.range(at: 3))
        let hour = (filename as NSString).substring(with: match.range(at: 4))
        let minute = (filename as NSString).substring(with: match.range(at: 5))
        let second = (filename as NSString).substring(with: match.range(at: 6))

        // 타임스탬프 파싱
        let timestampString = "\(year)\(month)\(day)\(hour)\(minute)\(second)"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        return dateFormatter.date(from: timestampString) ?? Date()
    }
}
