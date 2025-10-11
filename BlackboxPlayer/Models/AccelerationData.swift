//
//  AccelerationData.swift
//  BlackboxPlayer
//
//  Model for G-Sensor (accelerometer) data
//

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                   AccelerationData 모델 개요                             │
 │                                                                          │
 │  블랙박스의 G-센서(가속도계)가 측정한 가속도 데이터 포인트입니다.        │
 │                                                                          │
 │  【3축 가속도】                                                          │
 │                                                                          │
 │                    Z (Vertical)                                          │
 │                      ↑                                                   │
 │                      │                                                   │
 │                      │                                                   │
 │       Y (Forward) ───┼─── X (Lateral)                                   │
 │                    / │                                                   │
 │                   /  │                                                   │
 │                  ↙   ↓                                                   │
 │                                                                          │
 │  X축 (Lateral/좌우):                                                     │
 │    - 양수 (+): 우측으로 가속 (우회전, 우측 충격)                         │
 │    - 음수 (-): 좌측으로 가속 (좌회전, 좌측 충격)                         │
 │                                                                          │
 │  Y축 (Longitudinal/전후):                                                │
 │    - 양수 (+): 전방으로 가속 (가속, 후방 충격)                           │
 │    - 음수 (-): 후방으로 가속 (제동, 전방 충격)                           │
 │                                                                          │
 │  Z축 (Vertical/상하):                                                    │
 │    - 양수 (+): 위로 가속 (점프, 하방 충격)                               │
 │    - 음수 (-): 아래로 가속 (낙하, 상방 충격)                             │
 │    - 정상 주행: 약 1.0G (중력)                                           │
 │                                                                          │
 │  【충격 강도 분류】                                                      │
 │                                                                          │
 │  총 가속도 크기 = √(x² + y² + z²)                                        │
 │                                                                          │
 │  - None:     < 1.0G  (정상 주행)         Green                          │
 │  - Low:      1.0-1.5G (경미한 가속)      Light Green                     │
 │  - Moderate: 1.5-2.5G (유의미한 가속)    Amber                           │
 │  - High:     2.5-4.0G (충격/사고)        Orange                          │
 │  - Severe:   > 4.0G   (심각한 충격)      Red                             │
 │                                                                          │
 │  【데이터 소스】                                                         │
 │                                                                          │
 │  블랙박스 SD 카드                                                        │
 │      │                                                                   │
 │      ├─ 20250115_100000_F.mp4 (비디오)                                  │
 │      └─ 20250115_100000.gsn (G-센서 데이터)                              │
 │           │                                                              │
 │           ├─ 타임스탬프                                                  │
 │           ├─ X축 가속도 (G)                                              │
 │           ├─ Y축 가속도 (G)                                              │
 │           └─ Z축 가속도 (G)                                              │
 │                │                                                         │
 │                ▼                                                         │
 │           AccelerationParser                                             │
 │                │                                                         │
 │                ▼                                                         │
 │           AccelerationData (이 구조체)                                   │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【G-센서(가속도계)란?】

 차량의 가속도를 3축으로 측정하는 센서입니다.

 원리:
 - MEMS (Micro-Electro-Mechanical Systems) 기술
 - 미세한 질량체의 움직임 감지
 - 전기 신호로 변환

 블랙박스에서의 역할:
 1. 충격 감지: 사고 발생 시 이벤트 녹화 트리거
 2. 주차 모드: 정차 중 충격 감지
 3. 급제동/급가속 경고
 4. 운전 습관 분석

 측정 단위: G (중력 가속도)
 - 1G = 9.8 m/s² (지구 중력)
 - 예: 2G = 19.6 m/s² (중력의 2배)

 【G-Force (G-force)란?】

 G는 중력 가속도를 기준으로 한 가속도 단위입니다.

 참고 수치:
 - 0G: 무중력 상태 (우주)
 - 1G: 정지 상태 (지구 표면)
 - 2G: 급제동, 빠른 회전
 - 3-4G: 경미한 충돌
 - 5-10G: 심각한 충돌
 - >15G: 치명적 충돌

 일상 예시:
 - 엘리베이터 출발: 약 1.2G
 - 롤러코스터: 3-5G
 - 전투기 기동: 9G
 - 자동차 급제동: 0.8-1.5G
 - 자동차 충돌: 20-100G (순간적)

 【벡터 크기 계산】

 3축 가속도를 하나의 값으로 표현하려면 벡터 크기를 계산합니다.

 수학 공식:
 ```
 magnitude = √(x² + y² + z²)
 ```

 예시:
 ```swift
 // 급제동 (Y축 -1.8G)
 x = 0.0
 y = -1.8
 z = 1.0 (중력)

 magnitude = √(0² + (-1.8)² + 1²)
           = √(0 + 3.24 + 1)
           = √4.24
           = 2.06G
 ```

 왜 제곱근인가?:
 - 피타고라스 정리의 3D 확장
 - 2D: √(x² + y²)
 - 3D: √(x² + y² + z²)

 【방향 감지 알고리즘】

 가장 큰 절댓값을 가진 축이 주요 충격 방향입니다.

 알고리즘:
 ```
 1. |x|, |y|, |z| 계산
 2. 최댓값 찾기
 3. 해당 축의 부호 확인
    - x > 0: 우측
    - x < 0: 좌측
    - y > 0: 전방
    - y < 0: 후방
    - z > 0: 상방
    - z < 0: 하방
 ```

 예시:
 ```swift
 x = 1.5  (우측)
 y = -3.5 (후방, 즉 전방 충격)
 z = 0.8  (상방)

 |x| = 1.5
 |y| = 3.5  ← 최대!
 |z| = 0.8

 y < 0이므로 → backward (제동/전방 충격)
 ```
 */

