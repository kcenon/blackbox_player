/// @file AccelerationParser.swift
/// @brief G센서(가속도계) 바이너리 데이터 파서
/// @author BlackboxPlayer Development Team
/// @details
/// 블랙박스 파일에 저장된 G센서 데이터를 읽어서 AccelerationData 객체로 변환합니다.
/// 바이너리 형식(Float32, Int16)과 텍스트 형식(CSV) 모두 지원합니다.

//
//  AccelerationParser.swift
//  BlackboxPlayer
//
//  G센서(가속도계) 바이너리 데이터 파서
//
//  [이 파일의 역할]
//  블랙박스 파일에 저장된 G센서 데이터를 읽어서 AccelerationData 객체로 변환합니다.
//  바이너리 형식(Float32, Int16)과 텍스트 형식(CSV) 모두 지원합니다.
//
//  [G센서 데이터란?]
//  자동차의 가속도를 3축(X, Y, Z)으로 측정한 데이터:
//  - X축: 좌우 가속도 (좌회전, 우회전)
//  - Y축: 전후 가속도 (가속, 브레이크)
//  - Z축: 상하 가속도 (과속방지턱, 점프)
//
//  [데이터 흐름]
//  1. 블랙박스 파일에서 G센서 바이너리 데이터 읽기
//  2. AccelerationParser로 파싱 → AccelerationData 배열
//  3. GSensorService에서 충격 감지, 분석
//  4. UI에 그래프로 시각화
//
//  바이너리 파일 → AccelerationParser → [AccelerationData] → GSensorService → 📊 그래프
//

import Foundation

// MARK: - AccelerationParser 클래스

/// @class AccelerationParser
/// @brief G센서 바이너리 데이터 파서
/// @details
/// 블랙박스에 저장된 가속도 데이터를 파싱합니다.
/// 다양한 데이터 형식(Float32, Int16, CSV)을 지원합니다.
///
/// ### 주요 기능:
/// 1. 바이너리 가속도 데이터 파싱 (Float32, Int16)
/// 2. CSV 텍스트 데이터 파싱
/// 3. 데이터 포맷 자동 감지
/// 4. 타임스탬프 계산
///
/// ### 사용 예시:
/// ```swift
/// // Float32 바이너리 데이터 파싱
/// let parser = AccelerationParser(sampleRate: 10.0, format: .float32)
/// let accelData = parser.parseAccelerationData(binaryData, baseDate: videoStartDate)
///
/// // CSV 텍스트 데이터 파싱
/// let csvData = parser.parseCSVData(csvData, baseDate: videoStartDate)
///
/// // 포맷 자동 감지
/// if let format = AccelerationParser.detectFormat(unknownData) {
///     let parser = AccelerationParser(format: format)
///     // ...
/// }
/// ```
class AccelerationParser {
    // MARK: - Properties

    /// @var sampleRate
    /// @brief 샘플링 주파수 (Hz, 초당 샘플 수)
    /// @details
    /// G센서가 1초에 몇 번 측정하는가를 나타냅니다.
    ///
    /// ### 일반적인 값:
    /// - 10 Hz: 블랙박스 표준 (1초에 10회 측정)
    /// - 50 Hz: 고급 블랙박스
    /// - 100 Hz: 전문 레이싱 로거
    ///
    /// ### 예시:
    /// ```
    /// sampleRate = 10 Hz
    /// → 1초 = 10개 샘플
    /// → 샘플 간격 = 1/10 = 0.1초 = 100ms
    /// ```
    private let sampleRate: Double

    /// @var format
    /// @brief 데이터 포맷 (Float32 또는 Int16)
    /// @details
    /// 블랙박스 제조사마다 다른 포맷을 사용합니다:
    /// - Float32: 높은 정밀도, 큰 메모리 (4바이트 × 3축 = 12바이트)
    /// - Int16: 메모리 절약, 충분한 정밀도 (2바이트 × 3축 = 6바이트, 50% 절감)
    private let format: AccelDataFormat

    // MARK: - Initialization

    /// @brief 파서 초기화
    /// @param sampleRate 샘플링 주파수 (기본값: 10 Hz)
    /// @param format 데이터 포맷 (기본값: Float32)
    /// @details
    /// AccelerationParser를 초기화합니다.
    ///
    /// ### 예시:
    /// ```swift
    /// // 기본 설정 (10 Hz, Float32)
    /// let parser1 = AccelerationParser()
    ///
    /// // 사용자 지정 설정
    /// let parser2 = AccelerationParser(sampleRate: 50.0, format: .int16)
    /// ```
    init(sampleRate: Double = 10.0, format: AccelDataFormat = .float32) {
        self.sampleRate = sampleRate
        self.format = format
    }

    // MARK: - Public Methods

