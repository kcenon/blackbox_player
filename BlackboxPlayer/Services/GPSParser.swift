/// @file GPSParser.swift
/// @brief NMEA 0183 GPS 데이터 파서
/// @author BlackboxPlayer Development Team
/// @details
/// 블랙박스 비디오 파일에 포함된 NMEA 0183 형식의 GPS 데이터를 파싱하여 Swift 객체(GPSPoint)로 변환합니다.

/*
 ═══════════════════════════════════════════════════════════════════════════
 GPSParser.swift
 BlackboxPlayer

 NMEA 0183 GPS 데이터 파서
 ═══════════════════════════════════════════════════════════════════════════

 【NMEA 0183이란?】

 NMEA (National Marine Electronics Association) 0183은
 해양 전자기기 간 통신을 위한 표준 프로토콜입니다.

 블랙박스는 이 프로토콜을 사용하여 GPS 모듈로부터
 위치, 속도, 방향, 고도 등의 정보를 받아옵니다.


 【NMEA 문장 구조】

 $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
 │     │      │ │        │ │         │ │     │     │      │     │ │
 │     │      │ │        │ │         │ │     │     │      │     │ └─ 체크섬
 │     │      │ │        │ │         │ │     │     │      │     └─── 자기편차 방향
 │     │      │ │        │ │         │ │     │     │      └───────── 자기편차
 │     │      │ │        │ │         │ │     │     └──────────────── 날짜 (DDMMYY)
 │     │      │ │        │ │         │ │     └────────────────────── 진행방향 (도)
 │     │      │ │        │ │         │ └──────────────────────────── 속도 (knots)
 │     │      │ │        │ │         └────────────────────────────── 경도 방향 (E/W)
 │     │      │ │        │ └──────────────────────────────────────── 경도 (DDDMM.MMMM)
 │     │      │ │        └────────────────────────────────────────── 위도 방향 (N/S)
 │     │      │ └─────────────────────────────────────────────────── 위도 (DDMM.MMMM)
 │     │      └───────────────────────────────────────────────────── 상태 (A=유효, V=무효)
 │     └──────────────────────────────────────────────────────────── 시간 (HHMMSS)
 └────────────────────────────────────────────────────────────────── 문장 타입


 【주요 문장 타입】

 1. $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data)
 - 위치 (위도, 경도)
 - 속도 (knots)
 - 진행 방향 (도)
 - 날짜/시간
 ➜ 가장 기본적이고 필수적인 GPS 정보

 2. $GPGGA (Global Positioning System Fix Data)
 - 위치 (위도, 경도)
 - 고도 (해발 미터)
 - 위성 개수
 - HDOP (정확도 지표)
 ➜ 3D 위치와 정확도 정보

 3. $GNRMC, $GNGGA
 - GP: GPS 전용
 - GN: GPS + GLONASS + Galileo (복합 위성 시스템)
 ➜ 최신 수신기는 여러 위성 시스템을 동시 사용


 【좌표 형식 변환】

 NMEA 형식: DDMM.MMMM (도분)
 ┌─────────────────────────────────────┐
 │ 4807.038 (위도)                     │
 │ ││└─────── 분(Minutes): 07.038      │
 │ ││                                   │
 │ └┴──────── 도(Degrees): 48          │
 └─────────────────────────────────────┘

 십진수 도(Decimal Degrees) 변환:
 DD = 48 + (07.038 / 60)
 = 48 + 0.1173
 = 48.1173°

 방향:
 - N (북위) = 양수
 - S (남위) = 음수
 - E (동경) = 양수
 - W (서경) = 음수

 예: 4807.038,N → +48.1173° (북위 48.1173도)
 01131.000,E → +11.5167° (동경 11.5167도)


 【속도 단위 변환】

 NMEA는 속도를 knots(해리/시)로 표현:

 1 knot = 1 해리(nautical mile) / 1 시간
 = 1.852 km/h

 예: 022.4 knots = 022.4 × 1.852 = 41.48 km/h


 【HDOP (Horizontal Dilution of Precision)】

 위성들의 기하학적 배치에 따른 정확도 지표:

 HDOP 값      정확도
 ──────────────────────
 < 1       이상적 (거의 불가능)
 1-2       우수 (±1-2m)
 2-5       양호 (±2-5m)
 5-10      보통 (±5-10m)
 > 10      나쁨 (±10m 이상)

 ┌──────────────────────────────────────┐
 │       위성 배치에 따른 HDOP          │
 ├──────────────────────────────────────┤
 │                                      │
 │   위성1 ●                            │
 │                                      │
 │           ●   ← 고르게 분포           │
 │        위성2   (HDOP 낮음 = 정확)    │
 │                                      │
 │                   ● 위성3            │
 │                                      │
 │ vs.                                  │
 │                                      │
 │   위성1 ● ● 위성2                    │
 │           ● 위성3  ← 한쪽에 몰림      │
 │                    (HDOP 높음 = 부정확)│
 └──────────────────────────────────────┘


 【데이터 병합 전략】

 블랙박스는 보통 GPRMC와 GPGGA를 쌍으로 출력:

 $GPRMC,123519,A,4807.038,N,...  ← 위치, 속도, 방향
 $GPGGA,123519,4807.038,N,...    ← 같은 시간, 고도, 정확도 추가

 파서는 두 문장을 병합하여 완전한 GPSPoint 생성:

 ┌────────────────────────────────────────┐
 │ Step 1: GPRMC 파싱                     │
 │   - GPSPoint 생성 (고도 없음)          │
 │   - gpsPoints 배열에 추가              │
 │                                        │
 │ Step 2: GPGGA 파싱                     │
 │   - 마지막 GPSPoint를 업데이트         │
 │   - altitude, satelliteCount 추가      │
 │   - horizontalAccuracy 추가            │
 └────────────────────────────────────────┘


 【사용 예시】

 ```swift
 let parser = GPSParser()

 // MP4 파일에서 추출한 NMEA 데이터
 let nmeaData = """
 $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
 $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
 """.data(using: .utf8)!

 // 비디오 파일 날짜
 let baseDate = Date() // 20240115_143025_F.mp4에서 추출

 // 파싱
 let gpsPoints = parser.parseNMEA(data: nmeaData, baseDate: baseDate)

 // 결과
 for point in gpsPoints {
 print("위치: \(point.latitude), \(point.longitude)")
 print("고도: \(point.altitude ?? 0)m")
 print("속도: \(point.speed ?? 0) km/h")
 print("방향: \(point.heading ?? 0)°")
 print("위성: \(point.satelliteCount ?? 0)개")
 }
 ```


 【참고】

 1. NMEA 0183 표준 문서:
 https://www.nmea.org/content/STANDARDS/NMEA_0183_Standard

 2. 체크섬 계산:
 XOR of all characters between $ and *
 예: $GPRMC,... *6A
 6A는 16진수 체크섬 (현재 미구현)

 3. UTC 시간:
 NMEA 시간은 항상 UTC (협정세계시)
 한국 시간 = UTC + 9시간

 ═══════════════════════════════════════════════════════════════════════════
 */

import Foundation