import Foundation

/*
 【AccelerationData 구조체】

 블랙박스의 G-센서가 측정한 3축 가속도 데이터 포인트입니다.

 데이터 구조:
 - 값 타입 (struct) - 불변성과 스레드 안전성
 - Codable - JSON 직렬화/역직렬화
 - Equatable - 비교 연산 (==, !=)
 - Hashable - Set, Dictionary 키로 사용 가능
 - Identifiable - SwiftUI List에서 사용

 사용 예시:
 ```swift
 // 1. G-센서 데이터 파싱
 let parser = AccelerationParser()
 let dataPoints = try parser.parseAccelerationData(from: gsnFileURL)

 // 2. 충격 감지
 for data in dataPoints {
     if data.isImpact {
         print("충격 감지: \(data.magnitudeString)")
         print("방향: \(data.primaryDirection.displayName)")
         print("강도: \(data.impactSeverity.displayName)")
     }
 }

 // 3. 차트 시각화
 Chart(dataPoints) { point in
     LineMark(x: .value("Time", point.timestamp),
              y: .value("G-Force", point.magnitude))
 }
 ```
 */
/// G-Sensor acceleration data point from dashcam recording
struct AccelerationData: Codable, Equatable, Hashable {
    /*
     【타임스탬프 (Timestamp)】

     이 가속도 측정이 이루어진 시각입니다.

     타입: Date
     - UTC 기준 (협정 세계시)
     - 비디오 프레임과 동기화

     용도:
     - 비디오 재생 시 해당 시점의 가속도 표시
     - 시간 기반 차트 그리기
     - GPS 데이터와 시간 동기화
     */
    /// Timestamp of this reading
    let timestamp: Date

    /*
     【X축 가속도 (Lateral)】

     좌우 방향의 가속도를 G-force 단위로 나타냅니다.

     방향:
     - 양수 (+): 우측으로 가속
       * 좌회전 시 원심력으로 우측으로 쏠림
       * 좌측에서 충격 받음 (우측으로 밀림)
     - 음수 (-): 좌측으로 가속
       * 우회전 시 원심력으로 좌측으로 쏠림
       * 우측에서 충격 받음 (좌측으로 밀림)

     예시 값:
     - 0.0G: 직진
     - +0.5G: 완만한 좌회전
     - -1.2G: 급한 우회전
     - +2.0G: 좌측 충격

     사용:
     ```swift
     if data.x > 1.5 {
         print("강한 좌회전 또는 좌측 충격")
     } else if data.x < -1.5 {
         print("강한 우회전 또는 우측 충격")
     }
     ```
     */
    /// X-axis acceleration in G-force (lateral/side-to-side)
    /// Positive: right, Negative: left
    let x: Double

