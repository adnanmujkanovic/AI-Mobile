import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        if let profile = profiles.first, profile.onboardingCompleted {
            MainTabView()
        } else {
            OnboardingView()
        }
    }
}

enum AppTab: Int {
    case today, nutrition, fasting, workouts, running
}

/// Lets any screen switch tabs, e.g. the dashboard's fasting card opening the Fasting tab.
private struct SelectTabKey: EnvironmentKey {
    static let defaultValue: (AppTab) -> Void = { _ in }
}

extension EnvironmentValues {
    var selectTab: (AppTab) -> Void {
        get { self[SelectTabKey.self] }
        set { self[SelectTabKey.self] = newValue }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var health: HealthKitManager
    @Query(filter: #Predicate<FastingSession> { $0.isActive }) private var activeFasts: [FastingSession]
    @Query private var profiles: [UserProfile]

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(AppTab.today)

            FoodTrackerView()
                .tabItem { Label("Nutrition", systemImage: "fork.knife") }
                .tag(AppTab.nutrition)

            FastingView()
                .tabItem { Label("Fasting", systemImage: "timer") }
                .tag(AppTab.fasting)

            WorkoutLibraryView()
                .tabItem { Label("Workouts", systemImage: "dumbbell.fill") }
                .tag(AppTab.workouts)

            RunningPlanView()
                .tabItem { Label("Running", systemImage: "figure.run") }
                .tag(AppTab.running)
        }
        .tint(.fdGreen)
        .environment(\.selectTab) { tab in selectedTab = tab }
        .onChange(of: selectedTab) { Haptics.selection() }
        .task {
            if let profile = profiles.first {
                NotificationManager.shared.applyPreferences(from: profile)
            }
            refreshOnForeground()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshOnForeground() }
        }
    }

    private func refreshOnForeground() {
        Task { await health.refreshToday() }
        // Recreate the Live Activity if the system removed it while the fast is still running
        if let fast = activeFasts.first {
            FastingLiveActivity.startOrUpdate(for: fast)
        } else {
            FastingLiveActivity.endOrphans()
        }
    }
}