/*
 ─────────────────────────────────────────────────────────────────────────
 GPSParser 클래스
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 블랙박스 비디오 파일에 포함된 NMEA 0183 형식의
 GPS 데이터를 파싱하여 Swift 객체(GPSPoint)로 변환합니다.


 【처리 흐름】

 ┌─────────────────────────────────────────────────────────────────┐
 │                                                                 │
 │  MP4 파일                                                        │
 │  ├── Video Track (H.264)                                        │
 │  ├── Audio Track (AAC)                                          │
 │  └── Data Track: GPS ──┐                                        │
 │         │              │                                        │
 │         │ NMEA Text    │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │ $GPRMC,143025... │  │                                        │
 │  │ $GPGGA,143025... │  │                                        │
 │  │ $GPRMC,143026... │  │                                        │
 │  │ $GPGGA,143026... │  │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │   GPSParser      │  │ ← 이 클래스                             │
 │  │   - parseNMEA()  │  │                                        │
 │  │   - parseGPRMC() │  │                                        │
 │  │   - parseGPGGA() │  │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  ┌──────────────────┐  │                                        │
 │  │ [GPSPoint]       │  │                                        │
 │  │ - lat: 37.7368   │  │                                        │
 │  │ - lon: 127.0761  │  │                                        │
 │  │ - alt: 123.4m    │  │                                        │
 │  │ - speed: 83.7 km/h│ │                                        │
 │  └──────────────────┘  │                                        │
 │         │              │                                        │
 │         ▼              │                                        │
 │  지도에 경로 표시        │                                        │
 │                        │                                        │
 └─────────────────────────────────────────────────────────────────┘


 【주요 기능】

 1. 전체 데이터 파싱: parseNMEA(data:baseDate:)
 - 여러 줄의 NMEA 문장을 한 번에 파싱
 - RMC와 GGA를 병합하여 완전한 GPSPoint 생성

 2. 단일 문장 파싱: parseSentence(_:)
 - 개별 NMEA 문장을 즉시 파싱
 - 실시간 GPS 수신 시 사용

 3. 좌표 변환: parseCoordinate(_:direction:)
 - DDMM.MMMM → 십진수 도

 4. 시간 변환: parseDateTime(time:date:)
 - HHMMSS + DDMMYY → Date
 - baseDate와 병합 (파일명에서 추출한 날짜)


 【설계 특징】

 ✓ 유연한 입력: $GPRMC, $GNRMC 모두 지원
 ✓ 데이터 병합: RMC와 GGA를 결합하여 완전한 정보 생성
 ✓ 오류 허용: 잘못된 문장은 건너뛰고 계속 처리
 ✓ UTC 기반: 모든 시간은 UTC로 처리

 ─────────────────────────────────────────────────────────────────────────
 */

/// @class GPSParser
/// @brief NMEA 0183 GPS 문장 파서
/// @details
/// 블랙박스 비디오 파일에 포함된 NMEA 0183 형식의 GPS 데이터를 파싱하여 GPSPoint 배열로 변환합니다.
///
/// ### 주요 기능:
/// 1. 전체 NMEA 데이터 파싱 (parseNMEA)
/// 2. 단일 NMEA 문장 파싱 (parseSentence)
/// 3. GPRMC 문장 파싱 (위치, 속도, 방향)
/// 4. GPGGA 문장 파싱 (고도, 위성 개수, 정확도)
/// 5. 좌표 형식 변환 (DDMM.MMMM → 십진수 도)
/// 6. 시간 변환 (HHMMSS + DDMMYY → Date)
class GPSParser {
    // MARK: - Properties

    /*
     ─────────────────────────────────────────────────────────────────────
     baseDate: 기준 날짜
     ─────────────────────────────────────────────────────────────────────

     【용도】

     NMEA 문장의 시간(HHMMSS)은 날짜 정보가 없거나 불완전합니다.
     파일명에서 추출한 날짜를 기준으로 완전한 타임스탬프를 생성합니다.


     【예시】

     파일명: 20240115_143025_F.mp4
     └──┬──┘
     기준 날짜 = 2024년 1월 15일

     NMEA: $GPRMC,143025,A,...
     └─┬─┘
     14:30:25

     최종 타임스탬프: 2024-01-15 14:30:25 UTC


     【초기화】

     parseNMEA(data:baseDate:) 호출 시 설정됩니다.

     ─────────────────────────────────────────────────────────────────────
     */

    /// @var baseDate
    /// @brief 기준 날짜
    /// @details
    /// NMEA 문장의 시간(HHMMSS)은 날짜 정보가 없거나 불완전하므로,
    /// 파일명에서 추출한 날짜를 기준으로 완전한 타임스탬프를 생성합니다.
    ///
    /// ### 용도:
    /// - parseNMEA(data:baseDate:) 호출 시 설정
    /// - parseDateTime(time:date:)에서 날짜 결합에 사용
    ///
    /// ### 예시:
    /// ```
    /// 파일명: 20240115_143025_F.mp4
    ///         └──┬──┘
    ///            기준 날짜 = 2024년 1월 15일
    ///
    /// NMEA: $GPRMC,143025,A,...
    ///               └─┬─┘
    ///                 14:30:25
    ///
    /// 최종 타임스탬프: 2024-01-15 14:30:25 UTC
    /// ```
    private var baseDate: Date?

    // MARK: - Public Methods

