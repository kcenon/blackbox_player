# Testing Guide

## Overview

The BlackboxPlayer project maintains comprehensive test coverage to ensure reliability, performance, and correctness of all major components. This document describes the testing strategy, test suite organization, and best practices for writing and running tests.

## Test Coverage Goals

- **Minimum Coverage**: 80% across all modules
- **Critical Paths**: 100% coverage for:
  - Multi-channel synchronization (SyncController)
  - Video decoding and rendering (VideoDecoder, Metal renderer)
  - Data parsing (GPS, G-sensor, VideoMetadata)
  - File system access (FileSystemService)

## Running Tests

### Quick Start

```bash
# Run all tests with coverage
./scripts/test.sh

# Build and optionally run tests
./scripts/build.sh  # Will prompt after build

# Run tests in Xcode
# Press Cmd+U or Product > Test
```

### Advanced Testing

```bash
# Run specific test class
xcodebuild test -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -only-testing:BlackboxPlayerTests/GPSSensorIntegrationTests

# Run specific test method
xcodebuild test -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -only-testing:BlackboxPlayerTests/GPSSensorIntegrationTests/testGPSServiceIntegration

# Run tests with verbose output
xcodebuild test -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -verbose
```

## Test Suite Organization

### Test Files

| Test File | Lines | Focus Area | Test Count |
|-----------|-------|------------|------------|
| **GPSSensorIntegrationTests.swift** | 773 | GPS/G-Sensor Pipeline | 9 |
| **SyncControllerTests.swift** | - | Multi-Channel Sync | Multiple |
| **VideoDecoderTests.swift** | - | FFmpeg Decoding | Multiple |
| **VideoChannelTests.swift** | - | Channel Management | Multiple |
| **DataModelsTests.swift** | - | Data Models | Multiple |
| **FileSystemServiceTests.swift** | - | File System Access | Multiple |
| **MultiChannelRendererTests.swift** | - | Metal Rendering | Multiple |
| **BlackboxPlayerTests.swift** | - | General App Tests | Multiple |

### Test Categories

Tests are organized into functional categories:

1. **Unit Tests**: Test individual components in isolation
2. **Integration Tests**: Test component interactions and data flow
3. **Performance Tests**: Benchmark critical operations
4. **UI Tests**: Test user interface interactions (future)

## GPS/G-Sensor Integration Tests

### Overview

The `GPSSensorIntegrationTests.swift` file provides comprehensive end-to-end testing of the GPS and G-sensor data processing pipeline, from data parsing through service integration to UI synchronization.

### Data Pipeline

```
┌────────────────────────────────────────────────┐
│         Video File (with metadata)             │
└─────────────────┬──────────────────────────────┘
                  ↓
┌────────────────────────────────────────────────┐
│            VideoMetadata                       │
│  - GPS Points Array (timestamp, lat/lon)       │
│  - Acceleration Data Array (timestamp, x/y/z)  │
└───────────┬────────────────────────────────────┘
            ↓
    ┌───────┴────────┐
    ↓                ↓
┌─────────┐    ┌──────────────┐
│GPSService│    │GSensorService│
└─────┬───┘    └──────┬───────┘
      ↓                ↓
      └────────┬───────┘
               ↓
    ┌─────────────────┐
    │ SyncController  │  (30fps)
    └────────┬────────┘
             ↓
    ┌────────┴────────┐
    ↓                 ↓
┌─────────┐    ┌─────────────┐
│MapOverlay│    │GSensorChart│
│(GPS route)│   │(XYZ graph) │
└──────────┘    └────────────┘
```

### Test Categories

#### 1. Data Parsing Tests

Tests that validate correct parsing and storage of GPS and G-sensor data.

**Test: `testVideoMetadataGPSData()`**
- **Purpose**: Verify VideoMetadata correctly stores and retrieves GPS points
- **Coverage**: GPS point array storage, data existence checks, time-based queries
- **Assertions**:
  - GPS point count matches expected
  - `hasGPSData` flag is set correctly
  - GPS points can be queried by timestamp

**Test: `testVideoMetadataAccelerationData()`**
- **Purpose**: Verify VideoMetadata correctly stores and retrieves acceleration data
- **Coverage**: Acceleration data array storage, 100Hz sampling rate
- **Assertions**:
  - Acceleration data count matches expected (1000 samples for 10 seconds)
  - `hasAccelerationData` flag is set correctly
  - Acceleration data can be queried by timestamp

**Test: `testImpactEventDetection()`**
- **Purpose**: Verify impact event detection from high acceleration values
- **Coverage**: Threshold-based event detection, magnitude calculation
- **Assertions**:
  - Impact events are detected when acceleration exceeds threshold (>3.0G)
  - Magnitude calculation is correct: `sqrt(x² + y² + z²)`
  - Normal driving conditions don't trigger false positives