    /// @brief 바이너리 가속도 데이터 파싱
    /// @param data 원시 바이너리 데이터
    /// @param baseDate 기준 시각 (비디오 시작 시간)
    /// @return AccelerationData 배열
    /// @details
    /// 블랙박스 파일에서 읽은 원시 바이너리 데이터를 AccelerationData 배열로 변환합니다.
    ///
    /// ### 데이터 구조:
    /// ```
    /// Float32 포맷 (12바이트 per 샘플):
    /// [X: 4바이트][Y: 4바이트][Z: 4바이트][X][Y][Z][X][Y][Z]...
    ///
    /// Int16 포맷 (6바이트 per 샘플):
    /// [X: 2바이트][Y: 2바이트][Z: 2바이트][X][Y][Z]...
    /// ```
    ///
    /// ### 타임스탬프 계산:
    /// ```
    /// sampleRate = 10 Hz (0.1초 간격)
    /// baseDate = 2024-10-12 15:30:00
    ///
    /// 샘플 0: 15:30:00.000 (baseDate + 0.0초)
    /// 샘플 1: 15:30:00.100 (baseDate + 0.1초)
    /// 샘플 2: 15:30:00.200 (baseDate + 0.2초)
    /// ...
    /// ```
    func parseAccelerationData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        var accelerationData: [AccelerationData] = []

        // 1샘플당 바이트 수 계산
        let bytesPerSample = format.bytesPerSample * 3  // X, Y, Z 3축
        // Float32: 4 × 3 = 12바이트
        // Int16: 2 × 3 = 6바이트

        let sampleCount = data.count / bytesPerSample

        guard sampleCount > 0 else { return [] }

        // 바이너리 데이터를 unsafe pointer로 접근 (성능 최적화)
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else { return }