    /*
     ═════════════════════════════════════════════════════════════════════
     parseNMEA(data:baseDate:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     MP4 파일에서 추출한 NMEA 데이터 전체를 파싱하여
     GPSPoint 배열을 생성합니다.


     【파라미터】

     - data: UTF-8 인코딩된 NMEA 텍스트
     예: "$GPRMC,143025...\n$GPGGA,143025...\n"

     - baseDate: 비디오 파일의 날짜 (파일명에서 추출)
     예: 20240115_143025_F.mp4 → 2024-01-15


     【반환값】

     [GPSPoint]: 타임스탬프 순서로 정렬된 GPS 포인트 배열


     【처리 과정】

     Step 1: 텍스트를 줄 단위로 분리
     ┌────────────────────────────────────┐
     │ $GPRMC,143025,A,3744.1234,N,...    │
     │ $GPGGA,143025,3744.1234,N,...      │
     │ $GPRMC,143026,A,3744.1235,N,...    │
     │ $GPGGA,143026,3744.1235,N,...      │
     └────────────────────────────────────┘
     │
     │ components(separatedBy: .newlines)
     ▼
     [Line 1, Line 2, Line 3, Line 4]


     Step 2: 각 줄을 파싱
     ┌─────────────────────────────────────────────────┐
     │ for line in lines {                             │
     │   if line.hasPrefix("$GPRMC") {                 │
     │     let rmc = parseGPRMC(line)                  │
     │     let point = createGPSPoint(from: rmc)       │
     │     gpsPoints.append(point)  ← 배열에 추가      │
     │     currentRMC = rmc          ← 임시 저장       │
     │   }                                             │
     │   else if line.hasPrefix("$GPGGA") {            │
     │     let gga = parseGPGGA(line)                  │
     │     // 마지막 point를 업데이트                   │
     │     gpsPoints[lastIndex].altitude = gga.altitude│
     │     gpsPoints[lastIndex].satelliteCount = ...   │
     │   }                                             │
     │ }                                               │
     └─────────────────────────────────────────────────┘


     Step 3: 병합 결과
     ┌──────────────────────────────────────────┐
     │ GPSPoint #1                              │
     │ ├─ timestamp: 2024-01-15 14:30:25 UTC    │
     │ ├─ latitude: 37.7354° (GPRMC)            │
     │ ├─ longitude: 127.0761° (GPRMC)          │
     │ ├─ speed: 83.7 km/h (GPRMC)              │
     │ ├─ heading: 120.0° (GPRMC)               │
     │ ├─ altitude: 123.4m (GPGGA) ← 추가       │
     │ ├─ satelliteCount: 8 (GPGGA) ← 추가      │
     │ └─ horizontalAccuracy: 12m (GPGGA) ← 추가│
     └──────────────────────────────────────────┘


     【오류 처리】

     - 빈 문장: 건너뛰기
     - $ 없는 문장: 건너뛰기
     - 상태 V (무효): 건너뛰기
     - 좌표 파싱 실패: 건너뛰기
     - UTF-8 디코딩 실패: 빈 배열 반환

     ➜ 잘못된 데이터가 있어도 유효한 데이터는 모두 추출


     【예시】

     ```swift
     let parser = GPSParser()

     let nmeaData = """
     $GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A
     $GPGGA,143025,3744.1234,N,12704.5678,E,1,08,1.2,123.4,M,20.1,M,,*4D
     $GPRMC,143026,A,3744.1235,N,12704.5679,E,45.3,121.0,150124,,,A*6B
     $GPGGA,143026,3744.1235,N,12704.5679,E,1,08,1.2,123.5,M,20.1,M,,*4E
     """.data(using: .utf8)!

     let baseDate = dateFormatter.date(from: "20240115")!
     let points = parser.parseNMEA(data: nmeaData, baseDate: baseDate)

     print("추출된 GPS 포인트: \(points.count)개")
     // 출력: 추출된 GPS 포인트: 2개

     for (i, point) in points.enumerated() {
     print("Point \(i + 1):")
     print("  시간: \(point.timestamp)")
     print("  위치: \(point.latitude)°, \(point.longitude)°")
     print("  고도: \(point.altitude ?? 0)m")
     print("  속도: \(point.speed ?? 0) km/h")
     print("  방향: \(point.heading ?? 0)°")
     print("  위성: \(point.satelliteCount ?? 0)개")
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief NMEA 데이터 전체 파싱
    /// @param data UTF-8 인코딩된 NMEA 텍스트 데이터
    /// @param baseDate 비디오 파일의 날짜 (파일명에서 추출)
    /// @return 타임스탬프 순서로 정렬된 GPSPoint 배열
    /// @details
    /// MP4 파일에서 추출한 NMEA 데이터 전체를 파싱하여 GPSPoint 배열을 생성합니다.
    ///
    /// ### 처리 과정:
    /// ```
    /// Step 1: 텍스트를 줄 단위로 분리
    /// Step 2: 각 줄을 파싱
    ///   - GPRMC: GPSPoint 생성 및 배열에 추가
    ///   - GPGGA: 마지막 GPSPoint 업데이트 (고도, 위성 개수, 정확도 추가)
    /// Step 3: 병합 결과 반환
    /// ```
    ///
    /// ### 오류 처리:
    /// - 빈 문장: 건너뛰기
    /// - $ 없는 문장: 건너뛰기
    /// - 상태 V (무효): 건너뛰기
    /// - 좌표 파싱 실패: 건너뛰기
    /// - UTF-8 디코딩 실패: 빈 배열 반환
    func parseNMEA(data: Data, baseDate: Date) -> [GPSPoint] {
        // 기준 날짜 저장
        // (시간 파싱 시 parseDateTime()에서 사용)
        self.baseDate = baseDate

        // Step 1: UTF-8 텍스트로 디코딩
        // Data → String 변환 실패 시 빈 배열 반환
        guard let text = String(data: data, encoding: .utf8) else {
            return []
        }

        // Step 2: 줄 단위로 분리
        // "...\n...\n..." → ["...", "...", "..."]
        let lines = text.components(separatedBy: .newlines)

        // 결과를 저장할 배열
        var gpsPoints: [GPSPoint] = []

        // GPRMC와 GPGGA를 병합하기 위한 임시 저장소
        // GPRMC 파싱 후 저장, GPGGA 파싱 시 참조
        var currentRMC: NMEARecord?

        // Step 3: 각 줄을 순회하며 파싱
        for line in lines {
            // 앞뒤 공백 제거
            let sentence = line.trimmingCharacters(in: .whitespaces)

            // 빈 줄이거나 $ 로 시작하지 않으면 건너뛰기
            // NMEA 문장은 반드시 $ 로 시작
            guard !sentence.isEmpty, sentence.hasPrefix("$") else { continue }

            // Step 3-1: GPRMC 또는 GNRMC 문장 처리
            // (위치, 속도, 방향 정보)
            if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
                // GPRMC 파싱
                if let rmc = parseGPRMC(sentence) {
                    // 임시 저장 (다음 GPGGA와 병합하기 위해)
                    currentRMC = rmc

                    // GPSPoint 생성 및 배열에 추가
                    // (나중에 GPGGA로 업데이트될 수 있음)
                    if let point = createGPSPoint(from: rmc) {
                        gpsPoints.append(point)
                    }
                }
            }
            // Step 3-2: GPGGA 또는 GNGGA 문장 처리
            // (고도, 위성 개수, 정확도 정보)
            else if sentence.hasPrefix("$GPGGA") || sentence.hasPrefix("$GNGGA") {
                // GPGGA 파싱 및 이전 RMC 확인
                if let gga = parseGPGGA(sentence), let rmc = currentRMC {
                    // 마지막에 추가된 GPSPoint를 업데이트
                    if !gpsPoints.isEmpty {
                        let lastIndex = gpsPoints.count - 1
                        let lastPoint = gpsPoints[lastIndex]

                        // GPRMC 데이터는 유지하고,
                        // GPGGA 데이터(고도, 위성 개수, 정확도)만 추가
                        gpsPoints[lastIndex] = GPSPoint(
                            timestamp: lastPoint.timestamp,
                            latitude: lastPoint.latitude,
                            longitude: lastPoint.longitude,
                            altitude: gga.altitude,              // GPGGA에서 추가
                            speed: lastPoint.speed,
                            heading: lastPoint.heading,
                            horizontalAccuracy: gga.hdop.map { $0 * 10 },  // HDOP → 미터 (대략)
                            satelliteCount: gga.satelliteCount   // GPGGA에서 추가
                        )
                    }
                }
            }
        }

        return gpsPoints
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseSentence(_:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     단일 NMEA 문장을 즉시 파싱합니다.


     【사용 사례】

     1. 실시간 GPS 스트리밍:
     GPS 모듈에서 한 줄씩 수신될 때

     2. 디버깅:
     특정 문장의 파싱 결과를 테스트


     【제한사항】

     - GPRMC만 지원 (GPGGA는 RMC와 병합되어야 하므로 미지원)
     - 고도, 위성 개수 정보 없음
     - baseDate가 설정되어 있어야 함


     【예시】

     ```swift
     let parser = GPSParser()
     parser.baseDate = Date() // 기준 날짜 설정 필요

     let sentence = "$GPRMC,143025,A,3744.1234,N,12704.5678,E,45.2,120.0,150124,,,A*6A"

     if let point = parser.parseSentence(sentence) {
     print("위치: \(point.latitude), \(point.longitude)")
     print("속도: \(point.speed ?? 0) km/h")
     }
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief 단일 NMEA 문장 파싱
    /// @param sentence NMEA 문장 문자열
    /// @return GPSPoint 또는 nil (파싱 실패 시)
    /// @details
    /// 단일 NMEA 문장을 즉시 파싱합니다.
    ///
    /// ### 사용 사례:
    /// 1. 실시간 GPS 스트리밍: GPS 모듈에서 한 줄씩 수신될 때
    /// 2. 디버깅: 특정 문장의 파싱 결과를 테스트
    ///
    /// ### 제한사항:
    /// - GPRMC만 지원 (GPGGA는 RMC와 병합되어야 하므로 미지원)
    /// - 고도, 위성 개수 정보 없음
    /// - baseDate가 설정되어 있어야 함
    func parseSentence(_ sentence: String) -> GPSPoint? {
        // GPRMC 또는 GNRMC만 지원
        if sentence.hasPrefix("$GPRMC") || sentence.hasPrefix("$GNRMC") {
            if let rmc = parseGPRMC(sentence) {
                return createGPSPoint(from: rmc)
            }
        }
        return nil
    }

    // MARK: - Private Methods

    /*
     ═════════════════════════════════════════════════════════════════════
     parseGPRMC(_:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data) 문장을 파싱합니다.


     【GPRMC 문장 구조】

     $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A

     필드 번호:
     [0]  $GPRMC        - 문장 타입
     [1]  123519        - UTC 시간 (HHMMSS)
     [2]  A             - 상태 (A=유효, V=무효)
     [3]  4807.038      - 위도 (DDMM.MMMM)
     [4]  N             - 위도 방향 (N=북, S=남)
     [5]  01131.000     - 경도 (DDDMM.MMMM)
     [6]  E             - 경도 방향 (E=동, W=서)
     [7]  022.4         - 속도 (knots)
     [8]  084.4         - 진행 방향 (도, 0-359)
     [9]  230394        - UTC 날짜 (DDMMYY)
     [10] 003.1         - 자기 편차 (도)
     [11] W             - 자기 편차 방향 (E/W)
     [12] *6A           - 체크섬


     【필수 필드】

     ✓ [1] 시간
     ✓ [2] 상태 (A만 유효)
     ✓ [3][4] 위도 및 방향
     ✓ [5][6] 경도 및 방향
     ✓ [7] 속도
     ✓ [8] 진행 방향
     ✓ [9] 날짜 (선택적)


     【상태 코드】

     A (Active):   GPS 신호 정상, 위치 유효
     V (Void):     GPS 신호 없음, 위치 무효

     ➜ 상태가 V이면 파싱하지 않음


     【속도 변환】

     NMEA: 022.4 knots
     │
     │ × 1.852
     ▼
     Swift: 41.48 km/h


     【진행 방향】

     북쪽(N)을 0도로 하여 시계방향으로 증가:

     0° (N)
     │
     270° ─┼─ 90° (E)
     │
     180° (S)

     예:
     - 45°: 북동쪽
     - 90°: 동쪽
     - 135°: 남동쪽
     - 270°: 서쪽


     【날짜 파싱】

     230394 (DDMMYY)
     ││└┴── 년: 94 → 1994 또는 2094?
     ││
     │└──── 월: 03 (3월)
     └───── 일: 23 (23일)

     2000년 이후로 가정: 2094년
     1900년대: 직접 처리 필요

     ➜ baseDate가 더 정확하므로 날짜는 선택적으로만 사용


     【파싱 실패 조건】

     1. 필드 개수 < 10
     2. 상태가 V (무효)
     3. 시간 파싱 실패
     4. 위도 파싱 실패
     5. 경도 파싱 실패

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief GPRMC 문장 파싱
    /// @param sentence GPRMC 문장 문자열
    /// @return NMEARecord 또는 nil (파싱 실패 시)
    /// @details
    /// $GPRMC (Recommended Minimum Specific GPS/TRANSIT Data) 문장을 파싱합니다.
    ///
    /// ### GPRMC 문장 구조:
    /// ```
    /// $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
    ///
    /// 필드:
    /// [0]  $GPRMC        - 문장 타입
    /// [1]  123519        - UTC 시간 (HHMMSS)
    /// [2]  A             - 상태 (A=유효, V=무효)
    /// [3]  4807.038      - 위도 (DDMM.MMMM)
    /// [4]  N             - 위도 방향 (N=북, S=남)
    /// [5]  01131.000     - 경도 (DDDMM.MMMM)
    /// [6]  E             - 경도 방향 (E=동, W=서)
    /// [7]  022.4         - 속도 (knots)
    /// [8]  084.4         - 진행 방향 (도, 0-359)
    /// [9]  230394        - UTC 날짜 (DDMMYY)
    /// [10] 003.1         - 자기 편차 (도)
    /// [11] W             - 자기 편차 방향 (E/W)
    /// [12] *6A           - 체크섬
    /// ```
    ///
    /// ### 파싱 실패 조건:
    /// 1. 필드 개수 < 10
    /// 2. 상태가 V (무효)
    /// 3. 시간 파싱 실패
    /// 4. 위도 파싱 실패
    /// 5. 경도 파싱 실패
    private func parseGPRMC(_ sentence: String) -> NMEARecord? {
        // $GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A
        // Fields: [0]Type, [1]Time, [2]Status, [3]Lat, [4]LatDir, [5]Lon, [6]LonDir,
        //         [7]Speed, [8]Heading, [9]Date, [10]MagVar, [11]MagVarDir, [12]Checksum

        // Step 1: 쉼표로 분리
        // "$GPRMC,123519,A,..." → ["$GPRMC", "123519", "A", ...]
        let fields = sentence.components(separatedBy: ",")

        // 최소 10개 필드 필요
        guard fields.count >= 10 else { return nil }

        // Step 2: 상태 확인
        // A = Active (유효), V = Void (무효)
        guard fields[2] == "A" else { return nil }

        // Step 3: 시간 및 날짜 파싱
        // fields[1]: HHMMSS
        // fields[9]: DDMMYY (선택적)
        guard let timestamp = parseDateTime(time: fields[1], date: fields.count > 9 ? fields[9] : nil) else {
            return nil
        }

        // Step 4: 위도 파싱
        // fields[3]: DDMM.MMMM
        // fields[4]: N 또는 S
        guard let latitude = parseCoordinate(fields[3], direction: fields[4]) else {
            return nil
        }

        // Step 5: 경도 파싱
        // fields[5]: DDDMM.MMMM
        // fields[6]: E 또는 W
        guard let longitude = parseCoordinate(fields[5], direction: fields[6]) else {
            return nil
        }

        // Step 6: 속도 파싱 (knots → km/h)
        // 예: "022.4" → 22.4 knots → 41.48 km/h
        let speed = Double(fields[7]).map { $0 * 1.852 }  // Convert knots to km/h

        // Step 7: 진행 방향 파싱 (도)
        // 예: "084.4" → 84.4°
        let heading = Double(fields[8])

        // Step 8: NMEARecord 생성
        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: nil,           // GPRMC에는 고도 정보 없음
            speed: speed,
            heading: heading,
            hdop: nil,               // GPRMC에는 HDOP 정보 없음
            satelliteCount: nil      // GPRMC에는 위성 개수 정보 없음
        )
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseGPGGA(_:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     $GPGGA (Global Positioning System Fix Data) 문장을 파싱합니다.


     【GPGGA 문장 구조】

     $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47

     필드 번호:
     [0]  $GPGGA        - 문장 타입
     [1]  123519        - UTC 시간 (HHMMSS)
     [2]  4807.038      - 위도 (DDMM.MMMM)
     [3]  N             - 위도 방향
     [4]  01131.000     - 경도 (DDDMM.MMMM)
     [5]  E             - 경도 방향
     [6]  1             - GPS 품질 (0=무효, 1=GPS, 2=DGPS)
     [7]  08            - 사용 중인 위성 개수
     [8]  0.9           - HDOP (수평 정밀도 저하)
     [9]  545.4         - 고도 (해발)
     [10] M             - 고도 단위 (미터)
     [11] 46.9          - 지오이드 높이
     [12] M             - 지오이드 높이 단위
     [13] (empty)       - DGPS 마지막 업데이트 시간
     [14] *47           - 체크섬


     【필수 필드】

     ✓ [1] 시간
     ✓ [2][3] 위도 및 방향
     ✓ [4][5] 경도 및 방향
     ✓ [6] GPS 품질 (0이 아니어야 함)
     ✓ [7] 위성 개수
     ✓ [8] HDOP
     ✓ [9] 고도


     【GPS 품질 지표】

     0: 무효 (GPS 신호 없음)
     1: GPS 단독 측위
     2: DGPS (Differential GPS) - 더 정확
     3: PPS (Precise Positioning Service)
     4: RTK (Real Time Kinematic) - cm 단위 정확도
     5: Float RTK
     6: Dead Reckoning (추측 항법)

     ➜ 0이면 파싱하지 않음


     【HDOP (Horizontal Dilution of Precision)】

     위성 배치의 기하학적 정확도 지표:

     HDOP   정확도       사용 가능성
     ───────────────────────────────
     < 1    이상적      우수
     1-2    우수        권장
     2-5    양호        일반 사용
     5-10   보통        주의
     > 10   나쁨        사용 제한

     예: HDOP 0.9 → 우수한 정확도
     HDOP 5.2 → 보통 정확도


     【고도 측정】

     $GPGGA의 고도는 WGS84 타원체 기준:

     ┌────────────────────────────────────┐
     │        위성                         │
     │         │                          │
     │    거리 측정                        │
     │         ▼                          │
     │ ┌──────────────┐ ← 고도 545.4m     │
     │ │   수신기     │                   │
     │ └──────────────┘                   │
     │ ════════════════ ← 지오이드 (평균 해수면)│
     │ ~~~~~~~~~~~~~~~~~                  │
     │ WGS84 타원체 ← 기준면               │
     └────────────────────────────────────┘

     실제 해발 고도 = 고도 - 지오이드 높이
     = 545.4 - 46.9
     = 498.5m

     ➜ 블랙박스에서는 보통 WGS84 고도를 그대로 사용


     【위성 개수】

     GPS는 최소 4개 위성이 필요:
     - 3개: 2D 위치 (위도, 경도)
     - 4개: 3D 위치 (위도, 경도, 고도)

     실제로는 8-12개 위성이 보임:
     - 더 많은 위성 = 더 정확한 위치
     - HDOP 값이 낮아짐


     【GPRMC와 차이】

     GPRMC:
     ✓ 속도, 진행 방향
     ✓ 날짜
     ✗ 고도
     ✗ 위성 개수
     ✗ 정확도

     GPGGA:
     ✗ 속도, 진행 방향
     ✗ 날짜
     ✓ 고도
     ✓ 위성 개수
     ✓ 정확도 (HDOP)

     ➜ 두 문장을 병합하면 완전한 GPS 정보

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief GPGGA 문장 파싱
    /// @param sentence GPGGA 문장 문자열
    /// @return NMEARecord 또는 nil (파싱 실패 시)
    /// @details
    /// $GPGGA (Global Positioning System Fix Data) 문장을 파싱합니다.
    ///
    /// ### GPGGA 문장 구조:
    /// ```
    /// $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
    ///
    /// 필드:
    /// [0]  $GPGGA        - 문장 타입
    /// [1]  123519        - UTC 시간 (HHMMSS)
    /// [2]  4807.038      - 위도 (DDMM.MMMM)
    /// [3]  N             - 위도 방향
    /// [4]  01131.000     - 경도 (DDDMM.MMMM)
    /// [5]  E             - 경도 방향
    /// [6]  1             - GPS 품질 (0=무효, 1=GPS, 2=DGPS)
    /// [7]  08            - 사용 중인 위성 개수
    /// [8]  0.9           - HDOP (수평 정밀도 저하)
    /// [9]  545.4         - 고도 (해발)
    /// [10] M             - 고도 단위 (미터)
    /// [11] 46.9          - 지오이드 높이
    /// [12] M             - 지오이드 높이 단위
    /// [13] (empty)       - DGPS 마지막 업데이트 시간
    /// [14] *47           - 체크섬
    /// ```
    ///
    /// ### GPS 품질 지표:
    /// ```
    /// 0: 무효 (GPS 신호 없음)
    /// 1: GPS 단독 측위
    /// 2: DGPS (Differential GPS) - 더 정확
    /// 3: PPS (Precise Positioning Service)
    /// 4: RTK (Real Time Kinematic) - cm 단위 정확도
    /// 5: Float RTK
    /// 6: Dead Reckoning (추측 항법)
    /// ```
    private func parseGPGGA(_ sentence: String) -> NMEARecord? {
        // $GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47
        // Fields: [0]Type, [1]Time, [2]Lat, [3]LatDir, [4]Lon, [5]LonDir,
        //         [6]Quality, [7]NumSats, [8]HDOP, [9]Alt, [10]AltUnit, ...

        // Step 1: 쉼표로 분리
        let fields = sentence.components(separatedBy: ",")

        // 최소 11개 필드 필요
        guard fields.count >= 11 else { return nil }

        // Step 2: GPS 품질 확인
        // 0 = 무효, 1+ = 유효
        guard let quality = Int(fields[6]), quality > 0 else { return nil }

        // Step 3: 시간 파싱
        // GPGGA에는 날짜 정보가 없으므로 baseDate 사용
        guard let timestamp = parseDateTime(time: fields[1], date: nil) else {
            return nil
        }

        // Step 4: 좌표 파싱
        guard let latitude = parseCoordinate(fields[2], direction: fields[3]),
              let longitude = parseCoordinate(fields[4], direction: fields[5]) else {
            return nil
        }

        // Step 5: 고도 파싱 (미터)
        // 예: "545.4" → 545.4m
        let altitude = Double(fields[9])

        // Step 6: 위성 개수 파싱
        // 예: "08" → 8개
        let satelliteCount = Int(fields[7])

        // Step 7: HDOP 파싱
        // 예: "0.9" → 0.9 (우수한 정확도)
        let hdop = Double(fields[8])

        // Step 8: NMEARecord 생성
        return NMEARecord(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: nil,              // GPGGA에는 속도 정보 없음
            heading: nil,            // GPGGA에는 방향 정보 없음
            hdop: hdop,
            satelliteCount: satelliteCount
        )
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseCoordinate(_:direction:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     NMEA 형식의 좌표를 십진수 도(Decimal Degrees)로 변환합니다.


     【NMEA 좌표 형식】

     위도: DDMM.MMMM (2자리 도 + 분)
     경도: DDDMM.MMMM (3자리 도 + 분)


     【변환 과정】

     예 1: 위도 "4807.038" + "N"

     Step 1: 자리수 판단
     ┌────────────────────────────────┐
     │ 4807.038                       │
     │ ││                             │
     │ └┴─ Degrees (2자리, 위도)      │
     └────────────────────────────────┘

     Step 2: 도와 분 분리
     ┌─────────────────┬──────────────┐
     │ Degrees: "48"   │ Minutes: "07.038"│
     │         = 48    │         = 7.038  │
     └─────────────────┴──────────────┘

     Step 3: 십진수 도 변환
     ┌────────────────────────────────────┐
     │ 분 → 도 변환:                       │
     │   7.038 minutes ÷ 60 = 0.1173°    │
     │                                    │
     │ 최종 위도:                          │
     │   48° + 0.1173° = 48.1173°        │
     └────────────────────────────────────┘

     Step 4: 방향 적용
     ┌────────────────────────────────────┐
     │ "N" (북위) → 양수                   │
     │ 최종: +48.1173°                    │
     └────────────────────────────────────┘


     예 2: 경도 "01131.000" + "E"

     Step 1: 자리수 판단
     ┌────────────────────────────────┐
     │ 01131.000                      │
     │ │││                            │
     │ └┴┴─ Degrees (3자리, 경도)     │
     └────────────────────────────────┘

     Step 2: 도와 분 분리
     ┌─────────────────┬──────────────┐
     │ Degrees: "011"  │ Minutes: "31.000"│
     │         = 11    │         = 31.0   │
     └─────────────────┴──────────────┘

     Step 3: 십진수 도 변환
     ┌────────────────────────────────────┐
     │ 분 → 도 변환:                       │
     │   31.0 minutes ÷ 60 = 0.5167°     │
     │                                    │
     │ 최종 경도:                          │
     │   11° + 0.5167° = 11.5167°        │
     └────────────────────────────────────┘

     Step 4: 방향 적용
     ┌────────────────────────────────────┐
     │ "E" (동경) → 양수                   │
     │ 최종: +11.5167°                    │
     └────────────────────────────────────┘


     【방향 코드】

     위도:
     - N (North, 북위): 0° ~ +90°
     - S (South, 남위): 0° ~ -90°

     경도:
     - E (East, 동경): 0° ~ +180°
     - W (West, 서경): 0° ~ -180°


     【한국의 좌표 범위】

     위도: 33° ~ 38° N (북위, 양수)
     경도: 124° ~ 132° E (동경, 양수)

     예: 서울 (Seoul)
     - 위도: 37.5665° N → +37.5665°
     - 경도: 126.9780° E → +126.9780°


     【오류 처리】

     1. 빈 문자열 → nil
     2. 도 자리수 부족 → nil
     3. 숫자 파싱 실패 → nil


     【예시】

     ```swift
     // 서울 남산
     let lat = parseCoordinate("3733.990", direction: "N")
     // Result: 37.5665°

     let lon = parseCoordinate("12658.680", direction: "E")
     // Result: 126.9780°

     // 남반구 (호주 시드니)
     let sydneyLat = parseCoordinate("3352.000", direction: "S")
     // Result: -33.8667°

     // 서경 (미국 뉴욕)
     let nyLon = parseCoordinate("07400.000", direction: "W")
     // Result: -74.0000°
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief NMEA 좌표를 십진수 도로 변환
    /// @param value NMEA 좌표 문자열 (예: "4807.038" 또는 "01131.000")
    /// @param direction 방향 문자열 (N/S/E/W)
    /// @return 십진수 도 (Decimal Degrees) 또는 nil (파싱 실패 시)
    /// @details
    /// NMEA 형식의 좌표를 십진수 도(Decimal Degrees)로 변환합니다.
    ///
    /// ### NMEA 좌표 형식:
    /// ```
    /// 위도: DDMM.MMMM (2자리 도 + 분)
    /// 경도: DDDMM.MMMM (3자리 도 + 분)
    /// ```
    ///
    /// ### 변환 과정:
    /// ```
    /// 예: "4807.038" + "N"
    ///
    /// Step 1: 도와 분 분리
    ///   Degrees: "48" = 48
    ///   Minutes: "07.038" = 7.038
    ///
    /// Step 2: 십진수 도 변환
    ///   7.038 minutes ÷ 60 = 0.1173°
    ///   48° + 0.1173° = 48.1173°
    ///
    /// Step 3: 방향 적용
    ///   "N" (북위) → 양수
    ///   최종: +48.1173°
    /// ```
    ///
    /// ### 방향 코드:
    /// ```
    /// 위도: N (북위, 0° ~ +90°), S (남위, 0° ~ -90°)
    /// 경도: E (동경, 0° ~ +180°), W (서경, 0° ~ -180°)
    /// ```
    private func parseCoordinate(_ value: String, direction: String) -> Double? {
        // 빈 값 체크
        guard !value.isEmpty, !direction.isEmpty else { return nil }

        // Step 1: 위도인지 경도인지 판단
        // 위도: N 또는 S → 도 2자리
        // 경도: E 또는 W → 도 3자리
        let isLatitude = direction == "N" || direction == "S"
        let degreeDigits = isLatitude ? 2 : 3

        // Step 2: 길이 확인
        // 최소: DD.M (위도) 또는 DDD.M (경도)
        guard value.count > degreeDigits else { return nil }

        // Step 3: 도와 분 분리
        // "4807.038" → "48" + "07.038"
        let degreeString = String(value.prefix(degreeDigits))
        let minuteString = String(value.dropFirst(degreeDigits))

        // Step 4: 문자열 → 숫자 변환
        guard let degrees = Double(degreeString),
              let minutes = Double(minuteString) else {
            return nil
        }

        // Step 5: 십진수 도 계산
        // DD + (MM.MMMM / 60)
        // 예: 48 + (7.038 / 60) = 48.1173
        var coordinate = degrees + (minutes / 60.0)

        // Step 6: 방향에 따라 부호 결정
        // S (남위) 또는 W (서경) → 음수
        if direction == "S" || direction == "W" {
            coordinate = -coordinate
        }

        return coordinate
    }

    /*
     ═════════════════════════════════════════════════════════════════════
     parseDateTime(time:date:)
     ═════════════════════════════════════════════════════════════════════

     【기능】

     NMEA 시간과 날짜를 Swift Date 객체로 변환합니다.


     【입력 형식】

     time: HHMMSS 또는 HHMMSS.sss
     └┬┘└┬┘└┬┘
     시 분 초

     date: DDMMYY (선택적)
     └┬┘└┬┘└┬┘
     일 월 년(2자리)


     【변환 과정】

     예: time = "143025", date = "150124", baseDate = 2024-01-15

     Step 1: 시간 파싱
     ┌────────────────────────────────┐
     │ "143025"                       │
     │  │││└┴─ 초: "25" → 25          │
     │  ││└──── 분: "30" → 30         │
     │  └┴───── 시: "14" → 14         │
     └────────────────────────────────┘

     Step 2: 날짜 파싱 (있으면)
     ┌────────────────────────────────┐
     │ "150124"                       │
     │  │││└┴─ 년: "24" → 2024        │
     │  ││└──── 월: "01" → 1          │
     │  └┴───── 일: "15" → 15         │
     └────────────────────────────────┘

     Step 3: Date 객체 생성
     ┌────────────────────────────────┐
     │ DateComponents:                │
     │ - year: 2024                   │
     │ - month: 1                     │
     │ - day: 15                      │
     │ - hour: 14                     │
     │ - minute: 30                   │
     │ - second: 25                   │
     │ - timeZone: UTC                │
     └────────────────────────────────┘
     │
     ▼
     Date: 2024-01-15 14:30:25 +0000 (UTC)


     【baseDate 사용】

     NMEA 날짜가 없거나 부정확할 때 baseDate를 사용:

     ┌──────────────────────────────────────┐
     │ 파일명: 20240115_143025_F.mp4        │
     │          └───┬──┘                    │
     │              baseDate = 2024-01-15   │
     └──────────────────────────────────────┘
     │
     │ NMEA에 날짜 없음
     ▼
     ┌──────────────────────────────────────┐
     │ baseDate의 년/월/일 사용             │
     │ NMEA의 시/분/초 사용                 │
     └──────────────────────────────────────┘


     【2자리 년도 처리】

     NMEA: "24" (YY)
     │
     │ + 2000
     ▼
     Swift: 2024 (YYYY)

     ⚠️ 2100년 이후는 처리 불가


     【UTC 시간대】

     GPS는 항상 UTC (협정세계시) 사용:

     ┌──────────────────────────────────────┐
     │ GPS 시각: 14:30:25 UTC               │
     │            │                         │
     │            │ + 9시간                 │
     │            ▼                         │
     │ 한국 시각: 23:30:25 KST              │
     └──────────────────────────────────────┘

     ➜ Date 객체는 UTC로 저장
     ➜ 표시할 때 로컬 시간대로 변환


     【밀리초 처리】

     일부 수신기는 밀리초도 제공:

     "143025.123"
     └─┬─┘
     밀리초 (현재 미지원)

     현재는 초 단위까지만 파싱


     【예시】

     ```swift
     // 날짜 포함
     let date1 = parseDateTime(time: "143025", date: "150124")
     // Result: 2024-01-15 14:30:25 UTC

     // 날짜 없음 (baseDate 사용)
     baseDate = Date() // 2024-01-15 00:00:00
     let date2 = parseDateTime(time: "143025", date: nil)
     // Result: 2024-01-15 14:30:25 UTC

     // 밀리초 포함 (무시됨)
     let date3 = parseDateTime(time: "143025.456", date: "150124")
     // Result: 2024-01-15 14:30:25 UTC (밀리초 무시)
     ```

     ═════════════════════════════════════════════════════════════════════
     */

