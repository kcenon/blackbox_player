/**
 * @file BlackVueParser.swift
 * @brief BlackVue 블랙박스 파일 파서
 * @author BlackboxPlayer Development Team
 *
 * @details
 * BlackVue 블랙박스의 파일명 형식과 메타데이터를 파싱합니다.
 *
 * 파일명 형식: YYYYMMDD_HHMMSS_X.mp4
 * - 예: 20240115_143025_F.mp4
 *
 * 메타데이터: Stream #2 (mp4s)
 * - GPS: NMEA 0183 형식
 * - 가속도: 3축 데이터
 */

import Foundation

// ============================================================================
// MARK: - BlackVueParser
// ============================================================================

/**
 * @class BlackVueParser
 * @brief BlackVue 블랙박스 파일 파서
 */
class BlackVueParser: VendorParserProtocol {

    // MARK: - VendorParserProtocol Properties

    let vendorId = "blackvue"
    let vendorName = "BlackVue"

    // MARK: - Private Properties

    /**
     * 파일명 정규식 패턴: YYYYMMDD_HHMMSS_X.mp4
     *
     * 캡처 그룹:
     * - 1: 날짜 (YYYYMMDD) - 8자리 숫자
     * - 2: 시간 (HHMMSS) - 6자리 숫자
     * - 3: 카메라 위치 (F/R/L/I) - 1글자 이상
     * - 4: 확장자 (mp4/avi 등)
     */
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

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
     * @brief 파일명이 BlackVue 형식과 일치하는지 검사
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
     * 1. 정규식으로 날짜, 시간, 카메라 위치 추출
     * 2. 날짜/시간 문자열 → Date 변환
     * 3. 카메라 위치 코드 → CameraPosition enum
     * 4. 경로에서 이벤트 타입 감지
     * 5. 파일 크기 조회
     * 6. VideoFileInfo 생성
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo? {
        let filename = fileURL.lastPathComponent
        let pathString = fileURL.path

        // 정규식 매칭
        guard let regex = filenameRegex else { return nil }

        let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
        guard let match = regex.firstMatch(in: filename, options: [], range: range) else {
            return nil
        }

        // 캡처 그룹 개수 확인: [전체, 날짜, 시간, 위치, 확장자]
        guard match.numberOfRanges == 5 else { return nil }

        // 캡처 그룹 추출
        let dateString = (filename as NSString).substring(with: match.range(at: 1))
        let timeString = (filename as NSString).substring(with: match.range(at: 2))
        let positionCode = (filename as NSString).substring(with: match.range(at: 3))

        // 타임스탬프 파싱: "20240115143025" → Date
        let timestampString = dateString + timeString
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

        guard let timestamp = dateFormatter.date(from: timestampString) else {
            return nil
        }

        // 카메라 위치 감지
        let position = CameraPosition.detect(from: positionCode)

        // 이벤트 타입 감지 (경로 기반)
        let eventType = EventType.detect(from: pathString)

        // 파일 크기 조회
        let fileSize = UInt64(
            (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? UInt64) ?? 0
        )

        // 기본 파일명 생성 (카메라 위치 제외)
        // "20240115_143025_F.mp4" → "20240115_143025"
        let baseFilename = "\(dateString)_\(timeString)"

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
     * BlackVue는 Stream #2에 NMEA 0183 형식으로 GPS 데이터 저장
     * GPSParser를 사용하여 추출합니다.
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint] {
        // TODO: GPSParser 통합
        // 현재는 빈 배열 반환
        return []
    }

    /**
     * @brief 비디오에서 가속도 데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return AccelerationData 배열
     *
     * @details
     * BlackVue는 Stream #2에 가속도 데이터 포함
     * GSensorParser를 사용하여 추출합니다.
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData] {
        // TODO: GSensorParser 통합
        // 현재는 빈 배열 반환
        return []
    }

    /**
     * @brief BlackVue 지원 기능
     * @return VendorFeature 배열
     */
    func supportedFeatures() -> [VendorFeature] {
        return [
            .gpsData,
            .accelerometer,
            .parkingMode,
            .cloudSync,
            .voiceRecording
        ]
    }
}
