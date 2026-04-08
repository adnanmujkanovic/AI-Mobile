import SwiftUI
import SwiftData

struct FoodTrackerView: View {
    @StateObject private var vm = FoodViewModel()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddFood = false
    @State private var showScanner = false
    @State private var showEatingWindowWarning = false

    var profile: UserProfile? { profiles.first }

    var dailyStats: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        vm.dailyStats(entries: allEntries)
    }

    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 2000 }

    var todayEntries: [FoodEntry] {
        vm.entriesForDate(vm.selectedDate, all: allEntries)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: FDSpacing.lg) {
                    // Date Picker
                    DateNavigator(selectedDate: $vm.selectedDate)
                        .padding(.horizontal, FDSpacing.md)

                    // Calorie Ring Card
                    CalorieRingCard(
                        consumed: dailyStats.calories,
                        target: Double(calorieTarget)
                    )
                    .padding(.horizontal, FDSpacing.md)

                    // Macros Card
                    MacroBreakdownCard(
                        protein: dailyStats.protein,
                        carbs: dailyStats.carbs,
                        fat: dailyStats.fat
                    )
                    .padding(.horizontal, FDSpacing.md)

                    // Meals by type
                    ForEach(MealType.allCases, id: \.rawValue) { meal in
                        let mealEntries = todayEntries.filter { $0.mealType == meal.rawValue }
                        if !mealEntries.isEmpty {
                            MealSection(
                                meal: meal,
                                entries: mealEntries,
                                onDelete: { entry in
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                }
                            )
                            .padding(.horizontal, FDSpacing.md)
                        }
                    }

                    if todayEntries.isEmpty {
                        EmptyFoodLogView()
                            .padding(.horizontal, FDSpacing.md)
                    }

                    Spacer(minLength: FDSpacing.xl)
                }
                .padding(.vertical, FDSpacing.md)
            }
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            checkEatingWindow { showScanner = true }
                        } label: {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button {
                            checkEatingWindow { showAddFood = true }
                        } label: {
                            Label("Search Food", systemImage: "magnifyingglass")
                        }
                        Button {
                            checkEatingWindow {
                                vm.startManualEntry()
                                showAddFood = true
                            }
                        } label: {
                            Label("Manual Entry", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.fdGreen)
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView { barcode in
                    vm.handleBarcode(barcode)
                    showScanner = false
                    showAddFood = true
                }
            }
            .sheet(isPresented: $showAddFood) {
                FoodSearchView(vm: vm)
                    .environment(\.modelContext, modelContext)
            }
            .alert("Outside Eating Window", isPresented: $showEatingWindowWarning) {
                Button("Log Anyway") { showAddFood = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You're currently in your fasting window. Logging food would break your fast.")
            }
        }
    }

    private func checkEatingWindow(action: () -> Void) {
        if !vm.isWithinEatingWindow(profile: profile) {
            showEatingWindowWarning = true
        } else {
            action()
        }
    }
}

// MARK: - Date Navigator

struct DateNavigator: View {
    @Binding var selectedDate: Date

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.fdGreen)
            }
            Spacer()
            Text(dateLabel)
                .font(.fdHeadline)
            Spacer()
            Button {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                if tomorrow <= Date() {
                    selectedDate = tomorrow
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(isToday ? .fdTertiaryLabel : .fdGreen)
            }
            .disabled(isToday)
        }
    }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var dateLabel: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: selectedDate)
    }
}

// MARK: - Calorie Ring Card

struct CalorieRingCard: View {
    let consumed: Double
    let target: Double

    var progress: Double { min(1.0, target > 0 ? consumed / target : 0) }
    var remaining: Double { max(0, target - consumed) }
    var isOver: Bool { consumed > target }