    /// @brief NMEA 시간과 날짜를 Date 객체로 변환
    /// @param time NMEA 시간 문자열 (HHMMSS 또는 HHMMSS.sss)
    /// @param date NMEA 날짜 문자열 (DDMMYY, 선택적)
    /// @return Date 객체 또는 nil (파싱 실패 시)
    /// @details
    /// NMEA 시간과 날짜를 Swift Date 객체로 변환합니다.
    ///
    /// ### 입력 형식:
    /// ```
    /// time: HHMMSS 또는 HHMMSS.sss
    ///       └┬┘└┬┘└┬┘
    ///        시 분 초
    ///
    /// date: DDMMYY (선택적)
    ///       └┬┘└┬┘└┬┘
    ///        일 월 년(2자리)
    /// ```
    ///
    /// ### 변환 과정:
    /// ```
    /// 예: time = "143025", date = "150124", baseDate = 2024-01-15
    ///
    /// Step 1: 시간 파싱
    ///   "143025" → 14:30:25
    ///
    /// Step 2: 날짜 파싱 (있으면)
    ///   "150124" → 2024-01-15
    ///
    /// Step 3: Date 객체 생성
    ///   2024-01-15 14:30:25 UTC
    /// ```
    ///
    /// ### baseDate 사용:
    /// NMEA 날짜가 없거나 부정확할 때 baseDate를 사용합니다.
    ///
    /// ### UTC 시간대:
    /// GPS는 항상 UTC (협정세계시) 사용합니다.
    private func parseDateTime(time: String, date: String?) -> Date? {
        // baseDate가 설정되어 있어야 함
        guard let baseDate = baseDate else { return nil }

        // Step 1: 시간 길이 확인
        // 최소 HHMMSS = 6자리
        guard time.count >= 6 else { return nil }

        // Step 2: 시간 파싱
        // "143025" → 14:30:25
        let hourString = String(time.prefix(2))           // "14"
        let minuteString = String(time.dropFirst(2).prefix(2))  // "30"
        let secondString = String(time.dropFirst(4).prefix(2))  // "25"

        // 문자열 → 정수 변환
        guard let hour = Int(hourString),
              let minute = Int(minuteString),
              let second = Int(secondString) else {
            return nil
        }

        // Step 3: 날짜 컴포넌트 초기화
        // baseDate에서 년/월/일 가져오기
        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)

