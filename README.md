# TimeBudget

A passive time tracking app for iOS that helps you understand how you spend your day. Built with SwiftUI and SwiftData, TimeBudget automatically tracks your activities using Apple Watch sensors, HealthKit, Core Motion, Core Location, and EventKit — then lets you "budget" your time like you'd budget money.

No backend. All data stays on your device.

## Features

### Passive Tracking
- **Sleep** — Automatically detected from Apple Watch, with sleep stage merging and Fajr prayer detection
- **Exercise** — Workouts synced from HealthKit (walking, running, cycling, etc.)
- **Meetings** — Pulled from your calendar via EventKit
- **Movement** — Core Motion activity detection (stationary, walking, driving)
- **Location** — Significant location monitoring with saved places (home, work, gym)

### Integrations
- **AniList** — Track manga reading activity with chapter counts and estimated reading time
- **LeetCode** — Track coding practice with problem stats, topic tags, and submission history

### Dashboard
- Today's health stats (steps, sleep, exercise, meetings)
- 24-hour timeline ring showing your day color-coded by activity
- Pie chart breakdown of time spent per category
- Live activity detection with current location context

### Insights
- **30-day trends** — Rolling averages for sleep, steps, exercise, and reading
- **Week vs week** — Side-by-side comparison of this week and last
- **Contribution heatmaps** — GitHub-style calendars for activity, manga, and LeetCode
- **Correlations** — Discover patterns like "more sleep → more steps" from 90 days of data
- **Detail views** — Tap any section title for deeper analytics with charts and breakdowns

### Focus Stopwatch
Manual timer for activities that aren't automatically tracked:
- Manga, LeetCode, Learning, Coding, Yoga
- Sessions persist through app backgrounding

### Time Budgets
- Set daily time targets per category
- Track actual vs. budgeted time
- Daily score (0–100) based on how close you hit your ideal day

### Settings
- Save and label frequent places on a map
- Configure your ideal day with per-category targets
- Connect AniList and LeetCode accounts
- Manage permissions (Health, Location, Calendar, Motion)

## Requirements

- iPhone running iOS 17+
- Apple Watch (for automatic sleep and workout tracking)
- Xcode 15+ (to build and deploy)

## Setup

1. Clone the repo:
   ```bash
   git clone https://github.com/ItsAbdiOk/TimeBudget.git
   ```

2. Open `TimeBudget.xcodeproj` in Xcode

3. Select your development team under **Signing & Capabilities**

4. Build and run on your iPhone (Simulator won't have HealthKit data)

5. Grant permissions when prompted (Health, Location, Calendar, Motion)

6. Optionally, connect your accounts in **Settings**:
   - **AniList** — Enter your username to track manga reading
   - **LeetCode** — Enter your username to track coding practice

> **Note:** With a free Apple Developer account, the app expires every 7 days and needs to be re-deployed from Xcode.

## Architecture

```
TimeBudget/
├── Models/           # SwiftData @Model classes (TimeEntry, HealthSnapshot, etc.)
├── Services/         # One per data source (HealthKit, AniList, LeetCode, etc.)
├── ViewModels/       # @Observable classes for each tab
├── Views/
│   ├── Dashboard/    # Today tab — stats, timeline, pie chart
│   ├── Focus/        # Focus stopwatch
│   ├── Budget/       # Time budget management
│   ├── Insights/     # Trends, heatmaps, correlations, detail views
│   ├── Settings/     # Places, ideal day, accounts, permissions
│   └── Onboarding/   # First-launch flow
└── Utilities/        # Extensions, design system, color helpers
```

**Pattern:** MVVM with a Services layer

**Data flow:** Apple Frameworks → Services → SwiftData → ViewModels → Views

## Battery

The app is designed to minimize battery impact:
- All HealthKit queries run in parallel using `async let`
- Dashboard reloads are throttled to once per 30 seconds
- Historical backfill uses batch range queries (3 queries instead of 120+)
- AniList and LeetCode sync at most once per hour with in-memory caching
- Location uses significant change monitoring and geofencing — no continuous GPS
- Background refresh via `BGAppRefreshTask` for overnight syncs

## License

MIT
