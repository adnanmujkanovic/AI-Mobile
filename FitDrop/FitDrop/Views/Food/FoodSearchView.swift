import SwiftUI
import SwiftData

struct FoodSearchView: View {
    @ObservedObject var vm: FoodViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let draft = vm.editingEntry {
                    FoodEntryEditView(vm: vm, draft: draft)
                        .environment(\.modelContext, modelContext)
                } else {
                    foodSearchContent
                }
            }
            .navigationTitle(vm.editingEntry == nil ? "Add Food" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        vm.editingEntry = nil
                        vm.scannedProduct = nil
                        vm.searchResults = []
                        dismiss()
                    }
                }
            }
        }
    }

    var foodSearchContent: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: FDSpacing.sm) {
                HStack(spacing: FDSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.fdSecondaryLabel)
                    TextField("Search food name...", text: $vm.searchQuery)
                        .submitLabel(.search)
                        .onSubmit { vm.searchFood() }
                    if !vm.searchQuery.isEmpty {
                        Button {
                            vm.searchQuery = ""
                            vm.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.fdSecondaryLabel)
                        }
                    }
                }
                .padding(FDSpacing.sm)
                .background(Color.fdSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: FDRadius.sm))

                Button {
                    vm.searchFood()
                } label: {
                    Text("Search")
                        .font(.fdSubheadline)
                        .foregroundColor(.fdGreen)
                }
            }
            .padding(FDSpacing.md)

            // Meal picker
            Picker("Meal", selection: $vm.selectedMealType) {
                ForEach(MealType.allCases, id: \.rawValue) { m in
                    Text(m.rawValue).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, FDSpacing.md)
            .padding(.bottom, FDSpacing.sm)

            Divider()

            if vm.isSearching {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if let error = vm.errorMessage {
                Spacer()
                VStack(spacing: FDSpacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.fdOrange)
                    Text(error)
                        .font(.fdBody)
                        .foregroundColor(.fdSecondaryLabel)
                        .multilineTextAlignment(.center)
                }
                .padding(FDSpacing.xl)
                Spacer()
            } else if vm.searchResults.isEmpty && vm.searchQuery.isEmpty {
                Spacer()
                VStack(spacing: FDSpacing.lg) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.fdGreen.opacity(0.5))
                    VStack(spacing: FDSpacing.sm) {
                        Text("Search the Food Database")
                            .font(.fdTitle3)
                        Text("Type a food name above, or use barcode scan from the main screen")
                            .font(.fdSubheadline)
                            .foregroundColor(.fdSecondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        vm.startManualEntry()
                    } label: {
                        Label("Enter Manually", systemImage: "pencil")
                            .font(.fdHeadline)
                            .foregroundColor(.fdGreen)
                    }
                }
                .padding(FDSpacing.xl)
                Spacer()
            } else {
                List(vm.searchResults) { product in
                    FoodSearchResultRow(product: product) {
                        vm.selectProduct(product)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

struct FoodSearchResultRow: View {
    let product: OFFProduct
    let onSelect: () -> Void

    var calories: Int {
        Int(product.nutriments?.energyKcal100g ?? 0)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FDSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdLabel)
                        .lineLimit(2)
                    if !product.displayBrand.isEmpty {
                        Text(product.displayBrand)
                            .font(.fdCaption)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(calories)")
                        .font(.fdHeadline)
                        .foregroundColor(.fdLabel)
                    Text("kcal/100g")
                        .font(.fdCaption2)
                        .foregroundColor(.fdSecondaryLabel)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.fdTertiaryLabel)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Food Entry Edit

struct FoodEntryEditView: View {
    @ObservedObject var vm: FoodViewModel
    @State var draft: FoodViewModel.FoodEntryDraft
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    init(vm: FoodViewModel, draft: FoodViewModel.FoodEntryDraft) {
        self.vm = vm
        _draft = State(initialValue: draft)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FDSpacing.lg) {
                // Product Info
                VStack(alignment: .leading, spacing: FDSpacing.sm) {
                    Text("PRODUCT")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .tracking(1)
                    TextField("Food name", text: $draft.name)
                        .font(.fdHeadline)
                    TextField("Brand (optional)", text: $draft.brand)
                        .font(.fdSubheadline)
                        .foregroundColor(.fdSecondaryLabel)
                }
                .padding(FDSpacing.md)
                .fdCard()
                .padding(.horizontal, FDSpacing.md)

                // Serving Size
                VStack(alignment: .leading, spacing: FDSpacing.md) {
                    Text("SERVING")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .tracking(1)

                    HStack {
                        Text("Amount")
                            .font(.fdSubheadline)
                        Spacer()
                        TextField("1.0", value: $draft.servingAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.fdHeadline)
                            .frame(width: 80)
                        Text("×")
                            .foregroundColor(.fdSecondaryLabel)
                        Text(draft.servingDescription)
                            .font(.fdSubheadline)
                            .foregroundColor(.fdSecondaryLabel)
                    }
                }
                .padding(FDSpacing.md)
                .fdCard()
                .padding(.horizontal, FDSpacing.md)

                // Nutrition per 100g
                VStack(alignment: .leading, spacing: FDSpacing.md) {
                    Text("NUTRITION (per 100g)")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .tracking(1)

                    NutritionInputRow(label: "Calories", value: $draft.calories, unit: "kcal", color: .fdOrange)
                    NutritionInputRow(label: "Protein", value: $draft.protein, unit: "g", color: .fdBlue)
                    NutritionInputRow(label: "Carbs", value: $draft.carbs, unit: "g", color: .fdYellow)
                    NutritionInputRow(label: "Fat", value: $draft.fat, unit: "g", color: .fdPurple)
                    NutritionInputRow(label: "Fiber", value: $draft.fiber, unit: "g", color: .fdGreen)
                }
                .padding(FDSpacing.md)
                .fdCard()
                .padding(.horizontal, FDSpacing.md)

                // Totals
                VStack(alignment: .leading, spacing: FDSpacing.md) {
                    Text("TOTAL FOR THIS SERVING")
                        .font(.fdCaption)
                        .foregroundColor(.fdSecondaryLabel)
                        .tracking(1)

                    HStack(spacing: FDSpacing.md) {
                        NutritionTotal(label: "Calories", value: draft.totalCalories, unit: "kcal", color: .fdOrange)
                        NutritionTotal(label: "Protein", value: draft.totalProtein, unit: "g", color: .fdBlue)
                        NutritionTotal(label: "Carbs", value: draft.totalCarbs, unit: "g", color: .fdYellow)
                        NutritionTotal(label: "Fat", value: draft.totalFat, unit: "g", color: .fdPurple)
                    }
                }
                .padding(FDSpacing.md)
                .fdCard()
                .padding(.horizontal, FDSpacing.md)

                // Log button
                FDPrimaryButton("Log Food", icon: "plus.circle.fill") {
                    vm.editingEntry = draft
                    vm.logFood(modelContext: modelContext)
                    dismiss()
                }
                .padding(.horizontal, FDSpacing.md)
                .padding(.bottom, FDSpacing.xl)
            }
            .padding(.top, FDSpacing.md)
        }
    }
}

struct NutritionInputRow: View {
    let label: String
    @Binding var value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.fdSubheadline)
                .foregroundColor(.fdLabel)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.fdSubheadline)
                .frame(width: 70)
            Text(unit)
                .font(.fdCaption)
                .foregroundColor(.fdSecondaryLabel)
                .frame(width: 30)
        }
    }
}

struct NutritionTotal: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.fdHeadline)
                .foregroundColor(color)
            Text(unit)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
            Text(label)
                .font(.fdCaption2)
                .foregroundColor(.fdSecondaryLabel)
        }
        .frame(maxWidth: .infinity)
    }
}