        // Step 4: NMEA 날짜가 있으면 파싱
        if let date = date, date.count >= 6 {
            // "150124" → 2024-01-15
            let dayString = String(date.prefix(2))              // "15"
            let monthString = String(date.dropFirst(2).prefix(2))  // "01"
            let yearString = String(date.dropFirst(4).prefix(2))   // "24"

            // 문자열 → 정수 변환
            if let day = Int(dayString),
               let month = Int(monthString),
               let year = Int(yearString) {
                // 2자리 년도 → 4자리 년도
                // 24 → 2024
                components.year = 2000 + year
                components.month = month
                components.day = day
            }
        }

        // Step 5: 시간 컴포넌트 설정
        components.hour = hour
        components.minute = minute
        components.second = second

        // GPS는 항상 UTC
        components.timeZone = TimeZone(identifier: "UTC")

        // Step 6: Date 객체 생성
        return Calendar.current.date(from: components)
    }

    /*
     ─────────────────────────────────────────────────────────────────────
     createGPSPoint(from:)
     ─────────────────────────────────────────────────────────────────────

     【기능】

     NMEARecord → GPSPoint 변환


     【HDOP → horizontalAccuracy 변환】

     HDOP는 무차원 지표이고,
     horizontalAccuracy는 미터 단위입니다.

     대략적인 변환:
     horizontalAccuracy ≈ HDOP × 10 meters

     예:
     - HDOP 0.9 → accuracy ≈ 9m
     - HDOP 2.5 → accuracy ≈ 25m

     ⚠️ 실제로는 위성 신호 품질, 환경 등 많은 요인에 영향

     ─────────────────────────────────────────────────────────────────────
     */

    /// @brief NMEARecord를 GPSPoint로 변환
    /// @param record NMEARecord 구조체
    /// @return GPSPoint 객체 또는 nil
    /// @details
    /// NMEARecord를 GPSPoint로 변환합니다.
    ///
    /// ### HDOP → horizontalAccuracy 변환:
    /// ```
    /// horizontalAccuracy ≈ HDOP × 10 meters
    ///
    /// 예:
    /// - HDOP 0.9 → accuracy ≈ 9m
    /// - HDOP 2.5 → accuracy ≈ 25m
    /// ```
    private func createGPSPoint(from record: NMEARecord) -> GPSPoint? {
        return GPSPoint(
            timestamp: record.timestamp,
            latitude: record.latitude,
            longitude: record.longitude,
            altitude: record.altitude,
            speed: record.speed,
            heading: record.heading,
            horizontalAccuracy: record.hdop.map { $0 * 10 },  // HDOP → 대략적인 미터
            satelliteCount: record.satelliteCount
        )
    }
}

