# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a pure Xcode project with no external dependency managers.

```bash
# Build
xcodebuild -scheme SaunaPro -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run tests
xcodebuild -scheme SaunaPro test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Prefer building/running through Xcode directly (Cmd+B / Cmd+R / Cmd+U).

## Project Overview

**SaunaPro** is an AI-powered sauna & cold plunge tracking iOS app integrating with Apple HealthKit. It auto-detects sessions from Apple Watch data and provides coaching insights.

- **Deployment target**: iOS 26.2
- **Xcode**: 26.3
- **No third-party dependencies** — native frameworks only

## Architecture

- SwiftUI app lifecycle (`@main`, `WindowGroup`)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor` unless otherwise specified
- HealthKit entitlements enabled: full access, health records, and background delivery
- Source folder is `DayShape/` (retained from original project name)

## Key Entitlements

`DayShape/SaunaPro.entitlements` enables:
- `com.apple.developer.healthkit`
- `com.apple.developer.healthkit.access`
- `com.apple.developer.healthkit.background-delivery`

Always request HealthKit authorization before querying data. Background delivery requires both the entitlement and explicit enablement per `HKObjectType`.
