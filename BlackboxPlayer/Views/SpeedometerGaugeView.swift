/// @file SpeedometerGaugeView.swift
/// @brief 시각적 속도계 게이지 뷰
/// @author BlackboxPlayer Development Team
/// @details
/// 원형 또는 반원형 속도계 게이지를 표시하는 SwiftUI 뷰입니다.
/// 속도에 따라 색상이 변하고 애니메이션 효과가 있습니다.

import SwiftUI

/// @struct SpeedometerGaugeView
/// @brief 시각적 속도계 게이지
///
/// @details
/// ## 기능
/// - 반원형 게이지 (0° ~ 180°)
/// - 속도 범위: 0 ~ 200 km/h
/// - 색상 코딩: 저속(녹색) → 중속(노란색) → 고속(주황색) → 과속(빨간색)
/// - 부드러운 애니메이션
///
/// ## 속도 범위별 색상
/// ```
/// 0-60 km/h   → 녹색   (도심 주행)
/// 60-100 km/h → 노란색 (일반 도로)
/// 100-140 km/h → 주황색 (고속 도로)
/// 140+ km/h   → 빨간색 (과속)
/// ```
///
/// ## 사용 예제
/// ```swift
/// SpeedometerGaugeView(speed: 85.0)
///     .frame(width: 160, height: 100)
/// ```
struct SpeedometerGaugeView: View {
    // MARK: - Properties

    /// @var speed
    /// @brief 현재 속도 (km/h)
    let speed: Double

    /// @var maxSpeed
    /// @brief 최대 속도 (기본 200 km/h)
    let maxSpeed: Double = 200.0

    /// @var minSpeed
    /// @brief 최소 속도 (기본 0 km/h)
    let minSpeed: Double = 0.0

    // MARK: - Computed Properties

    /// @brief 속도 비율 (0.0 ~ 1.0)
    ///
    /// @details
    /// **계산:**
    /// ```
    /// speedRatio = (현재 속도 - 최소) / (최대 - 최소)
    /// 예: speed = 100, maxSpeed = 200
    ///     → speedRatio = 100 / 200 = 0.5 (50%)
    /// ```
    private var speedRatio: Double {
        let clamped = min(max(speed, minSpeed), maxSpeed)
        return (clamped - minSpeed) / (maxSpeed - minSpeed)
    }

    /// @brief 게이지 각도 (0° ~ 180°)
    ///
    /// @details
    /// 반원형 게이지이므로 180도 범위
    /// speedRatio = 0.0 → 0°
    /// speedRatio = 0.5 → 90°
    /// speedRatio = 1.0 → 180°
    private var gaugeAngle: Double {
        return speedRatio * 180.0
    }

    /// @brief 속도에 따른 색상
    ///
    /// @details
    /// 속도 범위별 색상:
    /// - 0-60: 녹색 (도심)
    /// - 60-100: 노란색 (일반 도로)
    /// - 100-140: 주황색 (고속 도로)
    /// - 140+: 빨간색 (과속)
    private var speedColor: Color {
        if speed < 60 {
            return .green
        } else if speed < 100 {
            return .yellow
        } else if speed < 140 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 배경 게이지 (회색, 반원)
            backgroundGauge

            // 속도 게이지 (색상, 현재 속도만큼)
            speedGauge

            // 중앙 속도 텍스트
            speedText
        }
    }

    // MARK: - Background Gauge

    /// @brief 배경 게이지 (회색 반원)
    ///
    /// @details
    /// 전체 속도 범위를 나타내는 반투명 배경 게이지
    private var backgroundGauge: some View {
        Circle()
            .trim(from: 0, to: 0.5)  // 반원 (0° ~ 180°)
            .stroke(
                Color.white.opacity(0.2),
                style: StrokeStyle(lineWidth: 12, lineCap: .round)
            )
            .rotationEffect(.degrees(180))  // 아래쪽 반원으로 회전
    }

    // MARK: - Speed Gauge

    /// @brief 속도 게이지 (색상 반원)
    ///
    /// @details
    /// 현재 속도만큼만 표시되며, 속도에 따라 색상이 변경됨
    private var speedGauge: some View {
        Circle()
            .trim(from: 0, to: CGFloat(speedRatio) * 0.5)  // 현재 속도만큼
            .stroke(
                speedColor,
                style: StrokeStyle(lineWidth: 12, lineCap: .round)
            )
            .rotationEffect(.degrees(180))  // 아래쪽 반원으로 회전
            .animation(.easeInOut(duration: 0.5), value: speed)  // 부드러운 애니메이션
    }

    // MARK: - Speed Text

    /// @brief 중앙 속도 텍스트
    ///
    /// @details
    /// 게이지 중앙에 큰 숫자로 속도 표시
    private var speedText: some View {
        VStack(spacing: 0) {
            Text(String(format: "%.0f", speed))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("km/h")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
        }
        .offset(y: 20)  // 반원 아래쪽에 위치
    }
}

// MARK: - Preview

struct SpeedometerGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // 저속 (녹색)
            SpeedometerGaugeView(speed: 45)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Low Speed (45 km/h)")

            // 중속 (노란색)
            SpeedometerGaugeView(speed: 85)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Medium Speed (85 km/h)")

            // 고속 (주황색)
            SpeedometerGaugeView(speed: 120)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("High Speed (120 km/h)")

            // 과속 (빨간색)
            SpeedometerGaugeView(speed: 160)
                .frame(width: 160, height: 100)
                .background(Color.black)
                .previewDisplayName("Overspeeding (160 km/h)")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
