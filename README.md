# TimeBudget

**A passive time tracking app for iOS that builds a complete picture of your day — no manual logging.**

Budget your time like you'd budget money. TimeBudget pulls from 7+ sources in real time and stitches them into a single timeline. Sleep stages from your Apple Watch, deep work sessions from your Mac, podcast listening, manga reading, calendar meetings — all unified in one view.

All data stays on-device. No backend. No accounts. No cloud sync.

---

## The Problem

Time tracking apps require manual input, and manual input doesn't last. The moment you forget to start a timer, the data is useless. TimeBudget takes a different approach: it passively collects everything your devices already know about your day and presents it as one coherent timeline.

---

## Data Sources

| Source | What It Tracks |
|:-------|:---------------|
| HealthKit | Sleep with stages, steps, workouts, active calories |
| Core Motion | Walking, running, cycling, driving, stationary detection |
| Core Location | Saved places — home, work, gym — with geofencing |
| EventKit | Calendar meetings with duration |
| ActivityWatch | Mac and iPhone screen time, apps, websites, productivity tiers |
| AniList | Manga chapters and estimated reading time |
| Pocket Casts | Podcast listening history |
| LeetCode | Coding practice sessions |

---

## Features

### Today — the daily dashboard
Personalized greeting, daily score (0–100) against your ideal day, mini stats with trend deltas, category breakdown bar, and a full timeline with app names, source chips, and AI badges.

### Budget — set targets, track actuals
Define your ideal day — 4h deep work, 1h exercise, 8h sleep — and see how reality compares. Progress bars per category, with a composite score.

### Insights — patterns over time
30-day rolling averages. Week-over-week comparisons. GitHub-style contribution heatmaps for activity, reading, coding, and desk time. Correlation detection across 90 days of data — things like "more sleep correlates with more steps."

### Desk Time — multi-device screen time
Bridges the iOS sandbox by relaying iPhone Screen Time data through a Mac:

1. `aw-import-screentime` on Mac reads iCloud Biome data
2. Pushes to local ActivityWatch server
3. iOS app fetches Mac and iPhone buckets concurrently
4. Device filter pills: All Devices / Mac / iPhone

### On-Device AI — iOS 26+
Apple Intelligence refines activity categories on-device. Ambiguous browser sessions get properly classified. AI-refined entries are marked with a brain badge in the timeline.

---

## Architecture

```
TimeBudget/
├── Models/           SwiftData @Model classes
├── Services/         One per data source — HealthKit, AniList, ActivityWatch, etc.
├── ViewModels/       @Observable classes, one per tab
├── Views/
│   ├── Dashboard/    Today — score, stats, timeline
│   ├── Focus/        Manual stopwatch for untracked activities
│   ├── Budget/       Time budget management
│   ├── Insights/     Trends, heatmaps, correlations, desk time
│   ├── Settings/     Places, ideal day, integrations, permissions
│   └── Onboarding/   First-launch flow
└── Utilities/        Design system, extensions, Keychain manager
```

**Pattern** — MVVM with a centralized Services layer.
All HealthKit queries run in parallel via `async let`. Dashboard reloads throttled to 30s. External API syncs throttled to 1h. Location uses significant change monitoring and geofencing only — no continuous GPS.

---

## Tech Stack

| | |
|:--|:--|
| Language | Swift 5 |
| UI | SwiftUI |
| Storage | SwiftData (on-device) |
| Minimum | iOS 17+ (iOS 26+ for Apple Intelligence) |
| Frameworks | HealthKit, Core Motion, Core Location, EventKit |
| Integrations | ActivityWatch, AniList API, Pocket Casts, LeetCode |

---

## Setup

```bash
git clone https://github.com/ItsAbdiOk/TimeBudget.git
```

1. Open in Xcode, select your development team under Signing & Capabilities
2. Build and run on iPhone — Simulator lacks HealthKit data
3. Grant permissions when prompted
4. Connect integrations in Settings (AniList username, Pocket Casts login, ActivityWatch IP)
5. Optional — iPhone Screen Time relay: `./scripts/screentime-bridge-setup.sh`

> Free Apple Developer accounts require re-deploying from Xcode every 7 days.

---

## License

MIT

---

*Built by [Abdirahman Mohamed](https://abdirahmanmohamed.dev)*