    var body: some View {
        HStack(spacing: FDSpacing.xl) {
            // Ring
            ZStack {
                FDProgressRing(
                    progress: progress,
                    lineWidth: 14,
                    color: isOver ? .fdRed : .fdGreen,
                    backgroundColor: Color.fdSecondaryLabel.opacity(0.2)
                )
                .frame(width: 120, height: 120)
                VStack(spacing: 2) {
                    Text("\(Int(consumed))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(isOver ? .fdRed : .fdLabel)
                    Text("kcal")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
            }

            VStack(alignment: .leading, spacing: FDSpacing.md) {
                CalorieRingStat(label: "Goal", value: "\(Int(target))", color: .fdSecondaryLabel)
                CalorieRingStat(label: isOver ? "Over" : "Left", value: "\(Int(remaining))", color: isOver ? .fdRed : .fdGreen)
                CalorieRingStat(label: "Burned", value: "—", color: .fdOrange)
            }
        }
        .padding(FDSpacing.lg)
        .fdCard()
        .fdShadow()
    }
}

struct CalorieRingStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.fdSubheadline)
                .foregroundColor(.fdSecondaryLabel)
            Spacer()
            Text(value)
                .font(.fdHeadline)
                .foregroundColor(color)
        }
    }
}

// MARK: - Macro Breakdown

struct MacroBreakdownCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var total: Double { protein * 4 + carbs * 4 + fat * 9 }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.md) {
            Text("MACROS")
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .tracking(1)

            HStack(spacing: FDSpacing.md) {
                MacroBar(label: "Protein", value: protein, unit: "g", color: .fdBlue, fraction: total > 0 ? (protein * 4) / total : 0)
                MacroBar(label: "Carbs", value: carbs, unit: "g", color: .fdOrange, fraction: total > 0 ? (carbs * 4) / total : 0)
                MacroBar(label: "Fat", value: fat, unit: "g", color: .fdPurple, fraction: total > 0 ? (fat * 9) / total : 0)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow()
    }
}

struct MacroBar: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    let fraction: Double

    var body: some View {
        VStack(spacing: FDSpacing.xs) {
            Text(String(format: "%.0f", value) + unit)
                .font(.fdHeadline)
                .foregroundColor(.fdLabel)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geo.size.height * fraction)
                }
            }
            .frame(height: 50)
            Text(label)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meal Section

struct MealSection: View {
    let meal: MealType
    let entries: [FoodEntry]
    let onDelete: (FoodEntry) -> Void

    var totalCals: Double { entries.reduce(0) { $0 + $1.totalCalories } }

    var body: some View {
        VStack(alignment: .leading, spacing: FDSpacing.sm) {
            HStack {
                Image(systemName: meal.icon)
                    .foregroundColor(.fdGreen)
                Text(meal.rawValue)
                    .font(.fdHeadline)
                Spacer()
                Text("\(Int(totalCals)) kcal")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdSecondaryLabel)
            }
            ForEach(entries) { entry in
                FoodEntryRow(entry: entry, onDelete: { onDelete(entry) })
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
        .fdShadow(radius: 4)
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                if !entry.brand.isEmpty {
                    Text(entry.brand)
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                }
                Text("\(String(format: "%.0f", entry.servingAmount))× \(entry.servingDescription)")
                    .font(.fdCaption)
                    .foregroundColor(.fdTertiaryLabel)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.totalCalories)) kcal")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                Text("P:\(Int(entry.totalProtein))g C:\(Int(entry.totalCarbs))g F:\(Int(entry.totalFat))g")
                    .font(.fdCaption2)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct EmptyFoodLogView: View {
    var body: some View {
        VStack(spacing: FDSpacing.md) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 50))
                .foregroundColor(.fdTertiaryLabel)
            Text("No food logged today")
                .font(.fdHeadline)
                .foregroundColor(.fdSecondaryLabel)
            Text("Tap + to log your meals")
                .font(.fdSubheadline)
                .foregroundColor(.fdTertiaryLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(FDSpacing.xxl)
    }
}
