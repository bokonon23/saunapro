# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is a pure Xcode project with no external dependency managers.

```bash
# Build
xcodebuild -scheme DayShape -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests
xcodebuild -scheme DayShape test -destination 'platform=iOS Simulator,name=iPhone 16'
```

Prefer building/running through Xcode directly (Cmd+B / Cmd+R / Cmd+U).

## Project Overview

**DayShape** is a health/fitness iOS app integrating with Apple HealthKit. Very early stage — currently only an app entry point and placeholder UI exist.

- **Deployment target**: iOS 26.2
- **Xcode**: 26.3
- **No third-party dependencies** — native frameworks only

## Architecture

- SwiftUI app lifecycle (`@main`, `WindowGroup`)
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor` unless otherwise specified
- HealthKit entitlements enabled: full access, health records, and background delivery

## Key Entitlements

`DayShape/DayShape.entitlements` enables:
- `com.apple.developer.healthkit`
- `com.apple.developer.healthkit.access`
- `com.apple.developer.healthkit.background-delivery`

Always request HealthKit authorization before querying data. Background delivery requires both the entitlement and explicit enablement per `HKObjectType`.