            for i in 0..<sampleCount {
                let offset = i * bytesPerSample

                guard offset + bytesPerSample <= data.count else { break }

                // X, Y, Z 값 파싱
                let x: Double
                let y: Double
                let z: Double

                switch format {
                case .float32:
                    // Float32 파싱 (4바이트씩 읽기)
                    // [X: 4byte][Y: 4byte][Z: 4byte]
                    let xPtr = baseAddress.advanced(by: offset).assumingMemoryBound(to: Float.self)
                    let yPtr = baseAddress.advanced(by: offset + 4).assumingMemoryBound(to: Float.self)
                    let zPtr = baseAddress.advanced(by: offset + 8).assumingMemoryBound(to: Float.self)
                    x = Double(xPtr.pointee)
                    y = Double(yPtr.pointee)
                    z = Double(zPtr.pointee)

                case .int16:
                    // Int16 파싱 (2바이트씩 읽기)
                    // [X: 2byte][Y: 2byte][Z: 2byte]
                    let xPtr = baseAddress.advanced(by: offset).assumingMemoryBound(to: Int16.self)
                    let yPtr = baseAddress.advanced(by: offset + 2).assumingMemoryBound(to: Int16.self)
                    let zPtr = baseAddress.advanced(by: offset + 4).assumingMemoryBound(to: Int16.self)

                    // Int16 → G-force 변환
                    // ±2G 범위, 16비트 (-32768 ~ +32767)
                    // 스케일 팩터: 32768 / 2G = 16384
                    //
                    // 예시:
                    // 16384 → 16384 / 16384 = 1.0G
                    // 32767 → 32767 / 16384 = 2.0G (최대)
                    // -16384 → -16384 / 16384 = -1.0G
                    x = Double(xPtr.pointee) / 16384.0
                    y = Double(yPtr.pointee) / 16384.0
                    z = Double(zPtr.pointee) / 16384.0
                }

                // 타임스탬프 계산
                let timeOffset = Double(i) / sampleRate  // 샘플 인덱스 / 샘플링 주파수
                let timestamp = baseDate.addingTimeInterval(timeOffset)

                let accelData = AccelerationData(
                    timestamp: timestamp,
                    x: x,
                    y: y,
                    z: z
                )

                accelerationData.append(accelData)
            }
        }

        return accelerationData
    }

    /// @brief CSV 텍스트 데이터 파싱
    /// @param data CSV 데이터
    /// @param baseDate 기준 시각
    /// @return AccelerationData 배열
    /// @details
    /// CSV 형식의 가속도 데이터를 파싱합니다.
    /// 디버깅 또는 테스트용 데이터에 유용합니다.
    ///
    /// ### 지원 형식:
    /// ```
    /// 형식 1 (타임스탬프 포함):
    /// timestamp,x,y,z
    /// 0.0,-0.1,0.05,1.0
    /// 0.1,-0.2,0.1,0.98
    /// 0.2,-0.15,0.08,1.02
    ///
    /// 형식 2 (타임스탬프 없음):
    /// x,y,z
    /// -0.1,0.05,1.0
    /// -0.2,0.1,0.98
    /// -0.15,0.08,1.02
    /// ```
    func parseCSVData(_ data: Data, baseDate: Date) -> [AccelerationData] {
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var accelerationData: [AccelerationData] = []
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // 헤더 행 스킵
            if trimmed.hasPrefix("timestamp") || trimmed.hasPrefix("time") {
                continue
            }

            // CSV 파싱: timestamp,x,y,z 또는 x,y,z
            let fields = trimmed.components(separatedBy: ",")

            let timestamp: Date
            let startIndex: Int

            if fields.count >= 4 {
                // 형식 1: timestamp,x,y,z
                if let timeValue = Double(fields[0]) {
                    timestamp = baseDate.addingTimeInterval(timeValue)
                } else {
                    // 타임스탬프 파싱 실패 시 인덱스 기반
                    timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                }
                startIndex = 1
            } else if fields.count >= 3 {
                // 형식 2: x,y,z (타임스탬프 없음)
                timestamp = baseDate.addingTimeInterval(Double(index) / sampleRate)
                startIndex = 0
            } else {
                continue  // 잘못된 형식
            }

            guard let x = Double(fields[startIndex]),
                  let y = Double(fields[startIndex + 1]),
                  let z = Double(fields[startIndex + 2]) else {
                continue  // 숫자 파싱 실패
            }

            let accelData = AccelerationData(
                timestamp: timestamp,
                x: x,
                y: y,
                z: z
            )

            accelerationData.append(accelData)
        }

        return accelerationData
    }

    /// @brief 바이너리 데이터에서 포맷 자동 감지
    /// @param data 원시 데이터
    /// @return 감지된 포맷 (또는 nil)
    /// @details
    /// 데이터의 패턴을 분석하여 Float32인지 Int16인지 추측합니다.
    /// 완벽하지는 않지만 대부분의 경우 정확합니다.
    ///
    /// ### 감지 로직:
    /// ```
    /// 1. 첫 12바이트를 Float32로 해석
    /// 2. X, Y, Z 값이 합리적인 G-force 범위(-20 ~ +20G)인가?
    /// 3. 그렇다면 Float32, 아니면 Int16
    /// ```
    ///
    /// ### 한계:
    /// - 우연히 Int16 값이 Float32처럼 보일 수 있음
    /// - 데이터가 손상되었거나 비정상적인 경우 오감지 가능
    ///
    /// ### 사용 예시:
    /// ```swift
    /// let unknownData = readFromFile("accel.bin")
    ///
    /// if let format = AccelerationParser.detectFormat(unknownData) {
    ///     let parser = AccelerationParser(format: format)
    ///     let data = parser.parseAccelerationData(unknownData, baseDate: Date())
    /// } else {
    ///     print("포맷 감지 실패")
    /// }
    /// ```
    static func detectFormat(_ data: Data) -> AccelDataFormat? {
        // 최소 12바이트 필요 (Float32 × 3축)
        guard data.count >= 12 else { return nil }

        // Float32로 해석해서 합리적인 값인지 확인
        let isFloat = data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let baseAddress = ptr.baseAddress else { return false }

            let x = baseAddress.assumingMemoryBound(to: Float.self).pointee
            let y = baseAddress.advanced(by: 4).assumingMemoryBound(to: Float.self).pointee
            let z = baseAddress.advanced(by: 8).assumingMemoryBound(to: Float.self).pointee

            // 합리적인 G-force 범위 체크 (-20 ~ +20G)
            // 일반 주행: -2 ~ +2G
            // 충격: -10 ~ +10G
            // 극한 상황: -20 ~ +20G
            return abs(x) < 20 && abs(y) < 20 && abs(z) < 20
        }

        return isFloat ? .float32 : .int16
    }
}

// MARK: - Supporting Types

