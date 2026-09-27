import SwiftUI
import SwiftData

struct FoodTrackerView: View {
    @StateObject private var vm = FoodViewModel()
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \SavedFood.createdAt, order: .reverse) private var savedFoods: [SavedFood]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workouts: [WorkoutSession]
    @Query(filter: #Predicate<FastingSession> { $0.isActive }) private var activeFasts: [FastingSession]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var health: HealthKitManager

    @State private var showAddFood = false
    @State private var showFastWarning = false
    @State private var pendingMeal: MealType? = nil
    @State private var copiedMessage: String? = nil

    var profile: UserProfile? { profiles.first }
    var calorieTarget: Int { profile?.dailyCalorieTarget ?? 2000 }
    var dayEntries: [FoodEntry] { vm.entriesForDate(vm.selectedDate, all: allEntries) }
    var totals: (calories: Double, protein: Double, carbs: Double, fat: Double) { FoodViewModel.totals(for: dayEntries) }

    var burnedCalories: Int {
        let logged = workouts
            .filter { $0.completed && Calendar.current.isDate($0.date, inSameDayAs: vm.selectedDate) }
            .reduce(0) { $0 + $1.estimatedCalories }
        let fromHealth = Calendar.current.isDateInToday(vm.selectedDate) ? health.todayActiveEnergy : 0
        // Health's active energy already includes workouts it knows about, so take the larger figure
        return max(logged, Int(fromHealth))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DateNavigator(selectedDate: $vm.selectedDate)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: FDSpacing.md, bottom: FDSpacing.sm, trailing: FDSpacing.md))

                    NutritionSummaryCard(
                        consumed: totals.calories,
                        target: Double(calorieTarget),
                        burned: burnedCalories,
                        protein: totals.protein,
                        proteinGoal: Double(profile?.effectiveProteinGoalG ?? 100),
                        carbs: totals.carbs,
                        fat: totals.fat
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: FDSpacing.md, bottom: 0, trailing: FDSpacing.md))
                }
                .listSectionSeparator(.hidden)

                ForEach(MealType.allCases, id: \.rawValue) { meal in
                    mealSection(meal)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        requestAdd(meal: MealType.suggested())
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.fdGreen)
                    }
                    .accessibilityLabel("Add food")
                }
            }
            .sheet(isPresented: $showAddFood, onDismiss: { vm.editingEntry = nil; vm.clearSearch() }) {
                AddFoodView(vm: vm, savedFoods: savedFoods, allEntries: allEntries)
            }
            .alert("You're Fasting", isPresented: $showFastWarning) {
                Button("End Fast & Log") {
                    if let fast = activeFasts.first {
                        FastingViewModel.end(fast, modelContext: modelContext)
                    }
                    openAddFood()
                }
                Button("Log Without Ending") { openAddFood() }
                Button("Cancel", role: .cancel) { pendingMeal = nil }
            } message: {
                if let fast = activeFasts.first {
                    Text("You've been fasting for \(FastingViewModel.formatHours(fast.elapsedHours)). Eating now ends your fast.")
                }
            }
            .overlay(alignment: .bottom) {
                if let copiedMessage {
                    ToastView(message: copiedMessage)
                        .padding(.bottom, FDSpacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let entries = dayEntries.filter { $0.mealType == meal.rawValue }.sorted { $0.date < $1.date }
        Section {
            ForEach(entries) { entry in
                Button {
                    vm.startEditing(entry)
                    showAddFood = true
                } label: {
                    FoodEntryRow(entry: entry, isFavorite: vm.isFavorite(entry, saved: savedFoods))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        withAnimation { vm.delete(entry, modelContext: modelContext) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        vm.toggleFavorite(entry, saved: savedFoods, modelContext: modelContext)
                    } label: {
                        Label("Favorite", systemImage: "star.fill")
                    }
                    .tint(.fdYellow)
                }
                .contextMenu {
                    Button {
                        vm.startEditing(entry)
                        showAddFood = true
                    } label: { Label("Edit", systemImage: "pencil") }
                    Button {
                        vm.toggleFavorite(entry, saved: savedFoods, modelContext: modelContext)
                    } label: {
                        vm.isFavorite(entry, saved: savedFoods)
                            ? Label("Remove Favorite", systemImage: "star.slash")
                            : Label("Add to Favorites", systemImage: "star")
                    }
                    Button {
                        _ = vm.relog(entry, mealType: entry.mealType, modelContext: modelContext)
                        Haptics.success()
                    } label: { Label("Log Again", systemImage: "arrow.clockwise") }
                    Button(role: .destructive) {
                        vm.delete(entry, modelContext: modelContext)
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }

            Button {
                requestAdd(meal: meal)
            } label: {
                Label("Add \(meal.rawValue.lowercased())", systemImage: "plus")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdGreen)
            }
        } header: {
            HStack {
                Image(systemName: meal.icon)
                    .foregroundColor(.fdGreen)
                Text(meal.rawValue)
                    .font(.fdHeadline)
                    .foregroundColor(.fdLabel)
                    .textCase(nil)
                Spacer()
                if !entries.isEmpty {
                    Text("\(Int(entries.reduce(0) { $0 + $1.totalCalories })) kcal")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                        .textCase(nil)
                }
                Menu {
                    Button {
                        let count = vm.copyMealFromPreviousDay(meal, all: allEntries, modelContext: modelContext)
                        showToast(count > 0 ? "Copied \(count) item\(count == 1 ? "" : "s") from the day before" : "Nothing logged for \(meal.rawValue.lowercased()) the day before")
                    } label: {
                        Label("Copy from Previous Day", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.fdSecondaryLabel)
                }
                .accessibilityLabel("\(meal.rawValue) options")
            }
        }
    }

    private func requestAdd(meal: MealType) {
        vm.selectedMealType = meal.rawValue
        pendingMeal = meal
        // Only warn about breaking a fast when logging for today
        if !activeFasts.isEmpty && Calendar.current.isDateInToday(vm.selectedDate) {
            Haptics.warning()
            showFastWarning = true
        } else {
            openAddFood()
        }
    }

    private func openAddFood() {
        if let pendingMeal { vm.selectedMealType = pendingMeal.rawValue }
        pendingMeal = nil
        vm.editingEntry = nil
        showAddFood = true
    }

    private func showToast(_ message: String) {
        withAnimation { copiedMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { copiedMessage = nil }
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
                Haptics.selection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundColor(.fdGreen)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous day")
            Spacer()
            Button {
                selectedDate = Date()
            } label: {
                Text(dateLabel)
                    .font(.fdHeadline)
                    .foregroundColor(.fdLabel)
            }
            .buttonStyle(.plain)
            .accessibilityHint(isToday ? "" : "Jump to today")
            Spacer()
            Button {
                let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                if Calendar.current.startOfDay(for: next) <= Date() {
                    selectedDate = next
                    Haptics.selection()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundColor(isToday ? .fdTertiaryLabel : .fdGreen)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(isToday)
            .accessibilityLabel("Next day")
        }
    }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var dateLabel: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

// MARK: - Summary

struct NutritionSummaryCard: View {
    let consumed: Double
    let target: Double
    let burned: Int
    let protein: Double
    let proteinGoal: Double
    let carbs: Double
    let fat: Double

    var remaining: Double { target - consumed }
    var isOver: Bool { consumed > target }

    var body: some View {
        VStack(spacing: FDSpacing.md) {
            HStack(spacing: FDSpacing.lg) {
                ZStack {
                    FDProgressRing(
                        progress: target > 0 ? consumed / target : 0,
                        lineWidth: 14,
                        color: isOver ? .fdRed : .fdGreen,
                        backgroundColor: Color.fdSecondaryLabel.opacity(0.15)
                    )
                    .frame(width: 116, height: 116)
                    VStack(spacing: 0) {
                        Text("\(Int(abs(remaining)))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(isOver ? .fdRed : .fdLabel)
                            .contentTransition(.numericText())
                        Text(isOver ? "kcal over" : "kcal left")
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isOver ? "\(Int(-remaining)) calories over goal" : "\(Int(remaining)) calories left")

                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    SummaryStat(icon: "fork.knife", label: "Eaten", value: "\(Int(consumed))", color: .fdGreen)
                    SummaryStat(icon: "target", label: "Goal", value: "\(Int(target))", color: .fdSecondaryLabel)
                    SummaryStat(icon: "flame.fill", label: "Burned", value: burned > 0 ? "\(burned)" : "—", color: .fdOrange)
                }
            }

            Divider()

            HStack(spacing: FDSpacing.md) {
                MacroProgress(label: "Protein", value: protein, goal: proteinGoal, color: .fdBlue)
                MacroProgress(label: "Carbs", value: carbs, goal: nil, color: .fdOrange)
                MacroProgress(label: "Fat", value: fat, goal: nil, color: .fdPurple)
            }
        }
        .padding(FDSpacing.md)
        .fdCard()
    }
}

struct SummaryStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: FDSpacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 16)
            Text(label)
                .font(.fdSubheadline)
                .foregroundColor(.fdSecondaryLabel)
            Spacer()
            Text(value)
                .font(.fdHeadline)
                .foregroundColor(.fdLabel)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

struct MacroProgress: View {
    let label: String
    let value: Double
    let goal: Double?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(value))")
                    .font(.fdHeadline)
                    .foregroundColor(.fdLabel)
                Text(goal.map { "/\(Int($0))g" } ?? "g")
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
            Text(label)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int(value)) grams" + (goal.map { " of \(Int($0))" } ?? ""))
    }

    private var fraction: Double {
        if let goal, goal > 0 { return min(1, value / goal) }
        // Without a goal, show the share of a generous 150 g reference
        return min(1, value / 150)
    }
}

// MARK: - Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry
    var isFavorite: Bool = false

    var body: some View {
        HStack(spacing: FDSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdLabel)
                        .lineLimit(1)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.fdYellow)
                            .accessibilityLabel("Favorite")
                    }
                }
                Text([entry.brand, entry.amountLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.fdCaption)
                    .foregroundColor(.fdSecondaryLabel)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.totalCalories)) kcal")
                    .font(.fdSubheadline)
                    .foregroundColor(.fdLabel)
                    .monospacedDigit()
                Text("P \(Int(entry.totalProtein)) · C \(Int(entry.totalCarbs)) · F \(Int(entry.totalFat))")
                    .font(.fdCaption2)
                    .foregroundColor(.fdSecondaryLabel)
            }
        }
        .contentShape(Rectangle())
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.fdSubheadline)
            .foregroundColor(.white)
            .padding(.horizontal, FDSpacing.md)
            .padding(.vertical, FDSpacing.sm + 2)
            .background(.black.opacity(0.8))
            .clipShape(Capsule())
            .accessibilityAddTraits(.isStaticText)
    }
}