    /*
     【Y축 가속도 (Longitudinal)】

     전후 방향의 가속도를 G-force 단위로 나타냅니다.

     방향:
     - 양수 (+): 전방으로 가속
       * 가속 페달 밟음
       * 후방에서 충격 받음 (전방으로 밀림)
     - 음수 (-): 후방으로 가속
       * 브레이크 밟음 (제동)
       * 전방에서 충격 받음 (후방으로 밀림)

     예시 값:
     - 0.0G: 등속 주행
     - +0.8G: 일반 가속
     - -1.5G: 급제동
     - -3.0G: 전방 충돌

     사용:
     ```swift
     if data.y < -2.0 {
         print("급제동 또는 전방 충돌!")
         triggerEventRecording()
     } else if data.y > 1.5 {
         print("급가속 또는 후방 충돌")
     }
     ```

     주의:
     - 블랙박스마다 Y축 방향 정의가 다를 수 있음
     - 일부는 양/음 부호가 반대
     */
    /// Y-axis acceleration in G-force (longitudinal/forward-backward)
    /// Positive: forward, Negative: backward
    let y: Double

    /*
     【Z축 가속도 (Vertical)】

     상하 방향의 가속도를 G-force 단위로 나타냅니다.

     방향:
     - 양수 (+): 위로 가속
       * 포트홀에서 튀어 오름
       * 과속방지턱 넘음
       * 하방에서 충격 (위로 밀림)
     - 음수 (-): 아래로 가속
       * 급격한 낙하
       * 점프 후 착지

     정상 주행: 약 1.0G
     - 중력에 의한 가속도
     - 평지 주행 시 Z ≈ 1.0G

     예시 값:
     - 1.0G: 평지 주행 (중력)
     - 1.5G: 작은 요철 통과
     - 2.0G: 큰 포트홀
     - 0.5G: 하강 또는 점프

     사용:
     ```swift
     let verticalDeviation = abs(data.z - 1.0)
     if verticalDeviation > 0.5 {
         print("노면 상태 불량 또는 충격")
     }

     if data.z > 2.0 {
         print("과속방지턱 또는 포트홀")
     }
     ```

     왜 1.0G인가?:
     - 지구 중력 = 1G = 9.8 m/s²
     - 정지 상태에서도 Z축은 1G 측정
     */
    /// Z-axis acceleration in G-force (vertical/up-down)
    /// Positive: up, Negative: down
    let z: Double

    // MARK: - Initialization

    /*
     【초기화 메서드】

     AccelerationData 인스턴스를 생성합니다.

     매개변수:
     - timestamp: 측정 시각
     - x: X축 가속도 (좌우)
     - y: Y축 가속도 (전후)
     - z: Z축 가속도 (상하)

     사용 예시:
     ```swift
     // 1. 정상 주행 (중력만)
     let normal = AccelerationData(
         timestamp: Date(),
         x: 0.0,
         y: 0.0,
         z: 1.0  // 중력
     )

     // 2. 급제동
     let braking = AccelerationData(
         timestamp: Date(),
         x: 0.0,
         y: -1.8,  // 후방으로 가속 (제동)
         z: 1.0
     )

     // 3. 충돌
     let impact = AccelerationData(
         timestamp: Date(),
         x: 1.5,   // 우측으로 밀림
         y: -3.5,  // 후방으로 밀림 (전방 충격)
         z: 0.8    // 약간 하방으로
     )

     // 4. 파싱 중 생성
     let data = AccelerationData(
         timestamp: baseDate.addingTimeInterval(timeOffset),
         x: parsedX,
         y: parsedY,
         z: parsedZ
     )
     ```
     */
    init(timestamp: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }

    // MARK: - Calculations