#### 2. Service Integration Tests

Tests that validate GPS and G-sensor services correctly load and provide data.

**Test: `testGPSServiceIntegration()`**
- **Purpose**: Verify GPSService loads and provides GPS data from VideoMetadata
- **Coverage**: Service initialization, data loading, data availability checks
- **Assertions**:
  - `loadGPSData()` successfully loads from VideoMetadata
  - `hasData` flag indicates data presence
  - `pointCount` matches loaded GPS points
  - `routePoints` array is populated for map display
  - `getCurrentLocation(at:)` returns valid locations

**Test: `testGPSInterpolation()`**
- **Purpose**: Verify linear interpolation between GPS points
- **Coverage**: Time-based interpolation, coordinate calculation, speed interpolation
- **Test Data**:
  - Point 1: (37.5000, 127.0000) at t=0s, speed=30.0 km/h
  - Point 2: (37.5020, 127.0020) at t=2s, speed=40.0 km/h
- **Assertions**:
  - Interpolated latitude at t=1s: 37.5010 (±0.0001)
  - Interpolated longitude at t=1s: 127.0010 (±0.0001)
  - Interpolated speed at t=1s: 35.0 km/h (±0.1)
- **Algorithm**: Linear interpolation: `value = start + (end - start) * ratio`

#### 3. Synchronization Tests

Tests that validate sensor data synchronization with video playback.

**Test: `testVideoGPSSynchronization()`**
- **Purpose**: Verify GPS data synchronizes with video playback time
- **Coverage**: Video file loading, seeking, time-based GPS queries
- **Synchronization Accuracy**: ±100ms (0.1 second)
- **Assertions**:
  - GPS location is available at seeked time
  - GPS timestamp matches video timestamp within tolerance
  - Seeking to different times returns appropriate GPS data

**Test: `testVideoGSensorSynchronization()`**
- **Purpose**: Verify G-sensor data synchronizes with video playback time
- **Coverage**: Video file loading, seeking, time-based acceleration queries
- **Synchronization Accuracy**: ±10ms (0.01 second) - tighter than GPS due to 100Hz sampling
- **Assertions**:
  - Acceleration data is available at seeked time
  - G-sensor timestamp matches video timestamp within tolerance
  - High sampling rate (100Hz) provides smooth data

**Test: `testRealtimeSensorDataUpdate()`**
- **Purpose**: Verify sensor data updates in real-time during playback
- **Coverage**: Combine publishers, reactive updates, playback state changes
- **Implementation**: Uses Combine to observe `$currentTime` publisher
- **Assertions**:
  - GPS location updates as time progresses
  - Acceleration data updates as time progresses
  - Multiple updates occur during 2-second playback window
  - At least 4 updates detected (2 GPS + 2 acceleration minimum)

#### 4. Performance Tests

Tests that benchmark critical operations and ensure acceptable performance.

**Test: `testGPSDataSearchPerformance()`**
- **Purpose**: Measure GPS point search performance with large datasets
- **Test Data**: 10,000 GPS points (simulating hours of driving)
- **Search Operations**: 100 searches (every 100th point)
- **Expected Algorithm**: Binary search with O(log n) complexity
- **Performance Expectations**:
  - All searches complete within measurement period
  - Average search time is acceptable for real-time playback
  - Performance scales logarithmically with dataset size

### Helper Methods

The test suite includes several helper methods for creating test data:

**GPS Data Helpers:**
- `createSampleGPSPoints(baseDate:count:)` - Generate GPS point arrays
- `createSampleGPSBinaryData()` - Generate binary GPS data (Float64)
- `createLargeGPSBinaryData(count:)` - Generate large GPS datasets

**G-Sensor Data Helpers:**
- `createSampleAccelerationData(baseDate:count:)` - Generate acceleration arrays
- `createSampleAccelerationFloat32Data()` - Generate binary acceleration (Float32)
- `createSampleAccelerationInt16Data()` - Generate binary acceleration (Int16)
- `createLargeAccelerationFloat32Data(count:)` - Generate large acceleration datasets

**Integration Helpers:**
- `createSampleVideoFile()` - Create complete VideoFile with GPS and G-sensor metadata

### Test Data Formats

**GPS Point Structure:**
```swift
GPSPoint {
    coordinate: CLLocationCoordinate2D {
        latitude: Double   // Degrees
        longitude: Double  // Degrees
    }
    timestamp: Date        // Absolute time
    speed: Double         // km/h
}
```

**Acceleration Data Structure:**
```swift
AccelerationData {
    timestamp: Date   // Absolute time
    x: Double        // G-force (lateral)
    y: Double        // G-force (forward/backward)
    z: Double        // G-force (vertical)
}
```

## Writing New Tests

