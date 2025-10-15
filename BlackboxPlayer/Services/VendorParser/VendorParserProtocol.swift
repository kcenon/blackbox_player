/**
 * @file VendorParserProtocol.swift
 * @brief 제조사별 파일 파싱 인터페이스
 * @author BlackboxPlayer Development Team
 *
 * @details
 * 다양한 블랙박스 제조사의 파일 형식을 지원하기 위한 프로토콜입니다.
 * 각 제조사는 이 프로토콜을 구현하여 자체 파일명 형식과 메타데이터를 처리합니다.
 */

import Foundation

// ============================================================================
// MARK: - VendorParserProtocol
// ============================================================================

/**
 * @protocol VendorParserProtocol
 * @brief 제조사별 파일 파싱 인터페이스
 *
 * @details
 * 각 블랙박스 제조사는 이 프로토콜을 구현하여:
 * - 파일명 패턴 매칭
 * - 메타데이터 추출
 * - GPS/가속도 데이터 파싱
 * - 제조사별 특수 기능 지원
 */
protocol VendorParserProtocol {
    /// 제조사 식별자 (예: "blackvue", "cr2000omega")
    var vendorId: String { get }

    /// 제조사 표시 이름 (예: "BlackVue", "CR-2000 OMEGA")
    var vendorName: String { get }

    /**
     * @brief 파일명이 이 제조사 형식과 일치하는지 검사
     * @param filename 검사할 파일명
     * @return 일치 여부
     */
    func matches(_ filename: String) -> Bool

    /**
     * @brief 파일명에서 메타데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return VideoFileInfo 또는 nil (파싱 실패 시)
     */
    func parseVideoFile(_ fileURL: URL) -> VideoFileInfo?

    /**
     * @brief 비디오에서 GPS 데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return GPSPoint 배열
     */
    func extractGPSData(from fileURL: URL) -> [GPSPoint]

    /**
     * @brief 비디오에서 가속도 데이터 추출
     * @param fileURL 비디오 파일 URL
     * @return AccelerationData 배열
     */
    func extractAccelerationData(from fileURL: URL) -> [AccelerationData]

    /**
     * @brief 제조사별 지원 기능 목록
     * @return VendorFeature 배열
     */
    func supportedFeatures() -> [VendorFeature]
}

// ============================================================================
// MARK: - VendorFeature
// ============================================================================

/**
 * @enum VendorFeature
 * @brief 제조사별 지원 기능
 *
 * @details
 * 각 블랙박스 제조사가 제공하는 기능을 열거합니다.
 * UI에서 기능 활성화/비활성화 판단에 사용됩니다.
 */
enum VendorFeature {
    case gpsData              // GPS 데이터
    case accelerometer        // 가속도계
    case gyroscope            // 자이로스코프
    case speedometer          // 속도계
    case parkingMode          // 주차 모드
    case voiceRecording       // 음성 녹음
    case adas                 // ADAS (차선 이탈 경고 등)
    case cloudSync            // 클라우드 동기화
}

// ============================================================================
// MARK: - VendorParserError
// ============================================================================

/**
 * @enum VendorParserError
 * @brief 파서 오류
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
            return "지원하지 않는 파일 형식: \(format)"
        case .metadataExtractionFailed(let reason):
            return "메타데이터 추출 실패: \(reason)"
        case .invalidTimestamp(let timestamp):
            return "잘못된 타임스탬프: \(timestamp)"
        }
    }
}