// MARK: - Supporting Types

/*
 ─────────────────────────────────────────────────────────────────────────
 NMEARecord 구조체
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 GPRMC와 GPGGA 파싱 결과를 임시 저장하는 내부 구조체입니다.


 【왜 GPSPoint를 직접 사용하지 않나요?】

 1. 유연성:
 - GPRMC: 속도/방향 있음, 고도 없음
 - GPGGA: 고도 있음, 속도/방향 없음
 - 모든 필드를 Optional로 처리

 2. 병합:
 - GPRMC로 NMEARecord 생성
 - GPGGA로 NMEARecord 생성
 - 두 개를 병합하여 GPSPoint 생성

 3. 내부 구현:
 - 외부에 노출되지 않음 (private)
 - GPSPoint는 public API용


 【필드 설명】

 - timestamp: 타임스탬프 (GPRMC/GPGGA 공통)
 - latitude: 위도 (GPRMC/GPGGA 공통)
 - longitude: 경도 (GPRMC/GPGGA 공통)
 - altitude: 고도 (GPGGA만)
 - speed: 속도 (GPRMC만)
 - heading: 진행 방향 (GPRMC만)
 - hdop: 정확도 지표 (GPGGA만)
 - satelliteCount: 위성 개수 (GPGGA만)

 ─────────────────────────────────────────────────────────────────────────
 */

