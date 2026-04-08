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

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)

            WorkoutLibraryView()
                .tabItem {
                    Label("Workouts", systemImage: "dumbbell.fill")
                }
                .tag(1)

            FoodTrackerView()
                .tabItem {
                    Label("Nutrition", systemImage: "fork.knife")
                }
                .tag(2)

            RunningPlanView()
                .tabItem {
                    Label("Running", systemImage: "figure.run")
                }
                .tag(3)

            FastingView()
                .tabItem {
                    Label("Fasting", systemImage: "timer")
                }
                .tag(4)
        }
        .tint(.fdGreen)
    }
}