/// @enum AccelDataFormat
/// @brief 가속도 데이터 포맷
/// @details
/// 블랙박스 제조사마다 다른 바이너리 포맷을 사용합니다.
///
/// ### Float32 vs Int16 비교:
///
/// #### Float32 (4바이트):
/// ```
/// 장점:
/// ✅ 높은 정밀도 (소수점 7자리)
/// ✅ 처리 간편 (스케일링 불필요)
/// ✅ 넓은 범위 (±3.4 × 10³⁸)
///
/// 단점:
/// ❌ 메모리 2배 사용
///
/// 용도: 고급 블랙박스, 정밀 측정
/// ```
///
/// #### Int16 (2바이트):
/// ```
/// 장점:
/// ✅ 메모리 절약 (50%)
/// ✅ 충분한 정밀도 (±2G 범위에서 0.00012G)
///
/// 단점:
/// ❌ 스케일 변환 필요 (int → float)
/// ❌ 제한된 범위 (±2G 또는 ±16G)
///
/// 용도: 표준 블랙박스, 메모리 제약
/// ```
///
/// ### 메모리 비교 (1분 녹화, 10 Hz 샘플링):
/// ```
/// Float32: 12바이트 × 600샘플 = 7.2KB
/// Int16:    6바이트 × 600샘플 = 3.6KB (50% 절감)
/// ```
enum AccelDataFormat {
    /// @brief 32비트 부동소수점 (축당 4바이트)
    /// @details
    /// ### 메모리 레이아웃:
    /// ```
    /// [X: Float32][Y: Float32][Z: Float32]
    ///    4 bytes     4 bytes     4 bytes  = 12 bytes total
    /// ```
    ///
    /// ### 값 범위:
    /// -3.4 × 10³⁸ ~ +3.4 × 10³⁸ (실제로는 -20G ~ +20G 사용)
    ///
    /// ### 정밀도:
    /// 약 7자리 (0.00001G 단위까지 표현)
    case float32

    /// @brief 16비트 부호있는 정수 (축당 2바이트)
    /// @details
    /// ### 메모리 레이아웃:
    /// ```
    /// [X: Int16][Y: Int16][Z: Int16]
    ///   2 bytes   2 bytes   2 bytes  = 6 bytes total
    /// ```
    ///
    /// ### 값 범위:
    /// -32768 ~ +32767
    ///
    /// ### G-force 변환 (±2G 범위 가정):
    /// ```
    /// scale = 32768 / 2G = 16384 (per G)
    ///
    /// intValue → G-force:
    /// g = intValue / 16384.0
    ///
    /// 예:
    /// 16384 → 1.0G
    /// 32767 → 2.0G (최대)
    /// 0 → 0.0G
    /// -16384 → -1.0G
    /// ```
    ///
    /// ### 정밀도:
    /// 0.00012G (2G / 16384)
    case int16

    /// @var bytesPerSample
    /// @brief 축당 바이트 크기
    /// @return Float32: 4바이트, Int16: 2바이트
    var bytesPerSample: Int {
        switch self {
        case .float32:
            return 4  // Float = 4바이트
        case .int16:
            return 2  // Int16 = 2바이트
        }
    }
}

// MARK: - Parser Errors

/// @enum AccelerationParserError
/// @brief 파서 에러 타입
/// @details
/// 가속도 데이터 파싱 중 발생할 수 있는 오류를 정의합니다.
enum AccelerationParserError: Error {
    /// @brief 잘못된 데이터 포맷
    /// @details 예상한 포맷과 실제 데이터가 맞지 않습니다.
    case invalidFormat

    /// @brief 데이터 부족
    /// @details 1개 샘플 크기(6 or 12바이트)보다 작은 데이터입니다.
    case insufficientData

    /// @brief 잘못된 값
    /// @details G-force 값이 물리적으로 불가능한 범위 (100G 등)입니다.
    case invalidValue
}

extension AccelerationParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid acceleration data format"
        case .insufficientData:
            return "Insufficient data for parsing"
        case .invalidValue:
            return "Invalid acceleration value"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// 통합 가이드: AccelerationParser 사용 플로우
// ═══════════════════════════════════════════════════════════════════════════
//
// 1️⃣ 포맷 감지 (선택 사항)
// ────────────────────────────────────────────────
// let binaryData = readFromBlackboxFile()
//
// if let format = AccelerationParser.detectFormat(binaryData) {
//     print("감지된 포맷: \(format)")
// }
//
// 2️⃣ 파서 생성
// ────────────────────────────────────────────────
// let parser = AccelerationParser(
//     sampleRate: 10.0,      // 10 Hz
//     format: .float32       // Float32 포맷
// )
//
// 3️⃣ 바이너리 데이터 파싱
// ────────────────────────────────────────────────
// let videoStartDate = Date()  // 비디오 시작 시간
// let accelData = parser.parseAccelerationData(binaryData, baseDate: videoStartDate)
//
// print("파싱된 샘플 수: \(accelData.count)")
// // 출력: 파싱된 샘플 수: 600 (1분 × 10Hz)
//
// 4️⃣ 또는 CSV 파싱
// ────────────────────────────────────────────────
// let csvData = loadCSV("accel.csv")
// let accelData = parser.parseCSVData(csvData, baseDate: videoStartDate)
//
// 5️⃣ 데이터 활용
// ────────────────────────────────────────────────
// for data in accelData {
//     print("\(data.timestamp): X=\(data.x), Y=\(data.y), Z=\(data.z)")
//     if data.isImpact {
//         print("⚠️ 충격 감지!")
//     }
// }
//
// ═══════════════════════════════════════════════════════════════════════════