### Test Naming Convention

Follow the pattern: `test[Component][Action][Condition]`

**Examples:**
- `testGPSServiceIntegration()` - Tests GPS service integration
- `testVideoMetadataGPSData()` - Tests VideoMetadata GPS data handling
- `testGPSInterpolation()` - Tests GPS interpolation algorithm

### Test Structure

Use the **Given-When-Then** pattern:

```swift
func testExampleFeature() {
    // Given: Setup test data and preconditions
    let baseDate = Date()
    let testData = createSampleData()

    // When: Execute the operation being tested
    let result = service.performOperation(testData)

    // Then: Assert expected outcomes
    XCTAssertNotNil(result, "Result should exist")
    XCTAssertEqual(result.value, expectedValue, "Value should match")
}
```

### Best Practices

1. **Isolation**: Each test should be independent and not rely on other tests
2. **Clarity**: Test names should clearly describe what is being tested
3. **Assertions**: Use descriptive assertion messages
4. **Setup/Teardown**: Use `setUp()` and `tearDown()` for common initialization
5. **Test Data**: Use helper methods to create consistent test data
6. **Performance**: Mark performance tests with `measure { }` block
7. **Async Testing**: Use `XCTestExpectation` for asynchronous operations

### Example: Adding a New GPS Feature Test

```swift
func testGPSRouteDistance() {
    // Given: GPS route with known points
    let baseDate = Date()
    let points = [
        GPSPoint(coordinate: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780),
                timestamp: baseDate, speed: 30.0),
        GPSPoint(coordinate: CLLocationCoordinate2D(latitude: 37.5670, longitude: 126.9785),
                timestamp: baseDate.addingTimeInterval(1.0), speed: 30.0)
    ]
    let metadata = VideoMetadata(gpsPoints: points, accelerationData: [])

    // When: Calculate route distance
    gpsService.loadGPSData(from: metadata, startTime: baseDate)
    let distance = gpsService.calculateRouteDistance()

    // Then: Distance should be approximately correct
    // Distance between points: ~66 meters (calculated using Haversine formula)
    XCTAssertEqual(distance, 66.0, accuracy: 10.0,
                  "Route distance should be approximately 66 meters")
}
```

## Coverage Reports

### Generating Coverage

```bash
# Run tests with coverage
./scripts/test.sh

# View in Xcode
# 1. Product > Test (Cmd+U)
# 2. Show Report Navigator (Cmd+9)
# 3. Select test run > Coverage tab
```

### Coverage Targets by Module

| Module | Target Coverage | Current Status |
|--------|----------------|----------------|
| GPS/G-Sensor Pipeline | 90%+ | ✅ Comprehensive tests |
| Multi-Channel Sync | 90%+ | In progress |
| Video Decoding | 85%+ | In progress |
| Data Models | 95%+ | In progress |
| File System Access | 80%+ | In progress |
| Metal Rendering | 75%+ | In progress |

## Continuous Integration

Tests run automatically on GitHub Actions for every push and pull request:

```yaml
# .github/workflows/build.yml
- name: Run Tests
  run: ./scripts/ci-build.sh Debug
```

**CI Test Requirements:**
- All tests must pass
- No test timeouts (max 10 minutes)
- Coverage reports generated
- Test results archived as artifacts

## Troubleshooting

### Test Failures

**Issue**: Tests fail with "Unable to load video file"
**Solution**: Ensure test data is properly created using helper methods

**Issue**: Synchronization tests fail intermittently
**Solution**: Increase timeout values or check system performance

**Issue**: Performance tests fail on slower machines
**Solution**: Adjust performance expectations in `measure { }` blocks

### Coverage Issues

**Issue**: Coverage report shows 0% for some files
**Solution**: Ensure files are included in test target

**Issue**: Coverage not generated
**Solution**: Enable code coverage in scheme settings

## Additional Resources

- [Apple XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Testing Best Practices](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode)
- [Performance Testing](https://developer.apple.com/documentation/xctest/performance_tests)
- [Code Coverage](https://developer.apple.com/documentation/xcode/code-coverage)

## Test Maintenance

### Regular Tasks

- **Weekly**: Review test coverage and identify gaps
- **Monthly**: Update test data to reflect real-world scenarios
- **Per Release**: Verify all tests pass and coverage meets targets
- **After Bugs**: Add regression tests for fixed bugs

### Test Data Management

Test data should be:
- **Representative**: Reflect real dashcam data formats
- **Comprehensive**: Cover edge cases and error conditions
- **Maintainable**: Use helper methods for generation
- **Documented**: Comment unusual or complex test scenarios

---

**Last Updated**: 2025-10-12
**Test Coverage**: 80%+ target across all modules
**Total Test Count**: 9+ GPS/G-sensor tests, multiple additional test suites
