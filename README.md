# FitDrop — iOS Weight Loss Companion

A native iPhone app built with Swift and SwiftUI. FitDrop brings food logging, intermittent fasting, water, workouts, a beginner running plan and weight progress into one app. There is no account, no subscription and no server: all data stays on your iPhone, with optional sync to Apple Health.

---

## Install it on your iPhone (free Apple ID)

You need a Mac with **Xcode 16 or newer** and an iPhone running **iOS 17 or newer**.

1. **Get the code**
   ```bash
   git clone https://github.com/adnanmujkanovic/ai-mobile.git
   cd ai-mobile
   git checkout claude/fitdrop-ios-app-TfQ7Y
   open FitDrop/FitDrop.xcodeproj
   ```
2. **Sign in to Xcode**: *Xcode → Settings → Accounts → +* and add your Apple ID.
3. **Set the team for both app targets**: click the blue **FitDrop** project in the sidebar, then for the **FitDrop** target *and* the **FitDropWidgets** target open *Signing & Capabilities* and choose your Apple ID (Personal Team) under **Team**.
   - If Xcode says the bundle identifier is taken, change `com.adnanmujkanovic.fitdrop` to something unique (for example `com.yourname.fitdrop`) and set the widget's to the same value plus `.widgets`.
4. **Connect your iPhone** with a cable, unlock it, and tap **Trust**. The first time, turn on *Settings → Privacy & Security → Developer Mode* on the iPhone and restart it.
5. Pick your iPhone as the run destination at the top of Xcode and press **⌘R**.
6. On the iPhone, open *Settings → General → VPN & Device Management*, tap your Apple ID and **Trust** it, then open FitDrop.

With a free Apple ID the app works for 7 days before you need to run it from Xcode again. A paid Apple Developer account removes that limit and lets you use TestFlight.

**If signing fails because of HealthKit**: in the FitDrop target's *Signing & Capabilities*, remove the HealthKit capability. Everything except Apple Health sync keeps working.

---

## Features

### Today (dashboard)
- Calories left, eaten, goal and burned, with protein progress
- **Water** tracker with +250 ml / +500 ml buttons and undo
- Live fasting status (stage, time fasted, goal time)
- Steps and active energy from Apple Health (when connected)
- **Weight**: current, lost so far, distance to goal and progress bar; a chart with a 7-entry trend line; weekly rate, projected goal date from your trend, BMI; full weigh-in history with delete
- This week's summary and streaks (food logging, fasting, weigh-ins, running weeks)

### Nutrition
- Search the **Open Food Facts** database as you type, or **scan a barcode** (or type the barcode number)
- Log by **grams** (with the product's serving size as a one-tap option) or by **servings**
- **Recent foods** and **favorites** with one-tap re-logging, **Quick Add** for calories only, and **copy a meal from the previous day**
- Tap any entry to edit it; swipe to delete or favorite
- Calorie ring, protein goal and carbs/fat breakdown per day; browse past days
- If you're fasting, logging food offers to end the fast first

### Fasting
- Protocols 13:11, 16:8, 18:6, 20:4, or custom from 12 to 72 hours
- Start now or **retroactively** ("I started earlier"); edit the start time or goal during a fast
- Large timer, six fasting stages with descriptions, milestone checklist, pause/resume
- **Lock Screen Live Activity and Dynamic Island** timer
- Notifications at 12h, 16h and 18h, one hour before the goal, and at the goal (only for the fast you're doing)
- History with a chart and swipe-to-delete, 7-day average and streak

### Workouts
- Treadmill interval workouts and mat workouts with calorie estimates scaled to your weight
- Live session: intervals **advance automatically** with sound and haptics, timed holds, rest countdowns with skip, pause/resume, and the screen stays awake
- End early to save the time you trained (calories are prorated), or discard
- Recent workouts list; finished workouts are saved to Apple Health

### Running
- 4-week plan that builds on an easy 5K, with an **Up Next** card
- Tick sessions off (and undo mistakes), monthly calendar, total distance, weekly streak
- Log runs outside the plan with distance, time and pace

### Profile & Settings
- Sex, age, height and activity level for an accurate calorie target (Mifflin-St Jeor with a capped, safe deficit); optional custom calorie, protein and water targets
- Fasting start time, daily fasting reminder, milestone alerts, evening food-log reminder, workout reminders
- **Apple Health** sync: writes weight, water, food energy and macros, and workouts; reads steps and active energy
- **CSV export** of all your data, and delete-all

### Onboarding
Five short steps: name, body data, current and goal weight (with healthy-goal checks), goal date (warns if the pace needs more than 1 kg a week and suggests a sustainable date), and activity level.

---

## Tech Stack

| Area | Technology |
|------|-----------|
| Language | Swift 5 language mode |
| UI | SwiftUI, Swift Charts |
| Data | SwiftData (on device) |
| Live Activity | ActivityKit + WidgetKit extension |
| Health | HealthKit (optional) |
| Camera | AVFoundation barcode scanning |
| Notifications | UserNotifications |
| Food data | Open Food Facts API (no key required) |
| Tests | Swift Testing unit tests, XCTest UI tests |
| Platform | iPhone, iOS 17+, light and dark mode |

---

## Project Structure

```
FitDrop/
├── FitDrop.xcodeproj
├── FitDrop/                      # The app
│   ├── FitDropApp.swift          # App entry, SwiftData container
│   ├── ContentView.swift         # Root view, tab bar, tab switching
│   ├── Models/                   # UserProfile, FoodEntry + SavedFood, FastingSession,
│   │                             # WorkoutSession, RunSession + WeightLog, WaterLog
│   ├── ViewModels/               # Dashboard, Food, Fasting, Workout, RunningPlan, Onboarding
│   ├── Views/                    # Dashboard, Food, Fasting, Workout, Running, Settings, Onboarding
│   ├── Services/                 # Open Food Facts, notifications, HealthKit,
│   │                             # Live Activity, CSV export
│   └── Utilities/                # Design system, calorie math, streaks, number parsing,
│                                 # haptics, debug demo data
├── FitDropWidgets/               # Live Activity (Lock Screen + Dynamic Island)
├── Shared/                       # Live Activity data shared by app and widget
├── FitDropTests/                 # Unit tests (Swift Testing)
└── FitDropUITests/               # End-to-end UI tests
```

---

## Development

Run the tests from Xcode with **⌘U**, or from the terminal:

```bash
cd FitDrop
xcodebuild test -project FitDrop.xcodeproj -scheme FitDrop \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Demo data** (Debug builds only): add the launch arguments `-FitDropDemo YES` to fill an empty install with a month of sample data, and `-FitDropTab fasting` (or `today`, `nutrition`, `workouts`, `running`) to open a tab. `-FitDropReset YES` deletes everything at launch. Set these in *Product → Scheme → Edit Scheme → Run → Arguments*.

---

## Data & Privacy

- Everything is stored in SwiftData on the device. There's no account, analytics or backend.
- The only network calls go to Open Food Facts when you search or scan food. Food data © Open Food Facts contributors, under the [Open Database License](https://opendatacommons.org/licenses/odbl/1-0/).
- Apple Health sync is off until you turn it on, and you control each data type in the Health app.

| Permission | Why |
|-----------|-----|
| Camera | Scanning food barcodes |
| Notifications | Fasting milestones and reminders you turn on |
| Apple Health | Optional sync of weight, water, food and workouts |

FitDrop isn't a medical device. Fasting and calorie restriction aren't right for everyone; talk to a doctor first if you're pregnant, diabetic, take medication or have a history of eating disorders.
