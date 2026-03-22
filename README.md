# Rejoy

A time dedication tracking iOS app that aggregates minutes/hours from multiple data sources and maps them to your intentions.

## Requirements

- iOS 17+
- Xcode 15+
- Swift 5.9+
- Bundle ID: `com.globio.rejoy`

## Project Structure

```
Rejoy/
├── Rejoy.xcodeproj/
├── Rejoy/
│   ├── RejoyApp.swift          # App entry + SwiftData container
│   ├── ContentView.swift       # TabView (Permissions, Intentions, Summary)
│   ├── Info.plist
│   ├── Assets.xcassets/
│   ├── Models/
│   │   ├── DataSourceType.swift
│   │   ├── Intention.swift
│   │   ├── DedicationMapping.swift
│   │   └── DailyRecord.swift
│   ├── Storage/
│   │   └── LocalStore.swift
│   ├── Services/
│   │   ├── HealthKitService.swift
│   │   ├── CalendarService.swift
│   │   ├── MotionService.swift
│   │   ├── LocationService.swift
│   │   ├── ScreenTimeService.swift   # Returns empty until entitlement available
│   │   └── DedicationEngine.swift
│   └── Features/
│       ├── Onboarding/
│       ├── Intentions/
│       ├── Summary/
│       └── ManualEntry/
```

## Build & Run

### Simulator

1. Open the project in Xcode:
   ```bash
   open ~/Projects/Rejoy/Rejoy.xcodeproj
   ```

2. Select scheme **Rejoy** and an iOS 17+ simulator (e.g. iPhone 16).

3. Build and run (Cmd+R).

**Note:** HealthKit, Motion (pedometer), and Location may return limited or no data in Simulator. Calendar and Manual Entry work fully.

### Device

1. Select your physical device as the run destination.
2. Set your **Team** in Signing & Capabilities.
3. Build and run; grant permissions when prompted.
4. HealthKit, Motion, Location, and Calendar will use real data.

## Info.plist Keys

The app uses these permission descriptions:

- `NSHealthShareUsageDescription` – Health data (workouts, steps, exercise, mindful, sleep)
- `NSHealthUpdateUsageDescription` – Saving dedication data to Health
- `NSMotionUsageDescription` – Pedometer for walking/running time
- `NSLocationWhenInUseUsageDescription` – Time at saved places
- `NSCalendarsFullAccessUsageDescription` – Calendar events
- `UIBackgroundModes` – `fetch` for background refresh

## Capabilities

- **HealthKit** – Workouts, steps, exercise time, mindful sessions, sleep
- **Background Modes** – Background fetch (optional daily refresh)

## Limitations

| Feature | Limitation |
|---------|------------|
| **Screen Time** | Not included (requires Family Controls entitlement). |
| **HealthKit (Simulator)** | Limited data; may show zeros. Add sample data in Health app for testing. |
| **Pedometer (Simulator)** | May not provide step data. |
| **Location** | MVP uses simple distance checks; manual "Arrived/Left" fallback available. |
| **Background fetch** | System may delay or skip; not guaranteed. |

## Features

- **Onboarding / Permissions** – Request access for Health, Motion, Location, Calendar
- **Intentions** – Create intentions (name + emoji) and map data sources to them
- **Daily Summary** – Totals by source and by intention; weekly chart
- **Manual Entry** – Add dedication blocks with duration and intention
- **Dedication Ritual** – "Rejoice" button with haptic + confetti + dedication message

## Marketing site

The public landing page (Vercel) is maintained in a separate repository: **[github.com/maxiglobio/rejoy-marketing](https://github.com/maxiglobio/rejoy-marketing)**. A `website/` copy may exist locally next to this project for convenience; it is not tracked here to avoid divergence.