    /*
     【총 가속도 크기 (Magnitude)】

     3축 가속도의 벡터 크기를 계산합니다.

     수학 공식:
     ```
     magnitude = √(x² + y² + z²)
     ```

     반환값:
     - Double: 총 가속도 (G 단위)

     계산 예시:
     ```
     x = 1.5
     y = -3.5
     z = 0.8

     magnitude = √(1.5² + (-3.5)² + 0.8²)
               = √(2.25 + 12.25 + 0.64)
               = √15.14
               = 3.89G
     ```

     사용 예시:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     let mag = data.magnitude  // 3.89

     if mag > 2.5 {
         print("충격 감지! \(mag)G")
         triggerEventRecording()
     }

     // 차트에 표시
     Chart(dataPoints) { point in
         LineMark(
             x: .value("Time", point.timestamp),
             y: .value("G-Force", point.magnitude)
         )
     }
     ```

     왜 벡터 크기를 사용하는가?:
     - 방향 무관한 총 가속도
     - 충격 강도 판단에 유용
     - 단일 임계값으로 판단 가능
     */
    /// Total acceleration magnitude (vector length)
    var magnitude: Double {
        return sqrt(x * x + y * y + z * z)  // √(x² + y² + z²)
    }

    /*
     【수평면 가속도 크기 (Lateral Magnitude)】

     X-Y 평면의 가속도 크기를 계산합니다 (Z축 제외).

     수학 공식:
     ```
     lateralMagnitude = √(x² + y²)
     ```

     반환값:
     - Double: 수평면 가속도 (G 단위)

     용도:
     - 주행 패턴 분석 (상하 움직임 제외)
     - 회전/제동 강도 측정
     - 노면 상태 영향 최소화

     계산 예시:
     ```
     x = 2.0  (좌회전)
     y = -1.5 (제동)
     z = 1.2  (노면 요철)

     lateralMagnitude = √(2.0² + (-1.5)²)
                      = √(4.0 + 2.25)
                      = √6.25
                      = 2.5G

     magnitude = √(2.0² + (-1.5)² + 1.2²) = 2.74G
     ```

     사용 예시:
     ```swift
     let lateral = data.lateralMagnitude

     // 주행 패턴 분석
     if lateral > 1.5 {
         print("급격한 조향 또는 제동")
     }

     // 운전 습관 점수 (Z축 노면 영향 제외)
     let drivingScore = 100 - (lateral * 10)
     ```
     */
    /// Lateral acceleration magnitude (X-Y plane)
    var lateralMagnitude: Double {
        return sqrt(x * x + y * y)  // √(x² + y²)
    }

    /*
     【유의미한 가속도 확인】

     총 가속도가 1.5G를 초과하는지 확인합니다.

     임계값: 1.5G
     - 일반 주행: < 1.5G
     - 유의미한 가속: > 1.5G

     반환값:
     - Bool: 1.5G 초과 시 true

     사용 예시:
     ```swift
     if data.isSignificant {
         print("유의미한 가속도 감지: \(data.magnitudeString)")
         highlightOnChart()
     }

     // 유의미한 데이터만 필터링
     let significantEvents = allData.filter { $0.isSignificant }
     print("총 \(significantEvents.count)개의 유의미한 이벤트")
     ```

     왜 1.5G인가?:
     - 일반 운전: 0.5-1.2G
     - 급한 조작: 1.2-1.5G
     - 비정상 상황: > 1.5G
     */
    /// Check if this reading indicates significant acceleration
    /// Threshold: > 1.5 G-force
    var isSignificant: Bool {
        return magnitude > 1.5
    }

    /*
     【충격 여부 확인】

     총 가속도가 2.5G를 초과하는지 확인합니다 (충격/사고).

     임계값: 2.5G
     - 일반 주행: < 2.5G
     - 충격/사고: > 2.5G

     반환값:
     - Bool: 2.5G 초과 시 true

     사용 예시:
     ```swift
     if data.isImpact {
         print("⚠️ 충격 감지! \(data.magnitudeString)")
         print("방향: \(data.primaryDirection.displayName)")

         // 이벤트 녹화 트리거
         triggerEventRecording(before: 10, after: 20)

         // 알림 전송
         sendEmergencyNotification()

         // 파일 보호 (자동 삭제 방지)
         protectCurrentRecording()
     }

     // 충격 이벤트만 표시
     let impacts = allData.filter { $0.isImpact }
     print("충격 이벤트: \(impacts.count)개")
     ```

     실제 예시:
     - 급제동: 약 1.5-2.0G (충격 아님)
     - 경미한 접촉: 2.5-3.5G (충격)
     - 중간 충돌: 3.5-5.0G (충격)
     - 심각한 충돌: > 5.0G (심각한 충격)
     */
    /// Check if this reading indicates an impact/collision
    /// Threshold: > 2.5 G-force
    var isImpact: Bool {
        return magnitude > 2.5
    }

