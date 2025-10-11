#!/bin/bash

#
# test.sh
# BlackboxPlayer Test Script
#
# Runs unit tests and generates coverage reports
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="BlackboxPlayer"
SCHEME_NAME="BlackboxPlayer"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="build"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
TEST_RESULTS_DIR="${BUILD_DIR}/TestResults"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  ${1}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run tests
run_tests() {
    print_header "Running Unit Tests"

    mkdir -p "${TEST_RESULTS_DIR}"
    local log_file="${TEST_RESULTS_DIR}/test_$(date +%Y%m%d_%H%M%S).log"
    local result_bundle="${TEST_RESULTS_DIR}/TestResults.xcresult"

    print_info "Running tests..."
    print_info "Log file: ${log_file}"
    print_info "Result bundle: ${result_bundle}"
    print_info ""

    if xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Debug \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -resultBundlePath "${result_bundle}" \
        -enableCodeCoverage YES \
        test \
        2>&1 | tee "${log_file}"; then

        print_success "All tests passed"
        return 0
    else
        print_error "Tests failed. Check log: ${log_file}"
        return 1
    fi
}

# Show test summary
show_test_summary() {
    print_header "Test Summary"

    local result_bundle="${TEST_RESULTS_DIR}/TestResults.xcresult"

    if [ -d "${result_bundle}" ]; then
        print_info "Extracting test results..."

        # Use xcrun to get test summary
        xcrun xcresulttool get --path "${result_bundle}" --format json > "${TEST_RESULTS_DIR}/results.json" 2>/dev/null || true

        # Show basic info
        if [ -f "${TEST_RESULTS_DIR}/results.json" ]; then
            print_success "Test results extracted to: ${TEST_RESULTS_DIR}/results.json"
        fi

        print_info "Full results available at: ${result_bundle}"
        print_info ""
        print_info "To view detailed results, run:"
        print_info "  open ${result_bundle}"
    else
        print_warning "Test result bundle not found"
    fi
}

# Generate coverage report
generate_coverage() {
    print_header "Generating Coverage Report"

    local result_bundle="${TEST_RESULTS_DIR}/TestResults.xcresult"
    local coverage_file="${TEST_RESULTS_DIR}/coverage.txt"

    if [ -d "${result_bundle}" ]; then
        print_info "Extracting coverage data..."

        # Extract coverage report
        if xcrun xccov view --report --json "${result_bundle}" > "${coverage_file}" 2>/dev/null; then
            print_success "Coverage report generated: ${coverage_file}"

            # Calculate total coverage
            if command -v jq &> /dev/null; then
                local coverage=$(jq '.lineCoverage' "${coverage_file}" 2>/dev/null | awk '{printf "%.2f%%", $1 * 100}')
                print_info "Total line coverage: ${coverage}"
            fi
        else
            print_warning "Failed to extract coverage data"
        fi
    else
        print_warning "Test result bundle not found"
    fi
}

# Main execution
main() {
    print_header "BlackboxPlayer Test Script"
    print_info "Project: ${PROJECT_NAME}"
    print_info ""

    # Change to project root directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${SCRIPT_DIR}/.."

    print_info "Working directory: $(pwd)"
    print_info ""

    # Run tests
    if run_tests; then
        show_test_summary
        generate_coverage

        print_header "Test Complete"
        print_success "All tests passed successfully!"
        exit 0
    else
        print_header "Test Complete"
        print_error "Some tests failed!"
        show_test_summary
        exit 1
    fi
}

# Run main function
main
