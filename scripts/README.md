# Build Scripts

This directory contains automated build scripts for the BlackboxPlayer macOS application.

## Available Scripts

### 1. build.sh - Main Build Script

Interactive build script for local development.

**Usage:**
```bash
# Build Debug configuration (default)
./scripts/build.sh

# Build Release configuration
./scripts/build.sh Release
```

**Features:**
- Automatic xcodegen project generation
- Clean build option (Release only)
- Interactive test execution prompt
- Colored output and progress indicators
- Build artifact summary
- Build logs saved to `build/` directory

**Requirements:**
- Xcode 15+
- xcodegen (auto-installed via Homebrew if missing)

---

### 2. test.sh - Test Runner

Runs unit tests and generates coverage reports.

**Usage:**
```bash
./scripts/test.sh
```

**Features:**
- Executes all unit tests
- Generates coverage reports
- Creates `.xcresult` bundles
- Extracts test summary
- Saves results to `build/TestResults/`

**Output:**
- Test logs: `build/TestResults/test_*.log`
- Result bundle: `build/TestResults/TestResults.xcresult`
- Coverage report: `build/TestResults/coverage.txt`

**View Results:**
```bash
# Open in Xcode
open build/TestResults/TestResults.xcresult
```

---

### 3. archive.sh - Archive & Distribution

Creates release archives for distribution.

**Usage:**
```bash
./scripts/archive.sh
```

**Features:**
- Interactive workflow
- Creates `.xcarchive` for distribution
- Optional archive export
- Optional DMG creation (requires `create-dmg`)
- Opens in Xcode Organizer

**Workflow:**
1. Generates Xcode project
2. Creates archive (Release configuration)
3. Prompts to export archive
4. Prompts to create DMG

**Output:**
- Archive: `build/Archives/BlackboxPlayer_*.xcarchive`
- Export: `build/Export/BlackboxPlayer_*/`
- DMG: `build/BlackboxPlayer_*.dmg` (optional)

**Install DMG Creator:**
```bash
brew install create-dmg
```

---

### 4. ci-build.sh - CI/CD Build

Non-interactive build script for CI/CD pipelines.

**Usage:**
```bash
# Debug build (with tests)
./scripts/ci-build.sh

# Release build (no tests)
./scripts/ci-build.sh Release
```

**Features:**
- Non-interactive (no prompts)
- CI environment detection
- Code signing disabled for CI
- Structured logging for CI systems
- GitHub Actions integration
- Error handling and exit codes

**Environment Variables:**
- `CI=true` - Enables CI mode
- `GITHUB_ACTIONS=true` - GitHub Actions integration

**GitHub Actions Integration:**
```yaml
- name: Build
  run: ./scripts/ci-build.sh Debug
```

---

## Build Artifacts

All build outputs are stored in the `build/` directory:

```
build/
├── DerivedData/           # Xcode build outputs
├── Archives/              # Release archives
├── Export/                # Exported applications
├── TestResults/           # Test results and coverage
├── build_*.log            # Build logs
├── test_*.log             # Test logs
└── *.dmg                  # Distribution DMG files
```

**Note:** The `build/` directory is git-ignored.

---

## Common Tasks

### Clean Build
```bash
# Remove all build artifacts
rm -rf build/

# Build from scratch
./scripts/build.sh Release
```

### Run Tests with Coverage
```bash
./scripts/test.sh

# View coverage in Xcode
open build/TestResults/TestResults.xcresult
```

### Create Release DMG
```bash
# Full workflow
./scripts/archive.sh

# Follow prompts to export and create DMG
```

### CI/CD Integration
```bash
# In your CI pipeline
./scripts/ci-build.sh Debug

# Check exit code
echo $?  # 0 = success, 1 = failure
```

---

## Troubleshooting

### xcodegen not found
```bash
# Install via Homebrew
brew install xcodegen
```

### Build fails with code signing error
```bash
# For local builds, configure Xcode signing
# For CI builds, use ci-build.sh (signing disabled)
./scripts/ci-build.sh Debug
```

### Tests fail
```bash
# View detailed test results
open build/TestResults/TestResults.xcresult

# Check test logs
cat build/TestResults/test_*.log
```

### Archive fails
```bash
# Ensure Release configuration builds successfully first
./scripts/build.sh Release

# Then try archiving
./scripts/archive.sh
```

---

## Project Configuration

Build scripts use settings from `project.yml`:

```yaml
name: BlackboxPlayer
options:
  bundleIdPrefix: com.blackboxplayer
  deploymentTarget:
    macOS: "12.0"
```

To modify build settings, edit `project.yml` and regenerate:
```bash
xcodegen
```

---

## Development Workflow

**Recommended workflow for local development:**

1. **Make changes to code**

2. **Quick Debug build:**
   ```bash
   ./scripts/build.sh
   ```

3. **Run tests:**
   ```bash
   ./scripts/test.sh
   ```

4. **Create Release build:**
   ```bash
   ./scripts/build.sh Release
   ```

5. **Create distribution archive:**
   ```bash
   ./scripts/archive.sh
   ```

---

## CI/CD Pipeline Example

**GitHub Actions workflow:**

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest

    steps:
      - uses: actions/checkout@v3

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Install Dependencies
        run: brew install xcodegen

      - name: Build and Test
        run: ./scripts/ci-build.sh Debug

      - name: Upload Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: BlackboxPlayer-Debug
          path: build/DerivedData/Build/Products/Debug/BlackboxPlayer.app
```

---

## Script Maintenance

All scripts follow these conventions:

- **Exit codes:** 0 = success, 1 = failure
- **Error handling:** `set -e` (exit on error)
- **Colored output:** Green = success, Red = error, Yellow = warning, Blue = info
- **Logs:** All outputs saved to `build/*.log`
- **Non-destructive:** Scripts won't delete source code, only build artifacts

---

## Support

For issues with build scripts:

1. Check script logs in `build/` directory
2. Ensure all requirements are installed
3. Try cleaning and rebuilding: `rm -rf build/`
4. Verify Xcode and xcodegen versions

For project-specific build issues, check the main project README.

---

**Last Updated:** 2025-10-12
**Project:** BlackboxPlayer macOS Application