    /*
     【심각한 충격 확인】

     총 가속도가 4.0G를 초과하는지 확인합니다 (심각한 충격).

     임계값: 4.0G
     - 일반 충격: 2.5-4.0G
     - 심각한 충격: > 4.0G

     반환값:
     - Bool: 4.0G 초과 시 true

     사용 예시:
     ```swift
     if data.isSevereImpact {
         print("🚨 심각한 충격 감지! \(data.magnitudeString)")

         // 긴급 조치
         triggerEmergencyMode()

         // 자동으로 119 연결 (일부 블랙박스)
         callEmergencyServices()

         // 비상 연락처에 SMS 전송
         sendEmergencySMS(location: currentGPS)

         // 에어백 전개 가능성
         if data.magnitude > 10.0 {
             print("⚠️ 에어백 전개 수준의 충격")
         }
     }
     ```

     실제 시나리오:
     - 4-6G: 중간 속도 충돌
     - 6-10G: 고속 충돌
     - >10G: 매우 심각한 충돌
     - >20G: 치명적 충돌 (순간적)
     */
    /// Check if this reading indicates a severe impact
    /// Threshold: > 4.0 G-force
    var isSevereImpact: Bool {
        return magnitude > 4.0
    }

    /*
     【충격 강도 분류】

     총 가속도 크기에 따라 충격 강도를 5단계로 분류합니다.

     분류 기준:
     - None:     < 1.0G  (정상 주행)
     - Low:      1.0-1.5G (경미한 가속)
     - Moderate: 1.5-2.5G (유의미한 가속)
     - High:     2.5-4.0G (충격)
     - Severe:   > 4.0G   (심각한 충격)

     반환값:
     - ImpactSeverity: 충격 강도 열거형

     사용 예시:
     ```swift
     let severity = data.impactSeverity

     switch severity {
     case .none:
         statusLabel.text = "정상"
         statusLabel.textColor = .systemGreen
     case .low:
         statusLabel.text = "경미"
         statusLabel.textColor = .systemYellow
     case .moderate:
         statusLabel.text = "주의"
         statusLabel.textColor = .systemOrange
     case .high:
         statusLabel.text = "충격"
         statusLabel.textColor = .systemRed
         triggerEventRecording()
     case .severe:
         statusLabel.text = "심각"
         statusLabel.textColor = .systemRed
         triggerEmergencyMode()
     }

     // UI 색상 적용
     circle.fill(Color(hex: severity.colorHex))

     // 필터링
     let severeImpacts = allData.filter { $0.impactSeverity == .severe }
     ```

     색상 코드:
     - None: Green (#4CAF50)
     - Low: Light Green (#8BC34A)
     - Moderate: Amber (#FFC107)
     - High: Orange (#FF9800)
     - Severe: Red (#F44336)
     */
    /// Classify the impact severity
    var impactSeverity: ImpactSeverity {
        let mag = magnitude  // 총 가속도 크기

        if mag > 4.0 {
            return .severe  // 심각 (> 4.0G)
        } else if mag > 2.5 {
            return .high  // 높음 (2.5-4.0G)
        } else if mag > 1.5 {
            return .moderate  // 중간 (1.5-2.5G)
        } else if mag > 1.0 {
            return .low  // 낮음 (1.0-1.5G)
        } else {
            return .none  // 없음 (< 1.0G)
        }
    }

