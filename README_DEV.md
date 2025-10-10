# BlackboxPlayer - Development Guide

> **Note**: For general project information, see [README.md](README.md)

This guide provides instructions for setting up and building the BlackboxPlayer project.

## Prerequisites

### System Requirements

- **macOS**: 12.0 (Monterey) or later
- **Xcode**: 15.0 or later (currently using 26.0.1)
- **Apple Silicon** or Intel Mac

### Required Tools

1. **Homebrew** (4.6.11+)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Development Tools**
   ```bash
   brew install ffmpeg cmake git git-lfs swiftlint xcodegen
   ```

   Installed versions:
   - FFmpeg: 8.0
   - Git LFS: 3.7.0
   - SwiftLint: 0.61.0
   - XcodeGen: 2.44.1

3. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   xcodebuild -runFirstLaunch
   ```

## Project Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd blackbox_player
```

### 2. Generate Xcode Project

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project from `project.yml`.

```bash
xcodegen generate
```

**Note**: The `.xcodeproj` file is git-ignored and regenerated from `project.yml`. Never edit the `.xcodeproj` directly.

### 3. Open in Xcode

```bash
open BlackboxPlayer.xcodeproj
```

### 4. Build and Run

- Select the `BlackboxPlayer` scheme
- Choose your Mac as the destination
- Press `⌘+R` to build and run

## Project Structure

```
blackbox_player/
├── .github/
│   └── workflows/
│       └── build.yml          # CI/CD pipeline
├── BlackboxPlayer/
│   ├── App/                   # Application entry point
│   │   └── BlackboxPlayerApp.swift
│   ├── Views/                 # SwiftUI views
│   │   └── ContentView.swift
│   ├── ViewModels/            # View models (MVVM pattern)
│   ├── Services/              # Business logic and services
│   ├── Models/                # Data models
│   ├── Utilities/             # Utility functions and extensions
│   │   └── BridgingHeader.h  # Objective-C bridging header
│   ├── Resources/             # Assets and resources
│   │   ├── Info.plist
│   │   ├── BlackboxPlayer.entitlements
│   │   └── Assets.xcassets/
│   └── Tests/                 # Unit and integration tests
├── docs/                      # Project documentation
├── project.yml                # XcodeGen project configuration
├── .swiftlint.yml            # SwiftLint configuration
├── .gitignore                # Git ignore rules
├── IMPLEMENTATION_CHECKLIST.md       # Implementation progress (English)
├── IMPLEMENTATION_CHECKLIST_kr.md    # Implementation progress (Korean)
└── README.md                 # Project overview
```

## FFmpeg Integration

The project is configured to use Homebrew's FFmpeg installation:

- **Include Path**: `/opt/homebrew/Cellar/ffmpeg/8.0_1/include`
- **Library Path**: `/opt/homebrew/Cellar/ffmpeg/8.0_1/lib`
- **Linked Libraries**: `avformat`, `avcodec`, `swscale`, `avutil`, `swresample`

These paths are configured in `project.yml` and may need to be updated if FFmpeg is upgraded.

## Building from Command Line

### Clean Build

```bash
xcodebuild -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -configuration Debug \
           clean build
```

### Run Tests

```bash
xcodebuild -project BlackboxPlayer.xcodeproj \
           -scheme BlackboxPlayer \
           -configuration Debug \
           test
```

### Run SwiftLint

```bash
swiftlint lint BlackboxPlayer
```

## Code Signing

For development builds, the project uses **automatic code signing** with ad-hoc signing.

For distribution:
1. Configure your Apple Developer account in Xcode
2. Select your development team
3. Update `CODE_SIGN_STYLE` in `project.yml` if needed

## Continuous Integration

The project uses GitHub Actions for CI/CD:

- **Build and Test**: Runs on every push and pull request
- **SwiftLint**: Checks code quality
- **Coverage**: Reports test coverage

See `.github/workflows/build.yml` for configuration.

## Common Issues

### Issue: FFmpeg not found

**Error**: `ld: library not found for -lavformat`

**Solution**:
```bash
# Reinstall FFmpeg
brew reinstall ffmpeg

# Update paths in project.yml if needed
brew --prefix ffmpeg
```

### Issue: Xcode project out of sync

**Error**: Build settings or file references are incorrect

**Solution**:
```bash
# Regenerate the project
xcodegen generate

# Clean build
xcodebuild clean
```

### Issue: SwiftLint warnings

**Solution**:
```bash
# Auto-fix some issues
swiftlint --fix

# Or update .swiftlint.yml to adjust rules
```

## Development Workflow

1. **Make changes** in your editor
2. **Regenerate project** if you added/removed files:
   ```bash
   xcodegen generate
   ```
3. **Run SwiftLint** to check code quality:
   ```bash
   swiftlint lint BlackboxPlayer --quiet
   ```
4. **Build and test**:
   ```bash
   xcodebuild build test
   ```
5. **Commit changes**:
   ```bash
   git add .
   git commit -m "type(scope): description"
   ```

## Commit Message Format

Follow the conventional commits format:

```
type(scope): description

[optional body]

[optional footer]
```

**Types**: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Examples**:
- `feat(player): add video playback controls`
- `fix(decoder): resolve memory leak in frame conversion`
- `docs(readme): update build instructions`

## Resources

- [Project Documentation](docs/)
- [Implementation Checklist](IMPLEMENTATION_CHECKLIST.md)
- [Technical Challenges](docs/05_technical_challenges.md)
- [Architecture](docs/03_architecture.md)

## Current Status

**Phase 0: Preparation** - 9/15 tasks completed (60%)

✅ Environment setup complete
✅ Project structure created
✅ CI/CD pipeline configured
✅ FFmpeg linked to project

⏳ Pending: EXT4 library integration, sample data collection

See [IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md) for detailed progress.

---

**Last Updated**: 2025-10-10
**Xcode Version**: 26.0.1
**macOS Target**: 12.0+
