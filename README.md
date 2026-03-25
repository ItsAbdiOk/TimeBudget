# TimeBudget

A passive time tracking app for iOS that automatically builds a complete picture of your day — from sleep and exercise to deep work and manga reading. No manual logging. Budget your time like you'd budget money.

All data stays on-device. No backend. No accounts.

## What It Does

TimeBudget pulls data from 7+ sources in real time and stitches them into a single timeline:

| Source | What It Tracks |
|--------|---------------|
| **Apple Watch / HealthKit** | Sleep (with stages), steps, workouts, active calories |
| **Core Motion** | Walking, running, cycling, driving, stationary detection |
| **Core Location** | Saved places (home, work, gym) with geofencing |
| **EventKit** | Calendar meetings with duration |
| **ActivityWatch** | Mac + iPhone screen time — apps, websites, productivity tiers |
| **AniList** | Manga reading (chapter counts, estimated reading time) |
| **Pocket Casts** | Podcast listening history |

### Multi-Device Screen Time

The app bridges the iOS sandbox gap by reading iPhone Screen Time data through a Mac relay:

1. `aw-import-screentime` on your Mac reads iCloud Biome data (iOS Screen Time)
2. Pushes it to your local ActivityWatch server
3. The iOS app fetches both Mac and iPhone buckets concurrently
4. Device filter pills let you view All Devices / Mac / iPhone separately

Includes a setup script (`scripts/screentime-bridge-setup.sh`) that automates installation and creates a launchd plist for hourly imports.

### On-Device AI Categorization

On iOS 26+ devices with Apple Intelligence, the app uses the on-device foundation model to refine activity categories. Deep Work sessions get validated, ambiguous browser time gets properly classified, and AI-refined entries are marked with a brain badge in the timeline.

## Tabs

### Today
- Personalized greeting with time-of-day context
- Daily score (0-100) based on your ideal day targets
- Mini stats: steps, sleep, exercise with trend deltas
- Category breakdown bar showing time per activity type
- Full timeline with app/site names, colored category labels, source chips, and AI badges
- Contextual daily insight

### Focus
Manual stopwatch for activities that aren't auto-tracked:
- Manga, LeetCode, Learning, Coding, Yoga
- Sessions persist through app backgrounding

### Budget
- Set daily time targets per category (Deep Work: 4h, Exercise: 1h, etc.)
- Track actual vs. budgeted time with progress bars
- Daily score computed from how close you hit your ideal day

### Insights
- **Desk Time** — Productivity score, daily/weekly toggle, visual timeline bar, device-aware app and website breakdowns, session list with AI refinement badges, 84-day heatmap
- **30-day trends** — Rolling averages for sleep, steps, exercise, reading
- **Week vs week** — Side-by-side comparison with deltas
- **Contribution heatmaps** — GitHub-style calendars for activity, manga, LeetCode, podcasts, and desk time
- **Correlations** — Patterns like "more sleep = more steps" from 90 days of data
- **Detail views** — Tap any section for deeper analytics with charts

### Settings
- Save and label places on a map
- Configure your ideal day with per-category targets
- Connect integrations (AniList, Pocket Casts, ActivityWatch)
- Apple Intelligence categorization toggle
- Manage permissions (Health, Location, Calendar, Motion)

## Architecture

```
TimeBudget/
├── Models/           # SwiftData @Model classes (TimeEntry, HealthSnapshot, etc.)
├── Services/         # One per data source (HealthKit, AniList, ActivityWatch, etc.)
├── ViewModels/       # @Observable classes for each tab
├── Views/
│   ├── Dashboard/    # Today tab — score, stats, timeline
│   ├── Focus/        # Focus stopwatch
│   ├── Budget/       # Time budget management
│   ├── Insights/     # Trends, heatmaps, correlations, desk time
│   ├── Settings/     # Places, ideal day, integrations, permissions
│   └── Onboarding/   # First-launch flow
└── Utilities/        # Extensions, design system, Keychain manager
```

**Pattern:** MVVM with a Services layer

**Data flow:** Apple Frameworks / APIs -> Services -> SwiftData -> ViewModels -> Views

## Battery

Designed to minimize battery impact:
- All HealthKit queries run in parallel using `async let`
- Dashboard reloads throttled to once per 30 seconds
- External API syncs (AniList, Pocket Casts) throttled to once per hour
- ActivityWatch uses 5-second timeout — never freezes when away from home WiFi
- ActivityWatch bucket discovery cached for 1 hour
- Location uses significant change monitoring and geofencing — no continuous GPS
- Background refresh via `BGAppRefreshTask` for overnight syncs

## Requirements

- iPhone running iOS 17+ (iOS 26+ for on-device AI)
- Apple Watch (for sleep and workout tracking)
- Xcode 15+
- Mac with ActivityWatch (optional, for desktop tracking)

## Setup

1. Clone and open in Xcode:
   ```bash
   git clone https://github.com/ItsAbdiOk/TimeBudget.git
   ```

2. Select your development team under **Signing & Capabilities**

3. Build and run on your iPhone (Simulator won't have HealthKit data)

4. Grant permissions when prompted (Health, Location, Calendar, Motion)

5. Optionally connect integrations in **Settings**:
   - **AniList** — Enter your username
   - **Pocket Casts** — Log in with your account
   - **ActivityWatch** — Enter your Mac's local IP address

6. For iPhone Screen Time on your Mac (optional):
   ```bash
   ./scripts/screentime-bridge-setup.sh
   ```
   Requires Full Disk Access for Terminal and ActivityWatch running on the Mac.

> **Note:** With a free Apple Developer account, the app expires every 7 days and needs to be re-deployed from Xcode.

## License

MIT