    /*
     【주요 충격 방향 판단】

     가장 큰 절댓값을 가진 축을 기준으로 충격 방향을 판단합니다.

     알고리즘:
     1. |x|, |y|, |z| 계산
     2. 최댓값 찾기
     3. 해당 축의 부호 확인

     반환값:
     - ImpactDirection: 충격 방향 열거형

     사용 예시:
     ```swift
     let direction = data.primaryDirection

     print("주요 충격 방향: \(direction.displayName)")
     // "Forward", "Backward", "Left", "Right", "Up", "Down"

     // 아이콘 표시
     let icon = Image(systemName: direction.iconName)
     // arrow.up, arrow.down, arrow.left, arrow.right, etc.

     // 방향별 처리
     switch direction {
     case .forward:
         print("전방 가속 또는 후방 충격")
     case .backward:
         print("제동 또는 전방 충격")
     case .left:
         print("우회전 또는 우측 충격")
     case .right:
         print("좌회전 또는 좌측 충격")
     case .up:
         print("포트홀 또는 하방 충격")
     case .down:
         print("낙하 또는 상방 충격")
     }

     // UI 화살표 회전
     arrowView.transform = CGAffineTransform(rotationAngle: direction.angle)
     ```

     예시 계산:
     ```
     x = 1.5, y = -3.5, z = 0.8

     |x| = 1.5
     |y| = 3.5  ← 최대!
     |z| = 0.8

     y < 0 → backward (제동/전방 충격)
     ```
     */
    /// Determine primary impact direction
    var primaryDirection: ImpactDirection {
        let absX = abs(x)  // X축 절댓값
        let absY = abs(y)  // Y축 절댓값
        let absZ = abs(z)  // Z축 절댓값

        let maxValue = max(absX, absY, absZ)  // 최댓값 찾기

        // 최댓값에 해당하는 축의 방향 반환
        if maxValue == absX {
            return x > 0 ? .right : .left  // X축이 최대
        } else if maxValue == absY {
            return y > 0 ? .forward : .backward  // Y축이 최대
        } else {
            return z > 0 ? .up : .down  // Z축이 최대
        }
    }

    // MARK: - Formatting

    /*
     【가속도 문자열 포맷】

     X, Y, Z 축의 가속도를 읽기 쉬운 문자열로 변환합니다.

     형식: "X: XXX.XXG, Y: XXX.XXG, Z: XXX.XXG"

     반환값:
     - String: 포맷된 3축 가속도 문자열

     사용 예시:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     print(data.formattedString)
     // "X: 1.50G, Y: -3.50G, Z: 0.80G"

     // UI 레이블
     detailLabel.text = data.formattedString

     // 로그 출력
     print("[\(data.timestamp)] \(data.formattedString)")

     // 데이터 내보내기
     let csv = "\(data.timestamp),\(data.formattedString)"
     ```

     형식 설명:
     - %.2f: 소수점 2자리
     - G: G-force 단위 표시
     */
    /// Format acceleration as string with G-force units
    var formattedString: String {
        return String(format: "X: %.2fG, Y: %.2fG, Z: %.2fG", x, y, z)
    }

    /*
     【총 가속도 크기 문자열】

     벡터 크기를 읽기 쉬운 문자열로 변환합니다.

     형식: "XXX.XX G"

     반환값:
     - String: 포맷된 총 가속도 문자열

     사용 예시:
     ```swift
     let data = AccelerationData(timestamp: Date(), x: 1.5, y: -3.5, z: 0.8)
     print(data.magnitudeString)
     // "3.89 G"

     // 차트 레이블
     Text(data.magnitudeString)
         .font(.caption)

     // 알림 메시지
     if data.isImpact {
         showAlert(title: "충격 감지", message: "강도: \(data.magnitudeString)")
     }

     // 통계
     let maxG = allData.map { $0.magnitude }.max() ?? 0
     print("최대 가속도: \(String(format: "%.2f G", maxG))")
     ```
     */
    /// Format magnitude as string
    var magnitudeString: String {
        return String(format: "%.2f G", magnitude)
    }
}

// MARK: - Supporting Types

/*
 【ImpactSeverity 열거형】

 충격 강도를 5단계로 분류하는 열거형입니다.

 프로토콜:
 - String: Raw Value로 문자열 사용
 - Codable: JSON 직렬화

 단계:
 - none: 정상 주행 (< 1.0G)
 - low: 경미 (1.0-1.5G)
 - moderate: 중간 (1.5-2.5G)
 - high: 높음 (2.5-4.0G)
 - severe: 심각 (> 4.0G)
 */
/// Impact severity classification
enum ImpactSeverity: String, Codable {
    case none = "none"          // 정상 주행
    case low = "low"            // 경미한 가속
    case moderate = "moderate"  // 유의미한 가속
    case high = "high"          // 충격
    case severe = "severe"      // 심각한 충격

