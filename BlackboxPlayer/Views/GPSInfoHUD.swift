/// @file GPSInfoHUD.swift
/// @brief GPS 정보를 상단 바에 표시하는 HUD 컴포넌트
/// @author BlackboxPlayer Development Team
/// @details
/// 속도, 좌표, 고도, 위성 개수 등 GPS 정보를 컴팩트하게 표시합니다.

import SwiftUI

/// GPS 정보 HUD (Heads-Up Display)
///
/// ## 표시 정보
/// - 속도 (km/h)
/// - GPS 좌표 (위도, 경도)
/// - 고도 (m)
/// - 위성 개수
/// - 방향 (°)
///
/// ## 사용 예
/// ```swift
/// GPSInfoHUD(
///     gpsService: gpsService,
///     currentTime: syncController.currentTime
/// )
/// ```
struct GPSInfoHUD: View {
    // MARK: - Properties

    /// GPS 서비스
    @ObservedObject var gpsService: GPSService

    /// 현재 재생 시간
    let currentTime: TimeInterval

    /// 디버그 모드 (상세 정보 표시)
    @State private var showDebugInfo = false

    // MARK: - Computed Properties

    /// 현재 GPS 포인트
    private var currentGPSPoint: GPSPoint? {
        return gpsService.getCurrentLocation(at: currentTime)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            /// GPS 데이터 상태 인디케이터
            HStack(spacing: 6) {
                Image(systemName: gpsService.hasData ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 14))
                    .foregroundColor(gpsService.hasData ? .green : .red)

                Text(gpsService.hasData ? "GPS" : "No GPS")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }

            if let gpsPoint = currentGPSPoint {
                Divider()
                    .frame(height: 20)
                    .background(Color.white.opacity(0.3))

                /// 속도 표시
                if let speed = gpsPoint.speed {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text(String(format: "%.0f km/h", speed))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }

                /// GPS 좌표
                HStack(spacing: 4) {
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))

                    Text(coordinateString(gpsPoint))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }

                /// 고도 (있을 경우)
                if let altitude = gpsPoint.altitude {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text(String(format: "%.0f m", altitude))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                    }
                }

                /// 위성 개수 (있을 경우)
                if let satelliteCount = gpsPoint.satelliteCount {
                    HStack(spacing: 4) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Text("\(satelliteCount)")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(satelliteColor(count: satelliteCount))
                    }
                }
            } else if gpsService.hasData {
                /// GPS 데이터는 있지만 현재 시간에 데이터 없음
                Text("Searching...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }

            /// 디버그 정보 토글 버튼
            if gpsService.hasData {
                Button(action: { showDebugInfo.toggle() }) {
                    Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Toggle GPS debug info")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        /// 디버그 정보 팝오버
        .popover(isPresented: $showDebugInfo, arrowEdge: .bottom) {
            debugInfoView
                .padding()
                .frame(width: 300)
        }
    }

    // MARK: - Helper Views

    /// 디버그 정보 뷰
    private var debugInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GPS Debug Info")
                .font(.headline)

            Divider()

            /// 전체 데이터 통계
            Group {
                debugRow(label: "Total Points", value: "\(gpsService.pointCount)")
                debugRow(label: "Has Data", value: gpsService.hasData ? "Yes" : "No")

                if let summary = gpsService.summary {
                    if let maxSpeed = summary.maximumSpeed {
                        debugRow(label: "Max Speed", value: String(format: "%.1f km/h", maxSpeed))
                    }
                    if let avgSpeed = summary.averageSpeed {
                        debugRow(label: "Avg Speed", value: String(format: "%.1f km/h", avgSpeed))
                    }
                    debugRow(label: "Total Distance", value: String(format: "%.2f km", summary.totalDistance / 1000))
                }
            }

            Divider()

            /// 현재 시간 데이터
            Group {
                debugRow(label: "Current Time", value: String(format: "%.2f s", currentTime))

                if let gpsPoint = currentGPSPoint {
                    debugRow(label: "Latitude", value: String(format: "%.6f°", gpsPoint.latitude))
                    debugRow(label: "Longitude", value: String(format: "%.6f°", gpsPoint.longitude))

                    if let speed = gpsPoint.speed {
                        debugRow(label: "Speed", value: String(format: "%.2f km/h", speed))
                    }

                    if let heading = gpsPoint.heading {
                        debugRow(label: "Heading", value: String(format: "%.1f°", heading))
                    }
                } else {
                    Text("No GPS data at current time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            /// 거리 및 속도 정보
            Group {
                let distance = gpsService.distanceTraveled(at: currentTime)
                debugRow(label: "Distance", value: String(format: "%.2f km", distance / 1000))

                if let avgSpeed = gpsService.averageSpeed(at: currentTime) {
                    debugRow(label: "Avg Speed", value: String(format: "%.1f km/h", avgSpeed))
                }
            }
        }
    }

    /// 디버그 정보 행
    private func debugRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper Methods

    /// 좌표 문자열 생성
    private func coordinateString(_ point: GPSPoint) -> String {
        let lat = point.latitude
        let lon = point.longitude

        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"

        return String(format: "%.4f°%@ %.4f°%@", abs(lat), latDir, abs(lon), lonDir)
    }

    /// 위성 개수에 따른 색상
    private func satelliteColor(count: Int) -> Color {
        switch count {
        case 0...3:
            return .red
        case 4...8:
            return .yellow
        case 9...:
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Preview

struct GPSInfoHUD_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black

            VStack(spacing: 20) {
                /// GPS 데이터 있는 경우
                GPSInfoHUD(
                    gpsService: {
                        let service = GPSService()
                        // Mock data would be loaded here
                        return service
                    }(),
                    currentTime: 10.0
                )

                /// GPS 데이터 없는 경우
                GPSInfoHUD(
                    gpsService: GPSService(),
                    currentTime: 0.0
                )
            }
            .padding()
        }
        .frame(width: 800, height: 200)
    }
}
