# FitDrop — iOS Weight Loss Companion

A native iPhone app built with Swift & SwiftUI. FitDrop combines workout tracking, food logging, a structured running plan, intermittent fasting, and a progress dashboard into one clean, motivating experience — no account or backend required.

---

## Screenshots & Modules

| Onboarding | Dashboard | Workout |
|---|---|---|
| Multi-step setup | Weight chart + streaks | Treadmill & mat library |

| Food Tracker | Running Plan | Fasting |
|---|---|---|
| Barcode scanner + macros | 4-week 5K build | Live countdown timer |

---

## Features

### Onboarding
- Collects name, current weight, goal weight, goal date, activity level
- Calculates personalised daily calorie target using the **Mifflin-St Jeor BMR** formula with TDEE multiplier and a safe calorie deficit (max 750 kcal/day, floor 1,200 kcal)
- Stores everything locally — no account required

### Module 1 — Workout Library
**Treadmill workouts**
- Speed Intervals, Steady State, Incline Walk, Tempo Run, Pyramid Intervals
- Speed zones: Easy (6–7 km/h), Tempo (8–9 km/h), Interval (10–11 km/h)
- Each workout shows duration, estimated calories, visual intensity strip

**Mat workouts**
- Core Crusher, Lower Body Burn, Upper Body Strength, Full Body Circuit, Glute & Core
- Sets × reps with rest countdowns between each set

**Live session mode**
- Active timer with interval/set tracking
- Rest countdown with audio cue on completion
- Session summary: total time + estimated calories burned
- Every completed session saved to workout history

### Module 2 — Food Scanner & Calorie Tracker
- **Barcode scanner** using AVFoundation (EAN-8, EAN-13, UPC-E, QR, Code128)
- **Open Food Facts API** for product lookup — free, no API key needed
- Manual food search and fully manual entry fallback
- Edit portion size before logging
- Daily dashboard: calorie ring (consumed vs. goal), macro breakdown (protein / carbs / fat)
- Organised by meal: Breakfast, Lunch, Dinner, Snack
- Swipe to delete entries
- **Fasting window integration** — warns if you try to log food during your fast

### Module 3 — Running Plan ("5-Day Build")
4-week progressive plan for someone currently running 5K at a slow pace:

| Week | Days/Week | Focus |
|------|-----------|-------|
| 1 | 3 | Easy 5K runs — build the habit |
| 2 | 3–4 | Introduce interval session |
| 3 | 4 | Add tempo run, increase distance |
| 4 | 5 | Long run (6.5K), intervals, structured rest |

- Each session shows distance, pace zone, treadmill speed (km/h), estimated duration
- Tap checkmark to mark complete
- Weekly progress bar, monthly calendar with completed runs highlighted
- Running streak counter

### Module 4 — Progress Dashboard
- Daily weight logging with date
- Weight loss line chart (iOS Charts framework) with goal weight target line — last 30 entries
- Weekly summary card: workouts completed, average calories, runs, average fasting hours
- Streak trackers: running days, fasting days, food logging days, weigh-in days

### Module 5 — Intermittent Fasting Tracker
**Protocols:** 16:8, 18:6, 20:4, Custom

**Active fast screen**
- Large countdown timer (elapsed + remaining)
- Animated progress arc
- 6 fasting stages with descriptions:

| Hours | Stage |
|-------|-------|
| 0–4h | Digestion |
| 4–8h | Fat Burning Begins |
| 8–12h | Glucose Depletion |
| 12–16h | Ketosis Zone |
| 16–18h | Autophagy |
| 18h+ | Deep Fast |

- One-tap Start / Pause / Resume / Break Fast
- Broken fasts log actual hours achieved

**History & stats**
- List of all fasts: date, planned vs. actual hours
- Weekly average fasting hours
- Consecutive fasting streak

**Push notifications**
- Fast starts
- Eating window opens
- 12h ketosis milestone
- 16h autophagy milestone
- 1 hour before eating window closes

---

## Tech Stack

| Area | Technology |
|------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Data | SwiftData (local, no backend) |
| Camera | AVFoundation |
| Charts | Swift Charts (iOS 17) |
| Notifications | UserNotifications |
| External API | Open Food Facts (no key required) |
| Architecture | MVVM |
| Platform | iPhone only, iOS 17+ |
| Dark Mode | Supported |