    /*
     【표시 이름】

     첫 글자를 대문자로 변환한 이름을 반환합니다.

     반환값:
     - String: "None", "Low", "Moderate", "High", "Severe"

     사용 예시:
     ```swift
     let severity = ImpactSeverity.high
     print(severity.displayName)  // "High"

     // UI 레이블
     severityLabel.text = severity.displayName
     ```
     */
    var displayName: String {
        return rawValue.capitalized  // 첫 글자 대문자
    }

    /*
     【색상 코드】

     충격 강도에 해당하는 색상 코드를 반환합니다.

     색상:
     - None: Green (#4CAF50) - 안전
     - Low: Light Green (#8BC34A) - 경미
     - Moderate: Amber (#FFC107) - 주의
     - High: Orange (#FF9800) - 위험
     - Severe: Red (#F44336) - 심각

     반환값:
     - String: Hex 색상 코드

     사용 예시:
     ```swift
     let severity = data.impactSeverity
     let color = Color(hex: severity.colorHex)

     Circle()
         .fill(color)
         .frame(width: 50, height: 50)

     // 차트 색상
     LineMark(...)
         .foregroundStyle(Color(hex: severity.colorHex))
     ```
     */
    var colorHex: String {
        switch self {
        case .none:
            return "#4CAF50"  // Green - 안전
        case .low:
            return "#8BC34A"  // Light Green - 경미
        case .moderate:
            return "#FFC107"  // Amber - 주의
        case .high:
            return "#FF9800"  // Orange - 위험
        case .severe:
            return "#F44336"  // Red - 심각
        }
    }
}

/*
 【ImpactDirection 열거형】

 충격 방향을 6방향으로 분류하는 열거형입니다.

 프로토콜:
 - String: Raw Value로 문자열 사용
 - Codable: JSON 직렬화

 방향:
 - forward: 전방 (Y+)
 - backward: 후방 (Y-)
 - left: 좌측 (X-)
 - right: 우측 (X+)
 - up: 상방 (Z+)
 - down: 하방 (Z-)
 */
/// Impact direction
enum ImpactDirection: String, Codable {
    case forward = "forward"    // 전방 가속 / 후방 충격
    case backward = "backward"  // 제동 / 전방 충격
    case left = "left"          // 좌측 가속 / 우측 충격
    case right = "right"        // 우측 가속 / 좌측 충격
    case up = "up"              // 상방 가속 / 하방 충격
    case down = "down"          // 하방 가속 / 상방 충격

    /*
     【표시 이름】

     첫 글자를 대문자로 변환한 이름을 반환합니다.

     반환값:
     - String: "Forward", "Backward", "Left", "Right", "Up", "Down"
     */
    var displayName: String {
        return rawValue.capitalized  // 첫 글자 대문자
    }

    /*
     【아이콘 이름】

     SF Symbols 아이콘 이름을 반환합니다.

     반환값:
     - String: SF Symbols 이름

     아이콘:
     - Forward: arrow.up
     - Backward: arrow.down
     - Left: arrow.left
     - Right: arrow.right
     - Up: arrow.up.circle
     - Down: arrow.down.circle

     사용 예시:
     ```swift
     let direction = data.primaryDirection

     // SwiftUI
     Image(systemName: direction.iconName)
         .font(.largeTitle)

     // UIKit
     let image = UIImage(systemName: direction.iconName)
     imageView.image = image
     ```
     */
    var iconName: String {
        switch self {
        case .forward:
            return "arrow.up"           // ↑
        case .backward:
            return "arrow.down"         // ↓
        case .left:
            return "arrow.left"         // ←
        case .right:
            return "arrow.right"        // →
        case .up:
            return "arrow.up.circle"    // ⊙↑
        case .down:
            return "arrow.down.circle"  // ⊙↓
        }
    }
}

// MARK: - Identifiable

/*
 【Identifiable 프로토콜 확장】

 SwiftUI의 List, ForEach 등에서 사용할 수 있도록 고유 식별자를 제공합니다.

 사용 예시:
 ```swift
 List(accelerationData) { point in
     HStack {
         Text(point.magnitudeString)
         Spacer()
         Circle()
             .fill(Color(hex: point.impactSeverity.colorHex))
             .frame(width: 20, height: 20)
     }
 }
 ```
 */