/// @struct NMEARecord
/// @brief NMEA 파싱 결과 임시 저장 구조체
/// @details
/// GPRMC와 GPGGA 파싱 결과를 임시 저장하는 내부 구조체입니다.
///
/// ### 필드:
/// - timestamp: 타임스탬프 (GPRMC/GPGGA 공통)
/// - latitude: 위도 (GPRMC/GPGGA 공통)
/// - longitude: 경도 (GPRMC/GPGGA 공통)
/// - altitude: 고도 (GPGGA만)
/// - speed: 속도 (GPRMC만)
/// - heading: 진행 방향 (GPRMC만)
/// - hdop: 정확도 지표 (GPGGA만)
/// - satelliteCount: 위성 개수 (GPGGA만)
///
/// ### 왜 GPSPoint를 직접 사용하지 않나요?
/// 1. 유연성: GPRMC와 GPGGA의 필드가 다르므로 모든 필드를 Optional로 처리
/// 2. 병합: 두 문장을 병합하여 GPSPoint 생성
/// 3. 내부 구현: 외부에 노출되지 않음 (private)
private struct NMEARecord {
    /// @var timestamp
    /// @brief 타임스탬프
    let timestamp: Date

    /// @var latitude
    /// @brief 위도 (십진수 도)
    let latitude: Double

