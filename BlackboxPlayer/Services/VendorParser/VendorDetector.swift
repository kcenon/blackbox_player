/**
 * @file VendorDetector.swift
 * @brief 블랙박스 제조사 자동 감지
 * @author BlackboxPlayer Development Team
 *
 * @details
 * 파일명 패턴과 디렉토리 구조를 분석하여 블랙박스 제조사를 자동으로 감지합니다.
 * 여러 파서를 시도하여 가장 적합한 파서를 선택합니다.
 */

import Foundation

// ============================================================================
// MARK: - VendorDetector
// ============================================================================

/**
 * @class VendorDetector
 * @brief 제조사 자동 감지 및 파서 관리
 *
 * @details
 * 1. 샘플 파일 수집 (최대 10개)
 * 2. 각 파서로 매칭 시도
 * 3. 가장 높은 점수의 파서 선택
 * 4. 신뢰도 검사 (50% 이상 매칭)
 * 5. 캐싱으로 성능 최적화
 */
class VendorDetector {

    // MARK: - Properties

    /// 등록된 모든 파서
    private var parsers: [VendorParserProtocol] = []

    /// 감지된 제조사 캐시 (디렉토리 경로 → 파서)
    private var detectedVendorCache: [String: VendorParserProtocol] = [:]

    /// 캐시 락 (thread-safe)
    private let cacheLock = NSLock()

    // MARK: - Initialization

    /**
     * @brief VendorDetector 초기화
     *
     * 기본 파서들을 등록합니다.
     */
    init() {
        registerDefaultParsers()
    }

    // MARK: - Private Methods

    /**
     * @brief 기본 파서 등록
     *
     * 지원하는 모든 제조사의 파서를 등록합니다.
     * 향후 새로운 파서 추가 시 이 메서드만 수정하면 됩니다.
     */
    private func registerDefaultParsers() {
        // BlackVue 파서
        parsers.append(BlackVueParser())

        // CR-2000 OMEGA 파서
        parsers.append(CR2000OmegaParser())

        // 향후 추가:
        // parsers.append(ThinkwareParser())
        // parsers.append(ViofoParser())
        // parsers.append(NextbaseParser())
    }

    // MARK: - Public Methods

    /**
     * @brief 새로운 파서 등록 (플러그인)
     * @param parser 등록할 파서
     *
     * 외부에서 커스텀 파서를 추가할 수 있습니다.
     */
    func registerParser(_ parser: VendorParserProtocol) {
        parsers.append(parser)

        // 캐시 무효화 (새 파서 추가 시)
        cacheLock.lock()
        detectedVendorCache.removeAll()
        cacheLock.unlock()
    }

    /**
     * @brief 디렉토리 스캔으로 제조사 자동 감지
     * @param directoryURL 스캔할 디렉토리
     * @return 감지된 파서, 실패 시 nil
     *
     * @details
     * 1. 캐시 확인
     * 2. 샘플 파일 수집 (최대 10개)
     * 3. 각 파서로 매칭 시도
     * 4. 최고 점수 파서 선택
     * 5. 신뢰도 검사 (50% 이상)
     */
    func detectVendor(in directoryURL: URL) -> VendorParserProtocol? {
        // 캐시 확인
        let cacheKey = directoryURL.path
        cacheLock.lock()
        if let cached = detectedVendorCache[cacheKey] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // 샘플 파일 수집 (처음 10개)
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

            // 비디오 파일만 샘플링
            if ["mp4", "mov", "avi", "mkv"].contains(ext) {
                sampleFiles.append(filename)
            }
        }

        guard !sampleFiles.isEmpty else { return nil }

        // 각 파서로 매칭 시도
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

        // 가장 높은 점수의 파서 선택
        guard let best = matchScores.max(by: { $0.score < $1.score }) else {
            return nil
        }

        // 신뢰도 검사: 최소 50% 이상 매칭해야 함
        let confidence = Double(best.score) / Double(sampleFiles.count)
        guard confidence >= 0.5 else {
            print("⚠️ 낮은 신뢰도 (\(Int(confidence * 100))%): \(best.parser.vendorName)")
            return nil
        }

        print("✓ 감지된 제조사: \(best.parser.vendorName) (신뢰도: \(Int(confidence * 100))%)")

        // 캐시 저장
        cacheLock.lock()
        detectedVendorCache[cacheKey] = best.parser
        cacheLock.unlock()

        return best.parser
    }

    /**
     * @brief 특정 파일명으로 제조사 감지
     * @param filename 파일명
     * @return 감지된 파서, 실패 시 nil
     *
     * 단일 파일의 제조사를 빠르게 감지합니다.
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
     * @brief 등록된 모든 파서 목록
     * @return 파서 배열
     */
    func allParsers() -> [VendorParserProtocol] {
        return parsers
    }

    /**
     * @brief 특정 vendorId로 파서 검색
     * @param vendorId 제조사 식별자
     * @return 파서 또는 nil
     */
    func parser(for vendorId: String) -> VendorParserProtocol? {
        return parsers.first { $0.vendorId == vendorId }
    }

    /**
     * @brief 캐시 초기화
     *
     * 메모리 절약 또는 재감지를 위해 캐시를 삭제합니다.
     */
    func clearCache() {
        cacheLock.lock()
        detectedVendorCache.removeAll()
        cacheLock.unlock()
    }
}