extension AccelerationData: Identifiable {
    var id: Date { timestamp }  // timestamp를 고유 식별자로 사용
}

// MARK: - Sample Data

/*
 【샘플 데이터 확장】

 테스트와 SwiftUI 프리뷰를 위한 샘플 가속도 데이터를 제공합니다.

 시나리오:
 - normal: 정상 주행
 - braking: 급제동
 - sharpTurn: 급회전
 - impact: 충격
 - severeImpact: 심각한 충격
 */
extension AccelerationData {
    /*
     【정상 주행】

     중력(1G)만 작용하는 평지 주행 상태입니다.

     값:
     - X: 0.0G (좌우 없음)
     - Y: 0.0G (전후 없음)
     - Z: 1.0G (중력)
     */
    /// Normal driving (minimal acceleration)
    static let normal = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: 0.0,
        z: 1.0  // Gravity (중력)
    )

    /*
     【급제동】

     후방으로 1.8G 가속 (제동).

     값:
     - X: 0.0G (좌우 없음)
     - Y: -1.8G (제동)
     - Z: 1.0G (중력)

     총 가속도: √(0² + 1.8² + 1²) = 2.06G (Moderate)
     */
    /// Moderate braking
    static let braking = AccelerationData(
        timestamp: Date(),
        x: 0.0,
        y: -1.8,  // 제동
        z: 1.0
    )

    /*
     【급회전】

     우측으로 2.2G + 약간의 전방 가속.

     값:
     - X: 2.2G (우측, 좌회전)
     - Y: 0.5G (전방 가속)
     - Z: 1.0G (중력)

     총 가속도: √(2.2² + 0.5² + 1²) = 2.44G (Moderate)
     */
    /// Sharp turn
    static let sharpTurn = AccelerationData(
        timestamp: Date(),
        x: 2.2,   // 우측 (좌회전)
        y: 0.5,   // 약간 가속
        z: 1.0
    )

    /*
     【충격 이벤트】

     전방 충돌 시나리오.

     값:
     - X: 1.5G (우측으로 밀림)
     - Y: -3.5G (후방으로 밀림, 전방 충격)
     - Z: 0.8G (약간 하방)

     총 가속도: √(1.5² + 3.5² + 0.8²) = 3.89G (High)
     방향: Backward (Y축이 최대, 음수)
     */
    /// Impact event
    static let impact = AccelerationData(
        timestamp: Date(),
        x: 1.5,   // 우측
        y: -3.5,  // 전방 충격
        z: 0.8    // 약간 하방
    )

    /*
     【심각한 충격】

     심각한 전방 충돌 시나리오.

     값:
     - X: 2.8G (우측으로 강하게 밀림)
     - Y: -5.2G (후방으로 강하게 밀림)
     - Z: 1.5G (위로 튕김)

     총 가속도: √(2.8² + 5.2² + 1.5²) = 6.08G (Severe)
     */
    /// Severe impact
    static let severeImpact = AccelerationData(
        timestamp: Date(),
        x: 2.8,   // 우측으로 강하게
        y: -5.2,  // 심각한 전방 충격
        z: 1.5    // 위로 튕김
    )

    /*
     【샘플 데이터 배열】

     정상 주행부터 충격까지의 시나리오가 포함된 배열입니다.

     사용 예시:
     ```swift
     // 차트 프리뷰
     Chart(AccelerationData.sampleData) { point in
         LineMark(
             x: .value("Time", point.timestamp),
             y: .value("G-Force", point.magnitude)
         )
     }

     // 테스트
     func testImpactDetection() {
         let sample = AccelerationData.sampleData
         let impacts = sample.filter { $0.isImpact }
         XCTAssertEqual(impacts.count, 1)
     }
     ```
     */
    /// Array of sample data points
    static let sampleData: [AccelerationData] = [
        normal,
        AccelerationData(timestamp: Date().addingTimeInterval(1), x: 0.2, y: 0.5, z: 1.0),
        AccelerationData(timestamp: Date().addingTimeInterval(2), x: -0.3, y: 1.2, z: 1.0),
        braking,
        AccelerationData(timestamp: Date().addingTimeInterval(4), x: 0.1, y: 0.3, z: 1.0),
        sharpTurn,
        impact
    ]
}