---

## Project Structure

```
FitDrop/
├── FitDrop.xcodeproj/
└── FitDrop/
    ├── FitDropApp.swift              # App entry, SwiftData container
    ├── ContentView.swift             # RootView + 5-tab navigation
    ├── Info.plist                    # Camera + notification permissions
    ├── Assets.xcassets/              # AccentColor, AppIcon
    │
    ├── Models/
    │   ├── UserProfile.swift         # User data, calorie target, fasting config
    │   ├── WorkoutSession.swift      # Workout history + full library data
    │   ├── FoodEntry.swift           # Food log + Open Food Facts models
    │   ├── FastingSession.swift      # Fasting timer state + stage logic
    │   └── RunSession.swift          # Run history + WeightLog + 4-week plan
    │
    ├── ViewModels/
    │   ├── OnboardingViewModel.swift
    │   ├── WorkoutViewModel.swift    # Session timer, interval tracking
    │   ├── FoodViewModel.swift       # Search, barcode, logging
    │   ├── FastingViewModel.swift    # Fast timer, pause/resume, streaks
    │   ├── RunningPlanViewModel.swift
    │   └── DashboardViewModel.swift  # Weekly stats, streaks, projections
    │
    ├── Views/
    │   ├── Onboarding/OnboardingView.swift
    │   ├── Workout/
    │   │   ├── WorkoutLibraryView.swift
    │   │   ├── WorkoutDetailView.swift
    │   │   └── WorkoutSessionView.swift
    │   ├── Food/
    │   │   ├── FoodTrackerView.swift
    │   │   ├── BarcodeScannerView.swift
    │   │   └── FoodSearchView.swift
    │   ├── Running/RunningPlanView.swift
    │   ├── Dashboard/DashboardView.swift
    │   └── Fasting/
    │       ├── FastingView.swift
    │       └── FastingHistoryView.swift
    │
    ├── Services/
    │   ├── OpenFoodFactsService.swift  # async/await API client
    │   └── NotificationManager.swift  # Scheduling all local notifications
    │
    └── Utilities/
        ├── DesignSystem.swift          # Colors, fonts, reusable components
        └── CalorieCalculator.swift     # BMR, TDEE, calorie target
```

---

## Data Models (SwiftData)

```swift
UserProfile     // name, weights, goal date, activity level, fasting config, calorie target
WorkoutSession  // date, name, type, duration, calories, completed
FoodEntry       // date, name, brand, macros, serving size, meal type, barcode
FastingSession  // start/end time, planned hours, actual hours, pause state
RunSession      // plan week/day, distance, duration, pace zone, completion
WeightLog       // date, weight (kg)
```

All data is stored **100% locally** using SwiftData. No server, no account, no network required (except food search).

---

## Getting Started

### Requirements
- Mac with **Xcode 15+**
- iPhone running **iOS 17+**
- Free Apple ID (for device testing)

### Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/adnanmujkanovic/ai-mobile.git
   cd ai-mobile
   git checkout claude/fitdrop-ios-app-TfQ7Y
   ```

2. **Open in Xcode**
   ```
   open FitDrop/FitDrop.xcodeproj
   ```

3. **Set your Development Team**
   - Select the `FitDrop` target → Signing & Capabilities
   - Choose your Apple ID under Team

4. **Connect your iPhone** via USB and select it as the build target

5. **Run** with `⌘R`

6. **First run on device** — go to:
   ```
   iPhone Settings → General → VPN & Device Management → [Your Apple ID] → Trust
   ```

### No Mac? Use a cloud Mac
- [MacinCloud](https://www.macincloud.com) — pay-per-hour remote Mac access
- Build the app there and distribute via **TestFlight** to your iPhone

---

## External API

**Open Food Facts** — `https://world.openfoodfacts.org/api`
- Free, open database of food products worldwide
- No API key required
- Used for barcode product lookup and food name search
- Returns: product name, brand, calories, protein, carbs, fat, fibre per 100g

---

## Permissions

| Permission | Usage |
|-----------|-------|
| Camera | Barcode scanning in food tracker |
| Notifications | Fasting reminders, workout reminders, food log reminder |

---

## Branch

All code lives on branch: `claude/fitdrop-ios-app-TfQ7Y`
