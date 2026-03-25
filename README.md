# Rejoy

An iOS app to track practice sessions by activity, plant “seeds” over time, and complete dedications (voice or text) after each session.

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+
- Bundle ID: `com.globio.rejoy`

## Project structure (high level)

```
Rejoy/
├── Rejoy.xcodeproj/
├── Rejoy/
│   ├── RejoyApp.swift          # App entry, SwiftData container, root flow
│   ├── Info.plist
│   ├── Models/                 # Session, ActivityType, AppSettings, …
│   ├── Storage/LocalStore.swift
│   ├── Services/               # Supabase, tracking, seeds attribution, …
│   └── Features/
│       ├── MainTabView.swift   # Home (seeds), profile/settings
│       ├── Home/, Tracking/, Settings/, Onboarding/, Sangha/, …
│       └── Summary/ConfettiView.swift  # Used after saving a dedication
└── RejoyWidgetExtension/
```

## Build and run

1. Open the project: `open Rejoy.xcodeproj`
2. Select scheme **Rejoy** and an iOS 17+ simulator or device.
3. Set your **Team** for signing on device builds.

**Simulator:** Core Motion–based visuals (e.g. seeds jar tilt) may behave differently than on device; push notifications are limited.

## Info.plist (permissions)

- `NSMotionUsageDescription` – device motion for seeds jar / welcome visuals
- `NSPhotoLibraryAddUsageDescription` – saving activity stickers
- `NSMicrophoneUsageDescription` / `NSSpeechRecognitionUsageDescription` – optional voice dedication
- `NSCalendars…` / Health / Location – **not** used; those keys were removed with the retired prototype features

## Capabilities

- Sign in with Apple, App Groups (widget), Push Notifications (development entitlement in repo), Live Activities where enabled.

**HealthKit** is not used; remove the HealthKit capability from the App ID in the Apple Developer portal if it is still enabled there (the app target no longer declares it in `Rejoy.entitlements`).

## Marketing site

Landing page: **[github.com/maxiglobio/rejoy-marketing](https://github.com/maxiglobio/rejoy-marketing)**.