    /// @var longitude
    /// @brief 경도 (십진수 도)
    let longitude: Double

    /// @var altitude
    /// @brief 고도 (미터, GPGGA에서만 제공)
    let altitude: Double?

    /// @var speed
    /// @brief 속도 (km/h, GPRMC에서만 제공)
    let speed: Double?

    /// @var heading
    /// @brief 진행 방향 (도, GPRMC에서만 제공)
    let heading: Double?

    /// @var hdop
    /// @brief 수평 정밀도 저하 지표 (GPGGA에서만 제공)
    let hdop: Double?

    /// @var satelliteCount
    /// @brief 위성 개수 (GPGGA에서만 제공)
    let satelliteCount: Int?
}

// MARK: - Parser Errors

/*
 ─────────────────────────────────────────────────────────────────────────
 GPSParserError 열거형
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 GPS 파싱 중 발생할 수 있는 오류를 정의합니다.


 【오류 타입】

 1. invalidFormat:
 - NMEA 문장 형식이 잘못됨
 - 필드 개수 부족
 - $ 로 시작하지 않음

 2. invalidChecksum:
 - 체크섬 불일치 (현재 미구현)

 3. invalidCoordinate:
 - 좌표 파싱 실패
 - 위도/경도 범위 초과

 4. invalidTimestamp:
 - 시간/날짜 파싱 실패


 【현재 사용】

 현재는 nil을 반환하는 방식으로 오류 처리하므로
 이 열거형은 미래 확장용으로 정의되어 있습니다.

 throws를 사용하도록 변경하면 활용 가능:

 ```swift
 func parseGPRMC(_ sentence: String) throws -> NMEARecord {
 guard fields.count >= 10 else {
 throw GPSParserError.invalidFormat
 }
 // ...
 }
 ```

 ─────────────────────────────────────────────────────────────────────────
 */

/// @enum GPSParserError
/// @brief GPS 파서 에러 타입
/// @details
/// GPS 파싱 중 발생할 수 있는 오류를 정의합니다.
///
/// ### 오류 타입:
/// 1. invalidFormat: NMEA 문장 형식이 잘못됨
/// 2. invalidChecksum: 체크섬 불일치 (현재 미구현)
/// 3. invalidCoordinate: 좌표 파싱 실패
/// 4. invalidTimestamp: 시간/날짜 파싱 실패
enum GPSParserError: Error {
    /// @brief 형식 오류
    /// @details NMEA 문장 형식이 잘못되었거나 필드 개수가 부족합니다.
    case invalidFormat

    /// @brief 체크섬 오류
    /// @details 체크섬이 불일치합니다 (현재 미구현).
    case invalidChecksum

    /// @brief 좌표 오류
    /// @details 좌표 파싱에 실패했거나 범위를 초과했습니다.
    case invalidCoordinate

    /// @brief 타임스탬프 오류
    /// @details 시간/날짜 파싱에 실패했습니다.
    case invalidTimestamp
}

/*
 ─────────────────────────────────────────────────────────────────────────
 LocalizedError 확장
 ─────────────────────────────────────────────────────────────────────────

 【역할】

 사용자에게 읽기 쉬운 오류 메시지를 제공합니다.


 【사용 예시】

 ```swift
 do {
 let record = try parseGPRMC(sentence)
 } catch let error as GPSParserError {
 print(error.localizedDescription)
 // 출력: "Invalid NMEA format"
 }
 ```

 ─────────────────────────────────────────────────────────────────────────
 */

extension GPSParserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid NMEA format"
        case .invalidChecksum:
            return "Invalid NMEA checksum"
        case .invalidCoordinate:
            return "Invalid GPS coordinate"
        case .invalidTimestamp:
            return "Invalid timestamp"
        }
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 통합 사용 예시
 ═══════════════════════════════════════════════════════════════════════════

 【시나리오: 블랙박스 비디오에서 GPS 경로 추출】

 ```swift
 import Foundation
 import CoreLocation

 // Step 1: MP4 파일에서 NMEA 데이터 추출
 // (MetadataExtractor가 수행)
 let videoFile = "20240115_143025_F.mp4"
 let metadataExtractor = MetadataExtractor()
 let metadata = try metadataExtractor.extract(from: URL(fileURLWithPath: videoFile))

 // Step 2: baseDate 생성
 // 파일명에서 추출: "20240115_143025_F.mp4" → 2024-01-15
 let dateFormatter = DateFormatter()
 dateFormatter.dateFormat = "yyyyMMdd"
 let baseDate = dateFormatter.date(from: "20240115")!

 // Step 3: GPS 파싱
 let parser = GPSParser()
 let gpsPoints = parser.parseNMEA(data: metadata.gpsData, baseDate: baseDate)

 print("총 GPS 포인트: \(gpsPoints.count)개")

 // Step 4: 경로 분석
 if let firstPoint = gpsPoints.first, let lastPoint = gpsPoints.last {
 print("\n출발지:")
 print("  위치: \(firstPoint.latitude), \(firstPoint.longitude)")
 print("  시간: \(firstPoint.timestamp)")

 print("\n도착지:")
 print("  위치: \(lastPoint.latitude), \(lastPoint.longitude)")
 print("  시간: \(lastPoint.timestamp)")

 // 거리 계산
 let start = CLLocation(
 latitude: firstPoint.latitude,
 longitude: firstPoint.longitude
 )
 let end = CLLocation(
 latitude: lastPoint.latitude,
 longitude: lastPoint.longitude
 )
 let distance = start.distance(from: end) / 1000.0  // km
 print("  이동 거리: \(String(format: "%.2f", distance)) km")
 }

 // Step 5: 속도 분석
 let speeds = gpsPoints.compactMap { $0.speed }
 if !speeds.isEmpty {
 let avgSpeed = speeds.reduce(0, +) / Double(speeds.count)
 let maxSpeed = speeds.max() ?? 0

 print("\n속도 분석:")
 print("  평균 속도: \(String(format: "%.1f", avgSpeed)) km/h")
 print("  최고 속도: \(String(format: "%.1f", maxSpeed)) km/h")
 }

 // Step 6: 위성 정확도 분석
 let accuracies = gpsPoints.compactMap { $0.horizontalAccuracy }
 if !accuracies.isEmpty {
 let avgAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)

 print("\n정확도 분석:")
 print("  평균 오차: \(String(format: "%.1f", avgAccuracy))m")
 }

 // Step 7: 지도에 경로 표시
 let coordinates = gpsPoints.map {
 CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
 }
 // MapView에서 polyline으로 표시...
 ```


 【출력 예시】

 총 GPS 포인트: 3600개

 출발지:
 위치: 37.7354, 127.0761
 시간: 2024-01-15 14:30:25 +0000

 도착지:
 위치: 37.5665, 126.9780
 시간: 2024-01-15 15:00:25 +0000
 이동 거리: 24.53 km

 속도 분석:
 평균 속도: 49.1 km/h
 최고 속도: 83.7 km/h

 정확도 분석:
 평균 오차: 12.3m

 ═══════════════════════════════════════════════════════════════════════════
 */
